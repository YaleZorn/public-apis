import { finishOAuth } from "../../../../../server/oauth.js";
import { publicOrigin } from "../../../../../server/publicOrigin.js";
import { createSession, sessionCookie } from "../../../../../server/session.js";
import { allowRequest, clientKey } from "../../../../../server/rateLimit.js";

export async function GET(request) {
  if (!(await allowRequest(`oauth-cb:${clientKey(request)}`, { limit: 30, windowMs: 60_000 }))) {
    return Response.redirect(`${publicOrigin(request)}/?auth=rate_limited`, 302);
  }

  const url = new URL(request.url);
  const code = url.searchParams.get("code") || "";
  const state = url.searchParams.get("state") || "";
  const finished = await finishOAuth(request, "github", { code, state });
  if (finished.error) {
    return Response.redirect(
      `${publicOrigin(request)}/?auth_error=${encodeURIComponent(finished.error)}`,
      302,
    );
  }

  const token = await createSession(finished.userId);
  return new Response(null, {
    status: 302,
    headers: {
      location: `${publicOrigin(request)}/?auth=github`,
      "set-cookie": sessionCookie(token),
    },
  });
}
