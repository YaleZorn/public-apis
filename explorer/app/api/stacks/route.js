import { randomBytes } from "node:crypto";
import { findApisByIds } from "../../../server/catalog.js";
import { sql } from "../../../server/db.js";
import { requireProToken } from "../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const MAX_ITEMS = 40;
const MAX_ACTIVE_STACKS = 200;
const MAX_PER_CREATOR = 8;
const TTL_DAYS = 3;

export async function POST(request) {
  const ip = clientKey(request);
  if (!(await allowRequest(`stacks:${ip}`, { limit: 2, windowMs: 15 * 60_000 }))) {
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
  if ((counts[0]?.count || 0) >= MAX_ACTIVE_STACKS) {
    return Response.json({ error: "capacity" }, { status: 503 });
  }

  const mine = await sql(
    `select count(*)::int as count from stacks
     where creator_key = $1 and (expires_at is null or expires_at > now())`,
    [ip],
  );
  if ((mine[0]?.count || 0) >= MAX_PER_CREATOR) {
    return Response.json({ error: "creator_cap" }, { status: 429 });
  }

  const code = randomBytes(6).toString("base64url");
  await sql(
    `insert into stacks (code, items, expires_at, creator_key)
     values ($1, $2, now() + interval '3 days', $3)`,
    [code, JSON.stringify(items), ip.slice(0, 64)],
  );

  return Response.json({ ok: true, code, expiresInDays: TTL_DAYS });
}
