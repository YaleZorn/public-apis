import { mailConfigured } from "../../../server/mail.js";
import { authProvidersStatus } from "../../../server/oauth.js";
import { billingPublic, stripeConfigured } from "../../../server/stripe.js";

export async function GET() {
  const hasDb = Boolean(process.env.DATABASE_URL?.trim());
  return Response.json({
    ok: true,
    storage: hasDb ? "postgres" : "memory",
    sampleData: !hasDb,
    mailConfigured: mailConfigured(),
    billingConfigured: stripeConfigured(),
    billingPublic: billingPublic(),
    auth: authProvidersStatus(),
  });
}
