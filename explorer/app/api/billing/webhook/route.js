import { syncStripeSubscription } from "../../../../server/billing.js";
import { getStripe, webhookSecret } from "../../../../server/stripe.js";

export const runtime = "nodejs";

export async function POST(request) {
  const stripe = getStripe();
  const secret = webhookSecret();
  if (!stripe || !secret) {
    return Response.json({ error: "webhook_not_configured" }, { status: 503 });
  }

  const signature = request.headers.get("stripe-signature") || "";
  const rawBody = await request.text();

  let event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, secret);
  } catch {
    return Response.json({ error: "invalid_signature" }, { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        if (session.mode !== "subscription" || !session.subscription) break;
        const sub = await stripe.subscriptions.retrieve(String(session.subscription));
        const userId = Number(session.client_reference_id || session.metadata?.user_id || 0);
        const email = (session.metadata?.email || session.customer_email || "").trim();
        await syncStripeSubscription(sub, {
          userId: Number.isFinite(userId) ? userId : undefined,
          email,
        });
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        await syncStripeSubscription(event.data.object);
        break;
      }
      case "invoice.payment_failed": {
        const invoice = event.data.object;
        if (!invoice.subscription) break;
        const sub = await stripe.subscriptions.retrieve(String(invoice.subscription));
        await syncStripeSubscription(sub);
        break;
      }
      default:
        break;
    }
  } catch (error) {
    console.error("stripe webhook handler failed", event.type, error);
    return Response.json({ error: "handler_failed" }, { status: 500 });
  }

  return Response.json({ received: true });
}
