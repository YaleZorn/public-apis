import { randomBytes } from "node:crypto";
import { sql } from "../../../server/db.js";
import { verifyMailChallenge } from "../../../server/mailChallenge.js";
import { mailConfigured, sendConfirmEmail } from "../../../server/mail.js";
import { publicOrigin } from "../../../server/publicOrigin.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DAILY_MAIL_CAP = 30;
const RESEND_COOLDOWN_MS = 60 * 60 * 1000;
const CONFIRM_TTL_MINUTES = 30;

export async function POST(request) {
  const canMail = mailConfigured();
  const ip = clientKey(request);
  // Paid email path: 1 attempt / 20 min per IP edge hop.
  const limit = canMail ? 1 : 6;
  const windowMs = canMail ? 20 * 60_000 : 60_000;
  if (!(await allowRequest(`waitlist:${ip}`, { limit, windowMs }))) {
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

  const challenge = verifyMailChallenge(body.challenge);
  if (!challenge.ok) {
    return Response.json({ error: challenge.error }, { status: 400 });
  }

  const email = String(body.email || "")
    .trim()
    .toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return Response.json({ error: "invalid_email" }, { status: 400 });
  }

  if (!(await allowRequest(`waitlist-email:${email}`, { limit: 1, windowMs: 60 * 60_000 }))) {
    return Response.json({ ok: true, delivery: "cooldown" });
  }

  const existing = await sql(
    "select email, confirmed_at, confirm_sent_at from waitlist where email = $1",
    [email],
  );

  if (existing[0]?.confirm_sent_at) {
    const sentAt = new Date(existing[0].confirm_sent_at).getTime();
    if (Number.isFinite(sentAt) && Date.now() - sentAt < RESEND_COOLDOWN_MS) {
      return Response.json({ ok: true, delivery: "cooldown" });
    }
  }

  const confirmToken = randomBytes(24).toString("base64url");
  if (!existing.length) {
    await sql(
      `insert into waitlist (email, source, confirm_token, last_confirm_ip, confirm_expires_at)
       values ($1, $2, $3, $4, now() + make_interval(mins => $5))`,
      [
        email,
        String(body.source || "web").slice(0, 40),
        confirmToken,
        ip.slice(0, 64),
        CONFIRM_TTL_MINUTES,
      ],
    );
  } else {
    await sql(
      `update waitlist
       set confirm_token = $2,
           last_confirm_ip = $3,
           confirm_expires_at = now() + make_interval(mins => $4)
       where email = $1`,
      [email, confirmToken, ip.slice(0, 64), CONFIRM_TTL_MINUTES],
    );
  }

  const confirmUrl = `${publicOrigin(request)}/?confirm=${confirmToken}`;
  const sampleMode =
    !process.env.DATABASE_URL?.trim() && process.env.STACKPICK_ALLOW_SAMPLE_CONFIRM === "1";

  if (canMail) {
    const day = new Date().toISOString().slice(0, 10);
    const quota = await sql("select sent from mail_quota where day = $1::date", [day]);
    const sent = quota[0]?.sent || 0;
    if (sent >= DAILY_MAIL_CAP) {
      return Response.json({ error: "mail_quota" }, { status: 503 });
    }

    const mailed = await sendConfirmEmail({ email, confirmUrl });
    if (!mailed.sent) {
      return Response.json(
        { error: "mail_failed", reason: mailed.reason || "provider" },
        { status: 502 },
      );
    }

    await sql(
      `insert into mail_quota (day, sent) values ($1::date, 1)
       on conflict (day) do update set sent = mail_quota.sent + 1`,
      [day],
    );
    await sql("update waitlist set confirm_sent_at = now() where email = $1", [email]);
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
