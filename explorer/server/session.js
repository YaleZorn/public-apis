import { createHash, randomBytes } from "node:crypto";
import { sql } from "./db.js";

const COOKIE = "stackpick_session";
const SESSION_DAYS = 30;

export function hashToken(token) {
  const pepper = process.env.SESSION_SECRET?.trim() || "stackpick-dev-session";
  return createHash("sha256").update(`${pepper}:${token}`).digest("hex");
}

export function readSessionToken(request) {
  const header = request.headers.get("cookie") || "";
  const parts = header.split(";").map((p) => p.trim());
  for (const part of parts) {
    if (part.startsWith(`${COOKIE}=`)) {
      return decodeURIComponent(part.slice(COOKIE.length + 1));
    }
  }
  return "";
}

export function sessionCookie(token, { clear = false } = {}) {
  if (clear) {
    return `${COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
  }
  const maxAge = SESSION_DAYS * 24 * 60 * 60;
  const secure = process.env.NODE_ENV === "production" ? "; Secure" : "";
  return `${COOKIE}=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${secure}`;
}

export async function createSession(userId) {
  const token = randomBytes(32).toString("base64url");
  const tokenHash = hashToken(token);
  await sql(
    `insert into sessions (token_hash, user_id, expires_at)
     values ($1, $2, now() + interval '30 days')`,
    [tokenHash, userId],
  );
  await sql("delete from sessions where expires_at < now()").catch(() => {});
  return token;
}

export async function destroySession(request) {
  const token = readSessionToken(request);
  if (!token) return;
  await sql("delete from sessions where token_hash = $1", [hashToken(token)]);
}

export async function getSessionUser(request) {
  const token = readSessionToken(request);
  if (!token) return null;
  const rows = await sql(
    `select u.id, u.email, u.name, u.avatar_url
     from sessions s
     join users u on u.id = s.user_id
     where s.token_hash = $1 and s.expires_at > now()`,
    [hashToken(token)],
  );
  return rows[0] || null;
}
