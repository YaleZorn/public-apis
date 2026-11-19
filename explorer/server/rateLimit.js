import { sql } from "./db.js";

/**
 * Rate limit backed by Postgres/PGlite so limits hold across instances.
 * Returns true when the caller is allowed.
 */
export async function allowRequest(key, { limit = 20, windowMs = 60_000 } = {}) {
  const now = new Date();
  const windowStart = now.toISOString();
  const cutoff = new Date(now.getTime() - windowMs).toISOString();
  const rows = await sql(
    `insert into rate_limits (bucket_key, window_start, hit_count)
     values ($1, $2, 1)
     on conflict (bucket_key) do update
     set
       hit_count = case
         when rate_limits.window_start < $3::timestamptz then 1
         else rate_limits.hit_count + 1
       end,
       window_start = case
         when rate_limits.window_start < $3::timestamptz then excluded.window_start
         else rate_limits.window_start
       end
     returning hit_count`,
    [key, windowStart, cutoff],
  );
  return Boolean(rows[0] && rows[0].hit_count <= limit);
}

/**
 * Do not trust X-Real-IP or the leftmost X-Forwarded-For hop — clients can
 * spoof those. Prefer the rightmost forwarded hop (added by the edge).
 */
export function clientKey(request) {
  const forwarded = request.headers.get("x-forwarded-for") || "";
  const hops = forwarded
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  if (hops.length) return hops[hops.length - 1];
  return "local";
}
