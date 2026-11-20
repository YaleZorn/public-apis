import { getIdentity } from "../cursor/identity.js";
import { publicOrigin } from "./publicOrigin.js";

/**
 * Admin access: ADMIN_TOKEN shared secret (required length),
 * optionally combined with allowlisted Origin, or Cursor private/team identity.
 */
export async function requireAdmin(request) {
  const expected = process.env.ADMIN_TOKEN?.trim() || "";
  if (!expected || expected.length < 24) {
    return { ok: false, status: 503, error: "admin_not_configured" };
  }

  const header = (request.headers.get("x-admin-token") || "").trim();
  if (header && timingSafeEqual(header, expected)) {
    if (!originAllowed(request)) {
      return { ok: false, status: 403, error: "origin_denied" };
    }
    return { ok: true, via: "token" };
  }

  const identity = await getIdentity(request);
  if (identity.verified && identity.kind === "person" && !identity.simulated) {
    if (identity.appVisibility === "private") {
      return { ok: true, via: "cursor", email: identity.email };
    }
    if (identity.appVisibility === "team" && identity.teamRole === "admin") {
      return { ok: true, via: "cursor", email: identity.email };
    }
  }

  return { ok: false, status: 401, error: "admin_required" };
}

function originAllowed(request) {
  const origin = (request.headers.get("origin") || "").trim();
  const referer = (request.headers.get("referer") || "").trim();
  // Browser form posts should send Origin; allow same public origin or missing Origin
  // (non-browser automation with ADMIN_TOKEN only).
  if (!origin && !referer) return true;
  let allowed;
  try {
    allowed = new URL(publicOrigin(request)).origin;
  } catch {
    return false;
  }
  if (origin) {
    try {
      return new URL(origin).origin === allowed;
    } catch {
      return false;
    }
  }
  try {
    return new URL(referer).origin === allowed;
  } catch {
    return false;
  }
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i += 1) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}
