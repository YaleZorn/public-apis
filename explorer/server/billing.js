import { sql } from "./db.js";
import { emailHasProAccess, issueProToken, revokeProToken } from "./proAuth.js";
import { getStripe, isPaidStatus, stripeConfigured, stripePriceId } from "./stripe.js";

export { emailHasProAccess };

export async function getSubscriptionByUserId(userId) {
  const rows = await sql("select * from subscriptions where user_id = $1", [userId]);
  return rows[0] || null;
}

export async function getSubscriptionByEmail(email) {
  if (!email) return null;
  const rows = await sql(
    "select * from subscriptions where lower(email) = lower($1) order by updated_at desc limit 1",
    [email],
  );
  return rows[0] || null;
}

export async function upsertSubscription({
  userId,
  email,
  stripeCustomerId,
  stripeSubscriptionId,
  status,
  priceId,
  currentPeriodEnd,
  cancelAtPeriodEnd,
}) {
  const periodEnd = currentPeriodEnd
    ? new Date(currentPeriodEnd * 1000).toISOString()
    : null;
  await sql(
    `insert into subscriptions (
       user_id, email, stripe_customer_id, stripe_subscription_id, status, price_id,
       current_period_end, cancel_at_period_end, updated_at
     ) values ($1,$2,$3,$4,$5,$6,$7,$8, now())
     on conflict (user_id) do update set
       email = excluded.email,
       stripe_customer_id = coalesce(excluded.stripe_customer_id, subscriptions.stripe_customer_id),
       stripe_subscription_id = coalesce(excluded.stripe_subscription_id, subscriptions.stripe_subscription_id),
       status = excluded.status,
       price_id = coalesce(nullif(excluded.price_id, ''), subscriptions.price_id),
       current_period_end = excluded.current_period_end,
       cancel_at_period_end = excluded.cancel_at_period_end,
       updated_at = now()`,
    [
      userId,
      email,
      stripeCustomerId || null,
      stripeSubscriptionId || null,
      status || "inactive",
      priceId || "",
      periodEnd,
      Boolean(cancelAtPeriodEnd),
    ],
  );

  if (isPaidStatus(status)) {
    await issueProToken(email);
  } else {
    await revokeProToken(email);
  }
}

export async function syncStripeSubscription(subscription, { userId, email } = {}) {
  const metaUserId = Number(subscription.metadata?.user_id || userId || 0);
  const metaEmail = (subscription.metadata?.email || email || "").trim().toLowerCase();
  let resolvedUserId = Number.isFinite(metaUserId) && metaUserId > 0 ? metaUserId : null;
  let resolvedEmail = metaEmail;

  if (!resolvedUserId && subscription.customer) {
    const byCustomer = await sql(
      "select user_id, email from subscriptions where stripe_customer_id = $1",
      [String(subscription.customer)],
    );
    if (byCustomer[0]) {
      resolvedUserId = byCustomer[0].user_id;
      resolvedEmail = byCustomer[0].email;
    }
  }

  if (!resolvedUserId && resolvedEmail) {
    const users = await sql("select id, email from users where lower(email) = lower($1)", [
      resolvedEmail,
    ]);
    if (users[0]) {
      resolvedUserId = users[0].id;
      resolvedEmail = users[0].email;
    }
  }

  if (!resolvedUserId || !resolvedEmail) {
    return { ok: false, error: "user_not_found" };
  }

  const item = subscription.items?.data?.[0];
  await upsertSubscription({
    userId: resolvedUserId,
    email: resolvedEmail,
    stripeCustomerId: String(subscription.customer || ""),
    stripeSubscriptionId: subscription.id,
    status: subscription.status,
    priceId: item?.price?.id || stripePriceId(),
    currentPeriodEnd: subscription.current_period_end,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
  });
  return { ok: true, userId: resolvedUserId, email: resolvedEmail };
}

export async function refreshSubscriptionForUser(user) {
  if (!stripeConfigured() || !user?.id) return null;
  const stripe = getStripe();
  if (!stripe) return null;

  let row = await getSubscriptionByUserId(user.id);
  if (!row?.stripe_customer_id && !row?.stripe_subscription_id) {
    // Look up by email on Stripe customers (best-effort).
    const customers = await stripe.customers.list({ email: user.email, limit: 1 });
    const customer = customers.data[0];
    if (!customer) return row;
    const subs = await stripe.subscriptions.list({
      customer: customer.id,
      status: "all",
      limit: 5,
    });
    const preferred =
      subs.data.find((s) => isPaidStatus(s.status)) || subs.data[0] || null;
    if (!preferred) {
      await upsertSubscription({
        userId: user.id,
        email: user.email,
        stripeCustomerId: customer.id,
        stripeSubscriptionId: null,
        status: "inactive",
        priceId: "",
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
      });
      return getSubscriptionByUserId(user.id);
    }
    await syncStripeSubscription(preferred, { userId: user.id, email: user.email });
    return getSubscriptionByUserId(user.id);
  }

  if (row.stripe_subscription_id) {
    try {
      const sub = await stripe.subscriptions.retrieve(row.stripe_subscription_id);
      await syncStripeSubscription(sub, { userId: user.id, email: user.email });
    } catch {
      // Keep cached row if Stripe is temporarily unavailable.
    }
  }
  return getSubscriptionByUserId(user.id);
}

export function billingPublicStatus(row, { configured = stripeConfigured() } = {}) {
  return {
    configured,
    subscribed: Boolean(row && isPaidStatus(row.status)),
    status: row?.status || (configured ? "inactive" : "legacy_free_pro"),
    cancelAtPeriodEnd: Boolean(row?.cancel_at_period_end),
    currentPeriodEnd: row?.current_period_end || null,
    priceUsd: 9,
    interval: "month",
  };
}
