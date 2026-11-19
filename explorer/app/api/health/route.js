import { findApisByIds } from "../../../server/catalog.js";
import { requireProToken } from "../../../server/proAuth.js";
import { allowRequest, clientKey } from "../../../server/rateLimit.js";

const MAX_IDS = 5;
const TIMEOUT_MS = 4000;

async function probe(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  const started = Date.now();
  try {
    let res = await fetch(url, {
      method: "HEAD",
      redirect: "follow",
      signal: controller.signal,
      headers: { "user-agent": "StackpickHealth/1.0" },
    });
    if (res.status === 405 || res.status === 501) {
      res = await fetch(url, {
        method: "GET",
        redirect: "follow",
        signal: controller.signal,
        headers: { "user-agent": "StackpickHealth/1.0" },
      });
    }
    return {
      ok: res.status > 0 && res.status < 500,
      status: res.status,
      ms: Date.now() - started,
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      ms: Date.now() - started,
      error: error.name === "AbortError" ? "timeout" : "network",
    };
  } finally {
    clearTimeout(timer);
  }
}

export async function POST(request) {
  if (!allowRequest(`health:${clientKey(request)}`, { limit: 12, windowMs: 60_000 })) {
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

  const ids = Array.isArray(body.ids) ? body.ids.map(String).slice(0, MAX_IDS) : [];
  if (!ids.length) {
    return Response.json({ error: "invalid_ids" }, { status: 400 });
  }

  // Only probe URLs that already exist in the curated catalog (SSRF guard).
  const apis = await findApisByIds(ids);
  if (!apis.length) {
    return Response.json({ error: "unknown_ids" }, { status: 400 });
  }

  const results = [];
  for (const api of apis) {
    const probeResult = await probe(api.url);
    results.push({
      id: api.id,
      name: api.name,
      url: api.url,
      ...probeResult,
    });
  }

  return Response.json({ results, checkedAt: new Date().toISOString() });
}
