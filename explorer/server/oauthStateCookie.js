import { createHash, timingSafeEqual } from "node:crypto";

const COOKIE = "stackpick_oauth_state";
const MAX_AGE = 15 * 60;

function hashState(state) {
  return createHash("sha256").update(String(state)).digest("hex");
}

export function oauthStateCookie(state) {
  const value = hashState(state);
  const secure = process.env.NODE_ENV === "production" ? "; Secure" : "";
  return `${COOKIE}=${encodeURIComponent(value)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${MAX_AGE}${secure}`;
}

export function clearOauthStateCookie() {
  return `${COOKIE}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
}

export function readOauthStateCookie(request) {
  const header = request.headers.get("cookie") || "";
  const parts = header.split(";").map((p) => p.trim());
  for (const part of parts) {
    if (part.startsWith(`${COOKIE}=`)) {
      return decodeURIComponent(part.slice(COOKIE.length + 1));
    }
  }
  return "";
}

export function oauthStateMatchesCookie(request, state) {
  const expected = hashState(state);
  const got = readOauthStateCookie(request);
  if (!got || got.length !== expected.length) return false;
  try {
    return timingSafeEqual(Buffer.from(got), Buffer.from(expected));
  } catch {
    return false;
  }
}
