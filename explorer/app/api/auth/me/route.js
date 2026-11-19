import {
  billingPublicStatus,
  getSubscriptionByUserId,
} from "../../../../server/billing.js";
import { emailHasProAccess, issueProToken } from "../../../../server/proAuth.js";
import { sql } from "../../../../server/db.js";
import { getSessionUser } from "../../../../server/session.js";
import { stripeConfigured } from "../../../../server/stripe.js";

export async function GET(request) {
  const user = await getSessionUser(request);
  if (!user) {
    return Response.json({
      ok: true,
      user: null,
      billing: billingPublicStatus(null),
    });
  }

  const hasPro = await emailHasProAccess(user.email);
  let proToken = null;
  if (hasPro && user.email) {
    const tokens = await sql(
      "select token from pro_tokens where email = $1 order by created_at desc limit 1",
      [user.email],
    );
    proToken = tokens[0]?.token || (await issueProToken(user.email));
  }

  const sub = await getSubscriptionByUserId(user.id);

  return Response.json({
    ok: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatar_url,
      pro: hasPro,
      proToken,
    },
    billing: billingPublicStatus(sub, { configured: stripeConfigured() }),
  });
}
