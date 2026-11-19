const buckets = new Map();

/** Simple in-memory rate limit. Returns true when the caller is allowed. */
export function allowRequest(key, { limit = 20, windowMs = 60_000 } = {}) {
  const now = Date.now();
  const bucket = buckets.get(key) ?? [];
  const fresh = bucket.filter((t) => now - t < windowMs);
  if (fresh.length >= limit) {
    buckets.set(key, fresh);
    return false;
  }
  fresh.push(now);
  buckets.set(key, fresh);
  return true;
}

/**
 * Prefer platform-provided identity. Never trust the leftmost
 * X-Forwarded-For value — clients can spoof that hop.
 */
export function clientKey(request) {
  const realIp = (request.headers.get("x-real-ip") || "").trim();
  if (realIp) return realIp;

  const forwarded = request.headers.get("x-forwarded-for") || "";
  const hops = forwarded
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  // Rightmost hop is typically appended by the trusted edge proxy.
  if (hops.length) return hops[hops.length - 1];

  return "local";
}
