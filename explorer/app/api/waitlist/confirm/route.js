import { sql } from "../../../../server/db.js";
import { emailHasProAccess, issueProToken } from "../../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";
import { createSession, sessionCookie } from "../../../../server/session.js";

export async function POST(request) {
  if (!(await allowRequest(`waitlist-confirm:${clientKey(request)}`, { limit: 20, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  const token = String(body.token || "").trim();
  if (!token || token.length > 128 || !/^[A-Za-z0-9_-]+$/.test(token)) {
    return Response.json({ error: "invalid_token" }, { status: 400 });
  }

  const rows = await sql(
    "select email from waitlist where confirm_token = $1",
    [token],
  );
  if (!rows.length) {
    return Response.json({ error: "invalid_token" }, { status: 400 });
  }

  const email = rows[0].email;
  await sql(
    "update waitlist set confirmed_at = coalesce(confirmed_at, now()), confirm_token = null where email = $1",
    [email],
  );

  let userId;
  const existing = await sql("select id from users where email = $1", [email]);
  if (existing.length) {
    userId = existing[0].id;
    await sql("update users set last_login_at = now() where id = $1", [userId]);
  } else {
    const created = await sql(
      `insert into users (email, name) values ($1, $2) returning id`,
      [email, email.split("@")[0].slice(0, 80) || "User"],
    );
    userId = created[0].id;
  }

  const hasPro = await emailHasProAccess(email);
  const proToken = hasPro ? await issueProToken(email) : null;
  const session = await createSession(userId);
  return Response.json(
    { ok: true, email, token: proToken, pro: hasPro },
    { headers: { "set-cookie": sessionCookie(session) } },
  );
}
