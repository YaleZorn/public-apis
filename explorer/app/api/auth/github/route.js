import { beginOAuth } from "../../../../server/oauth.js";
import { oauthStateCookie } from "../../../../server/oauthStateCookie.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";

export async function GET(request) {
  if (!(await allowRequest(`oauth-start:${clientKey(request)}`, { limit: 10, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }
  const started = await beginOAuth(request, "github");
  if (started.error) {
    return Response.json({ error: started.error }, { status: started.status || 503 });
  }
  return new Response(null, {
    status: 302,
    headers: {
      location: started.url,
      "set-cookie": oauthStateCookie(started.state),
    },
  });
}
