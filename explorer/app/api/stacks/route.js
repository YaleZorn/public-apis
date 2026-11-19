import { randomBytes } from "node:crypto";
import { sql } from "../../../src/lib/db.js";
import { allowRequest, clientKey } from "../../../src/lib/rateLimit.js";

const MAX_ITEMS = 40;

function normalizeItems(items) {
  if (!Array.isArray(items)) return null;
  if (items.length === 0 || items.length > MAX_ITEMS) return null;
  return items.map((item) => ({
    id: String(item.id || "").slice(0, 120),
    name: String(item.name || "").slice(0, 160),
    url: String(item.url || "").slice(0, 500),
    category: String(item.category || "").slice(0, 80),
  }));
}

export async function POST(request) {
  if (!allowRequest(`stacks:${clientKey(request)}`, { limit: 20, windowMs: 60_000 })) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  const items = normalizeItems(body.items);
  if (!items) {
    return Response.json({ error: "invalid_items" }, { status: 400 });
  }

  const code = randomBytes(6).toString("base64url");
  await sql("insert into stacks (code, items) values ($1, $2)", [
    code,
    JSON.stringify(items),
  ]);

  return Response.json({ ok: true, code });
}
