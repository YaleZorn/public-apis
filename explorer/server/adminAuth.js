import { getIdentity } from "../cursor/identity.js";

/**
 * Admin access: shared ADMIN_TOKEN secret (automation / agent ops),
 * or a verified Cursor identity when the app is private/team.
 */
export async function requireAdmin(request) {
  const expected = process.env.ADMIN_TOKEN?.trim() || "";
  const header = (request.headers.get("x-admin-token") || "").trim();
  if (expected && header && timingSafeEqual(header, expected)) {
    return { ok: true, via: "token" };
  }

  const identity = await getIdentity(request);
  // Ignore the local simulated viewer — admin on the public app needs ADMIN_TOKEN
  // (or a real Cursor private/team gate identity when visibility is changed).
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

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i += 1) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}
