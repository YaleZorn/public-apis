import { authProvidersStatus } from "../../../../server/oauth.js";

export async function GET() {
  return Response.json({ ok: true, providers: authProvidersStatus() });
}
