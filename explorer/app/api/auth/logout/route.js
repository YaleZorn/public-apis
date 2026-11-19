import { destroySession, sessionCookie } from "../../../../server/session.js";

export async function POST(request) {
  await destroySession(request);
  return Response.json(
    { ok: true },
    { headers: { "set-cookie": sessionCookie("", { clear: true }) } },
  );
}
