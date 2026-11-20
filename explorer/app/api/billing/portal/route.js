import { getSubscriptionByUserId } from "../../../../server/billing.js";
import { publicOrigin } from "../../../../server/publicOrigin.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";
import { getSessionUser } from "../../../../server/session.js";
import { billingPublic, getStripe } from "../../../../server/stripe.js";

export async function POST(request) {
  if (!(await allowRequest(`billing-portal:${clientKey(request)}`, { limit: 10, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  if (!billingPublic()) {
    return Response.json({ error: "billing_not_public" }, { status: 503 });
  }

  const user = await getSessionUser(request);
  if (!user?.email) {
    return Response.json({ error: "sign_in_required" }, { status: 401 });
  }

  const row = await getSubscriptionByUserId(user.id);
  if (!row?.stripe_customer_id) {
    return Response.json({ error: "no_customer" }, { status: 400 });
  }

  const stripe = getStripe();
  const portal = await stripe.billingPortal.sessions.create({
    customer: row.stripe_customer_id,
    return_url: `${publicOrigin(request)}/#pro`,
  });

  return Response.json({ ok: true, url: portal.url });
}
