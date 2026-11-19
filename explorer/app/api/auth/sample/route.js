import { sql } from "../../../../server/db.js";
import { issueProToken } from "../../../../server/proAuth.js";
import { createSession, sessionCookie } from "../../../../server/session.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";

/**
 * Local-only sample login when OAuth secrets are absent.
 * Enabled only with STACKPICK_ALLOW_SAMPLE_CONFIRM=1 and no DATABASE_URL.
 */
export async function POST(request) {
  const allowed =
    !process.env.DATABASE_URL?.trim() && process.env.STACKPICK_ALLOW_SAMPLE_CONFIRM === "1";
  if (!allowed) {
    return Response.json({ error: "not_available" }, { status: 404 });
  }
  if (!(await allowRequest(`oauth-sample:${clientKey(request)}`, { limit: 10, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body = {};
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const email = String(body.email || "sample.user@example.com")
    .trim()
    .toLowerCase();
  const name = String(body.name || "Sample User").slice(0, 80);

  let userId;
  const existing = await sql("select id from users where email = $1", [email]);
  if (existing.length) {
    userId = existing[0].id;
    await sql("update users set name = $2, last_login_at = now() where id = $1", [userId, name]);
  } else {
    const created = await sql(
      `insert into users (email, name) values ($1, $2) returning id`,
      [email, name],
    );
    userId = created[0].id;
  }

  const wait = await sql("select email from waitlist where email = $1", [email]);
  if (!wait.length) {
    await sql(
      `insert into waitlist (email, source, confirmed_at) values ($1, 'sample-oauth', now())`,
      [email],
    );
  } else {
    await sql(
      `update waitlist set confirmed_at = coalesce(confirmed_at, now()), confirm_token = null where email = $1`,
      [email],
    );
  }
  const proToken = await issueProToken(email);
  const session = await createSession(userId);

  return Response.json(
    { ok: true, email, name, proToken },
    { headers: { "set-cookie": sessionCookie(session) } },
  );
}
