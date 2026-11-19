import { randomBytes } from "node:crypto";
import { sql } from "./db.js";

export async function issueProToken(email) {
  const token = randomBytes(24).toString("base64url");
  // One active token per email: rotate on each successful waitlist call.
  await sql("delete from pro_tokens where email = $1", [email]);
  await sql("insert into pro_tokens (token, email) values ($1, $2)", [token, email]);
  return token;
}

export async function requireProToken(request, bodyToken) {
  const header = request.headers.get("x-stackpick-token") || "";
  const token = String(bodyToken || header || "").trim();
  if (!token || token.length > 128) {
    return { ok: false, status: 401, error: "pro_required" };
  }
  const rows = await sql("select email from pro_tokens where token = $1", [token]);
  if (!rows.length) {
    return { ok: false, status: 401, error: "pro_required" };
  }
  return { ok: true, email: rows[0].email, token };
}
