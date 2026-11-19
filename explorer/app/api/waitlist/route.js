import { randomBytes } from "node:crypto";
import { sql } from "../../../server/db.js";
import { mailConfigured, sendConfirmEmail } from "../../../server/mail.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PUBLIC_ORIGIN_RE = /^https:\/\/[a-z0-9.-]+(?::\d+)?$/i;

/**
 * Build confirm links from a pinned public origin, never from visitor-controlled
 * X-Forwarded-Host / X-Forwarded-Proto (open redirect / phishing risk).
 */
function originFrom(request) {
  const pinned = process.env.APP_BASE_URL?.trim() || process.env.NEXT_PUBLIC_APP_URL?.trim();
  if (pinned && PUBLIC_ORIGIN_RE.test(pinned.replace(/\/$/, ""))) {
    return pinned.replace(/\/$/, "");
  }
  try {
    const url = new URL(request.url);
    if (url.protocol === "https:" || url.hostname === "localhost" || url.hostname === "127.0.0.1") {
      return url.origin;
    }
  } catch {
    // fall through
  }
  return "https://stackpick.apps.grok.bot";
}

export async function POST(request) {
  const canMail = mailConfigured();
  // Tighter bucket when each call can spend Resend quota.
  const limit = canMail ? 3 : 8;
  const windowMs = canMail ? 10 * 60_000 : 60_000;
  if (!(await allowRequest(`waitlist:${clientKey(request)}`, { limit, windowMs }))) {
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
  } else {
    await sql("update waitlist set confirm_token = $2 where email = $1", [email, confirmToken]);
  }

  const confirmUrl = `${originFrom(request)}/?confirm=${confirmToken}`;
  // Sample confirm tokens only with an explicit local flag — never when Postgres is attached.
  // (next start always sets NODE_ENV=production, so do not gate on NODE_ENV.)
  const sampleMode =
    !process.env.DATABASE_URL?.trim() && process.env.STACKPICK_ALLOW_SAMPLE_CONFIRM === "1";

  if (canMail) {
    const mailed = await sendConfirmEmail({ email, confirmUrl });
    if (!mailed.sent) {
      return Response.json(
        { error: "mail_failed", reason: mailed.reason || "provider" },
        { status: 502 },
      );
    }
    return Response.json({ ok: true, delivery: "email" });
  }

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
