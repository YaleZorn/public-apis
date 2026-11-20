import Stripe from "stripe";

export function stripeConfigured() {
  return Boolean(
    process.env.STRIPE_SECRET_KEY?.trim() && process.env.STRIPE_PRICE_ID?.trim(),
  );
}

/**
 * Public Checkout / Portal are opt-in.
 * Default off so Partner referrals stay the primary monetization path until
 * the operator explicitly enables STACKPICK_BILLING_PUBLIC=1.
 */
export function billingPublic() {
  return stripeConfigured() && process.env.STACKPICK_BILLING_PUBLIC?.trim() === "1";
}

export function stripePriceId() {
  return process.env.STRIPE_PRICE_ID?.trim() || "";
}

export function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY?.trim();
  if (!key) return null;
  return new Stripe(key);
}

export function webhookSecret() {
  return process.env.STRIPE_WEBHOOK_SECRET?.trim() || "";
}

/** Statuses that unlock Pro tools. */
export function isPaidStatus(status) {
  return ["active", "trialing", "past_due"].includes(String(status || ""));
}
