import { sql } from "../../../server/db.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const MAX_LEN = 2000;

export async function POST(request) {
  const ip = clientKey(request);
  if (!(await allowRequest(`feedback:${ip}`, { limit: 3, windowMs: 60 * 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  if (body.company) {
    return Response.json({ ok: true });
  }

  const message = String(body.message || "").trim();
  if (message.length < 8 || message.length > MAX_LEN) {
    return Response.json({ error: "invalid_message" }, { status: 400 });
  }

  const email = String(body.email || "")
    .trim()
    .toLowerCase()
    .slice(0, 254);
  const category = String(body.category || "general")
    .trim()
    .toLowerCase()
    .slice(0, 40);

  await sql(
    `insert into feedback (email, message, category, client_key)
     values ($1, $2, $3, $4)`,
    [email || null, message, category || "general", ip.slice(0, 64)],
  );

  return Response.json({ ok: true });
}
