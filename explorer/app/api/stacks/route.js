import { randomBytes } from "node:crypto";
import { findApisByIds } from "../../../server/catalog.js";
import { sql } from "../../../server/db.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const MAX_ITEMS = 40;
const MAX_ACTIVE_STACKS = 500;
const TTL_DAYS = 7;

export async function POST(request) {
  // Keep share creation cheap to exhaust: 3 / 10 min per IP edge hop.
  if (!(await allowRequest(`stacks:${clientKey(request)}`, { limit: 3, windowMs: 10 * 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  const ids = Array.isArray(body.ids)
    ? [...new Set(body.ids.map(String))].slice(0, MAX_ITEMS)
    : [];
  if (!ids.length) {
    return Response.json({ error: "invalid_ids" }, { status: 400 });
  }

  // Resolve names/URLs from the curated catalog only — never trust client text/URLs.
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

  const code = randomBytes(6).toString("base64url");
  await sql(
    `insert into stacks (code, items, expires_at)
     values ($1, $2, now() + interval '7 days')`,
    [code, JSON.stringify(items)],
  );

  return Response.json({ ok: true, code, expiresInDays: TTL_DAYS });
}
