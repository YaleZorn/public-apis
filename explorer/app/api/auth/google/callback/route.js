import { finishOAuth } from "../../../../../server/oauth.js";
import { clearOauthStateCookie } from "../../../../../server/oauthStateCookie.js";
import { publicOrigin } from "../../../../../server/publicOrigin.js";
import { allowRequest, clientKey } from "../../../../../server/rateLimit.js";
import { createSession, sessionCookie } from "../../../../../server/session.js";

function redirectWithCookies(location, cookies) {
  const headers = new Headers({ location });
  for (const cookie of cookies) headers.append("set-cookie", cookie);
  return new Response(null, { status: 302, headers });
}

export async function GET(request) {
  if (!(await allowRequest(`oauth-cb:${clientKey(request)}`, { limit: 20, windowMs: 60_000 }))) {
    return redirectWithCookies(`${publicOrigin(request)}/?auth=rate_limited`, [
      clearOauthStateCookie(),
    ]);
  }

  const url = new URL(request.url);
  const code = url.searchParams.get("code") || "";
  const state = url.searchParams.get("state") || "";
  const finished = await finishOAuth(request, "google", { code, state });
  if (finished.error) {
    return redirectWithCookies(
      `${publicOrigin(request)}/?auth_error=${encodeURIComponent(finished.error)}`,
      [clearOauthStateCookie()],
    );
  }

  const token = await createSession(finished.userId);
  return redirectWithCookies(`${publicOrigin(request)}/?auth=google`, [
    sessionCookie(token),
    clearOauthStateCookie(),
  ]);
}
