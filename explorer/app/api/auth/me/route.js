import { sql } from "../../../../server/db.js";
import { getSessionUser } from "../../../../server/session.js";

export async function GET(request) {
  const user = await getSessionUser(request);
  if (!user) {
    return Response.json({ ok: true, user: null });
  }

  let proToken = null;
  if (user.email) {
    const tokens = await sql(
      "select token from pro_tokens where email = $1 order by created_at desc limit 1",
      [user.email],
    );
    proToken = tokens[0]?.token || null;
  }

  return Response.json({
    ok: true,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatar_url,
      proToken,
    },
  });
}
