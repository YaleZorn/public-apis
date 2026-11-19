import {
  getSubscriptionByUserId,
  upsertSubscription,
} from "../../../../server/billing.js";
import { publicOrigin } from "../../../../server/publicOrigin.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";
import { getSessionUser } from "../../../../server/session.js";
import { getStripe, stripeConfigured, stripePriceId } from "../../../../server/stripe.js";

export async function POST(request) {
  if (!(await allowRequest(`billing-checkout:${clientKey(request)}`, { limit: 10, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  if (!stripeConfigured()) {
    return Response.json({ error: "billing_not_configured" }, { status: 503 });
  }

  const user = await getSessionUser(request);
  if (!user?.email) {
    return Response.json({ error: "sign_in_required" }, { status: 401 });
  }

  const stripe = getStripe();
  const priceId = stripePriceId();
  const origin = publicOrigin(request);

  let row = await getSubscriptionByUserId(user.id);
  let customerId = row?.stripe_customer_id || "";

  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user.email,
      name: user.name || undefined,
      metadata: { user_id: String(user.id) },
    });
    customerId = customer.id;
    await upsertSubscription({
      userId: user.id,
      email: user.email,
      stripeCustomerId: customerId,
      stripeSubscriptionId: row?.stripe_subscription_id || null,
      status: row?.status || "inactive",
      priceId: row?.price_id || "",
      currentPeriodEnd: row?.current_period_end
        ? Math.floor(new Date(row.current_period_end).getTime() / 1000)
        : null,
      cancelAtPeriodEnd: row?.cancel_at_period_end || false,
    });
  }

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer: customerId,
    client_reference_id: String(user.id),
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${origin}/?billing=success`,
    cancel_url: `${origin}/?billing=cancel`,
    allow_promotion_codes: true,
    metadata: { user_id: String(user.id), email: user.email },
    subscription_data: {
      metadata: { user_id: String(user.id), email: user.email },
    },
  });

  return Response.json({ ok: true, url: session.url, sessionId: session.id });
}
