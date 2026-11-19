const ALLOWED_HOSTS = new Set([
  "stackpick.apps.grok.bot",
  "localhost",
  "127.0.0.1",
]);

/**
 * Confirm / share links must never follow visitor-controlled host headers.
 * Prefer APP_BASE_URL, then an allowlisted request.host / request.url host.
 */
export function publicOrigin(request) {
  const pinned = (process.env.APP_BASE_URL || "").trim().replace(/\/$/, "");
  if (pinned) {
    try {
      const u = new URL(pinned);
      if (u.protocol === "https:" || ALLOWED_HOSTS.has(u.hostname)) {
        return u.origin;
      }
    } catch {
      // ignore invalid pin
    }
  }

  const hostHeader = (request.headers.get("host") || "").split(",")[0].trim().toLowerCase();
  const hostname = hostHeader.replace(/:\d+$/, "");
  if (ALLOWED_HOSTS.has(hostname)) {
    const proto =
      hostname === "localhost" || hostname === "127.0.0.1" ? "http" : "https";
    return `${proto}://${hostHeader}`;
  }

  try {
    const url = new URL(request.url);
    if (ALLOWED_HOSTS.has(url.hostname)) {
      return url.origin;
    }
  } catch {
    // fall through
  }

  return "https://stackpick.apps.grok.bot";
}
