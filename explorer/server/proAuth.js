import { randomBytes } from "node:crypto";
import { sql } from "./db.js";
import { getSessionUser } from "./session.js";

export async function issueProToken(email) {
  const token = randomBytes(24).toString("base64url");
  await sql("delete from pro_tokens where email = $1", [email]);
  await sql("insert into pro_tokens (token, email) values ($1, $2)", [token, email]);
  return token;
}

function tokenFromRequest(request, bodyToken) {
  if (bodyToken) return String(bodyToken).trim();
  const custom = request.headers.get("x-stackpick-token");
  if (custom) return custom.trim();
  const auth = request.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(auth);
  return match ? match[1].trim() : "";
}

async function proFromSession(request) {
  const user = await getSessionUser(request);
  if (!user?.email) return null;
  const confirmed = await sql(
    "select email from waitlist where email = $1 and confirmed_at is not null",
    [user.email],
  );
  if (!confirmed.length) return null;
  const tokens = await sql(
    "select token from pro_tokens where email = $1 order by created_at desc limit 1",
    [user.email],
  );
  if (tokens[0]?.token) {
    return { ok: true, email: user.email, token: tokens[0].token, via: "session" };
  }
  const token = await issueProToken(user.email);
  return { ok: true, email: user.email, token, via: "session" };
}

export async function requireProToken(request, bodyToken) {
  const token = tokenFromRequest(request, bodyToken);
  if (token && token.length <= 128) {
    const rows = await sql(
      `select t.email
       from pro_tokens t
       join waitlist w on w.email = t.email
       where t.token = $1
         and w.confirmed_at is not null`,
      [token],
    );
    if (rows.length) {
      return { ok: true, email: rows[0].email, token };
    }
  }

  const fromSession = await proFromSession(request);
  if (fromSession) return fromSession;

  return { ok: false, status: 401, error: "pro_required" };
}
