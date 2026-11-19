import { randomBytes } from "node:crypto";
import { sql } from "../../../server/db.js";
import { mailConfigured, sendConfirmEmail } from "../../../server/mail.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function originFrom(request) {
  const proto = request.headers.get("x-forwarded-proto") || "https";
  const host = request.headers.get("x-forwarded-host") || request.headers.get("host");
  if (host) return `${proto}://${host}`;
  return new URL(request.url).origin;
}

export async function POST(request) {
  if (!(await allowRequest(`waitlist:${clientKey(request)}`, { limit: 8, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  if (body.company) {
    return Response.json({ ok: true });
  }

  const email = String(body.email || "")
    .trim()
    .toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return Response.json({ error: "invalid_email" }, { status: 400 });
  }

  const confirmToken = randomBytes(24).toString("base64url");
  const existing = await sql("select email, confirmed_at from waitlist where email = $1", [email]);

  if (!existing.length) {
    await sql(
      "insert into waitlist (email, source, confirm_token) values ($1, $2, $3)",
      [email, String(body.source || "web").slice(0, 40), confirmToken],
    );
  } else if (!existing[0].confirmed_at) {
    await sql("update waitlist set confirm_token = $2 where email = $1", [email, confirmToken]);
  } else {
    // Already confirmed: rotate confirm token unused; tell client to use confirm flow for new Pro token via email again.
    await sql("update waitlist set confirm_token = $2 where email = $1", [email, confirmToken]);
  }

  const confirmUrl = `${originFrom(request)}/?confirm=${confirmToken}`;
  const sampleMode = !process.env.DATABASE_URL?.trim();
  const canMail = mailConfigured();

  if (canMail) {
    const mailed = await sendConfirmEmail({ email, confirmUrl });
    if (!mailed.sent) {
      return Response.json({ error: "mail_failed" }, { status: 502 });
    }
    return Response.json({ ok: true, delivery: "email" });
  }

  // Local/sample only: expose the confirm token so flows work without a mail secret.
  // Production with Postgres never returns the token in the response body.
  if (sampleMode) {
    return Response.json({
      ok: true,
      delivery: "sample",
      sampleConfirmToken: confirmToken,
    });
  }

  return Response.json({
    ok: true,
    delivery: "pending_secret",
  });
}
