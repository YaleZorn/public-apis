import { sql } from "../../../server/db.js";
import { issueProToken } from "../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(request) {
  if (!allowRequest(`waitlist:${clientKey(request)}`, { limit: 10, windowMs: 60_000 })) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  // Honeypot: bots fill hidden fields; humans leave it empty.
  if (body.company) {
    return Response.json({ ok: true });
  }

  const email = String(body.email || "")
    .trim()
    .toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return Response.json({ error: "invalid_email" }, { status: 400 });
  }

  const existing = await sql("select email from waitlist where email = $1", [email]);
  if (!existing.length) {
    await sql("insert into waitlist (email, source) values ($1, $2)", [
      email,
      String(body.source || "web").slice(0, 40),
    ]);
  }

  const token = await issueProToken(email);
  // Never reveal whether the email was already registered.
  return Response.json({ ok: true, token });
}
