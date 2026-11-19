import {
  billingPublicStatus,
  getSubscriptionByUserId,
  refreshSubscriptionForUser,
} from "../../../../server/billing.js";
import { getSessionUser } from "../../../../server/session.js";
import { stripeConfigured } from "../../../../server/stripe.js";

export async function GET(request) {
  const configured = stripeConfigured();
  const user = await getSessionUser(request);
  if (!user) {
    return Response.json({
      ok: true,
      billing: billingPublicStatus(null, { configured }),
      user: null,
    });
  }

  const url = new URL(request.url);
  const refresh = url.searchParams.get("refresh") === "1";
  const row = refresh
    ? await refreshSubscriptionForUser(user)
    : await getSubscriptionByUserId(user.id);

  return Response.json({
    ok: true,
    billing: billingPublicStatus(row, { configured }),
    user: { id: user.id, email: user.email },
  });
}
