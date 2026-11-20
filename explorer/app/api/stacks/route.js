import { randomBytes } from "node:crypto";
import { findApisByIds } from "../../../server/catalog.js";
import { sql } from "../../../server/db.js";
import { requireProToken } from "../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";
import { billingPublic } from "../../../server/stripe.js";

const MAX_ITEMS = 40;

export async function POST(request) {
  const ip = clientKey(request);
  const paidMode = billingPublic();
  // When paid checkout is closed, keep share capacity tight even for signed-in Pro.
  const maxActive = paidMode ? 100 : 15;
  const maxPerCreator = paidMode ? 5 : 1;
  const ttlDays = paidMode ? 3 : 1;
  const ipLimit = paidMode ? 2 : 1;
  const ipWindow = paidMode ? 15 * 60_000 : 60 * 60_000;

  if (!(await allowRequest(`stacks:${ip}`, { limit: ipLimit, windowMs: ipWindow }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  const auth = await requireProToken(request, body.token);
  if (!auth.ok) {
    return Response.json({ error: auth.error }, { status: auth.status });
  }

  const ids = Array.isArray(body.ids)
    ? [...new Set(body.ids.map(String))].slice(0, MAX_ITEMS)
    : [];
  if (!ids.length) {
    return Response.json({ error: "invalid_ids" }, { status: 400 });
  }

  const apis = await findApisByIds(ids);
  if (!apis.length || apis.length !== ids.length) {
    return Response.json({ error: "unknown_ids" }, { status: 400 });
  }

  const items = apis.map((api) => ({
    id: api.id,
    name: api.name,
    url: api.url,
    category: api.category,
  }));

  await sql("delete from stacks where expires_at is not null and expires_at < now()");

  const counts = await sql(
    "select count(*)::int as count from stacks where expires_at is null or expires_at > now()",
  );
  if ((counts[0]?.count || 0) >= maxActive) {
    return Response.json({ error: "capacity" }, { status: 503 });
  }

  const mine = await sql(
    `select count(*)::int as count from stacks
     where creator_key = $1 and (expires_at is null or expires_at > now())`,
    [ip],
  );
  if ((mine[0]?.count || 0) >= maxPerCreator) {
    return Response.json({ error: "creator_cap" }, { status: 429 });
  }

  const code = randomBytes(6).toString("base64url");
  await sql(
    `insert into stacks (code, items, expires_at, creator_key)
     values ($1, $2, now() + make_interval(days => $3), $4)`,
    [code, JSON.stringify(items), ttlDays, ip.slice(0, 64)],
  );

  return Response.json({ ok: true, code, expiresInDays: ttlDays });
}
