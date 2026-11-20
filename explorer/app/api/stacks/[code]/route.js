import { sql } from "../../../../server/db.js";
import { allowRequest, clientKey } from "../../../../server/rateLimit.js";

export async function GET(request, { params }) {
  if (!(await allowRequest(`stack-get:${clientKey(request)}`, { limit: 60, windowMs: 60_000 }))) {
    return Response.json({ error: "rate_limited" }, { status: 429 });
  }

  const { code } = await params;
  if (!code || !/^[A-Za-z0-9_-]{6,16}$/.test(code)) {
    return Response.json({ error: "not_found" }, { status: 404 });
  }

  const rows = await sql(
    `select code, items, created_at, expires_at
     from stacks
     where code = $1
       and (expires_at is null or expires_at > now())`,
    [code],
  );
  if (!rows.length) {
    return Response.json({ error: "not_found" }, { status: 404 });
  }

  const row = rows[0];
  return Response.json(
    {
      code: row.code,
      items: row.items,
      createdAt: row.created_at,
      expiresAt: row.expires_at,
    },
    { headers: { "cache-control": "public, max-age=60" } },
  );
}
