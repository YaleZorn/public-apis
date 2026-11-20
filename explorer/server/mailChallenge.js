import { createHmac, timingSafeEqual } from "node:crypto";

const MAX_AGE_MS = 2 * 60 * 1000;
const MIN_AGE_MS = 2_000;

function secret() {
  return (
    process.env.SESSION_SECRET?.trim() ||
    process.env.ADMIN_TOKEN?.trim() ||
    "stackpick-dev-challenge"
  );
}

export function issueMailChallenge() {
  const issuedAt = Date.now();
  const payload = String(issuedAt);
  const sig = createHmac("sha256", secret()).update(payload).digest("base64url");
  return { challenge: `${payload}.${sig}`, issuedAt };
}

export function verifyMailChallenge(challenge) {
  const raw = String(challenge || "");
  const dot = raw.indexOf(".");
  if (dot <= 0) return { ok: false, error: "invalid_challenge" };
  const payload = raw.slice(0, dot);
  const sig = raw.slice(dot + 1);
  const expected = createHmac("sha256", secret()).update(payload).digest("base64url");
  if (sig.length !== expected.length) return { ok: false, error: "invalid_challenge" };
  try {
    if (!timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
      return { ok: false, error: "invalid_challenge" };
    }
  } catch {
    return { ok: false, error: "invalid_challenge" };
  }
  const issuedAt = Number(payload);
  if (!Number.isFinite(issuedAt)) return { ok: false, error: "invalid_challenge" };
  const age = Date.now() - issuedAt;
  if (age < MIN_AGE_MS) return { ok: false, error: "challenge_too_fast" };
  if (age > MAX_AGE_MS) return { ok: false, error: "challenge_expired" };
  return { ok: true, issuedAt };
}
