import { revokeProToken } from "../../../../server/proAuth.js";
import { destroySession, getSessionUser, sessionCookie } from "../../../../server/session.js";

export async function POST(request) {
  const user = await getSessionUser(request);
  if (user?.email) {
    await revokeProToken(user.email);
  }
  await destroySession(request);
  return Response.json(
    { ok: true },
    { headers: { "set-cookie": sessionCookie("", { clear: true }) } },
  );
}
