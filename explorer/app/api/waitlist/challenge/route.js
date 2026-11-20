import { issueMailChallenge } from "../../../../server/mailChallenge.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";

export async function GET(request) {
  if (!(await allowRequest(`waitlist-challenge:${clientKey(request)}`, { limit: 10, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }
  const { challenge, issuedAt } = issueMailChallenge();
  return Response.json({ ok: true, challenge, issuedAt });
}
