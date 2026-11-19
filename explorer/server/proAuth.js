import { randomBytes } from "node:crypto";
import { sql } from "./db.js";

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

export async function requireProToken(request, bodyToken) {
  const token = tokenFromRequest(request, bodyToken);
  if (!token || token.length > 128) {
    return { ok: false, status: 401, error: "pro_required" };
  }
  const rows = await sql(
    `select t.email
     from pro_tokens t
     join waitlist w on w.email = t.email
     where t.token = $1
       and w.confirmed_at is not null`,
    [token],
  );
  if (!rows.length) {
    return { ok: false, status: 401, error: "pro_required" };
  }
  return { ok: true, email: rows[0].email, token };
}
