import { sql } from "../../../../server/db.js";
import { issueProToken } from "../../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";

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
  const proToken = await issueProToken(email);
  return Response.json({ ok: true, email, token: proToken });
}
