import { randomBytes } from "node:crypto";
import { sql } from "./db.js";
import { getSessionUser } from "./session.js";
import { billingPublic, isPaidStatus } from "./stripe.js";

const PRO_TOKEN_TTL_DAYS = 7;

export async function issueProToken(email) {
  const token = randomBytes(24).toString("base64url");
  await sql("delete from pro_tokens where email = $1", [email]);
  await sql(
    `insert into pro_tokens (token, email, expires_at)
     values ($1, $2, now() + make_interval(days => $3))`,
    [token, email, PRO_TOKEN_TTL_DAYS],
  );
  return token;
}

export async function revokeProToken(email) {
  if (!email) return;
  await sql("delete from pro_tokens where email = $1", [email]);
}

export async function revokeExpiredProTokens() {
  await sql("delete from pro_tokens where expires_at is not null and expires_at < now()").catch(
    () => {},
  );
}

function tokenFromRequest(request, bodyToken) {
  if (bodyToken) return String(bodyToken).trim();
  const custom = request.headers.get("x-stackpick-token");
  if (custom) return custom.trim();
  const auth = request.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(auth);
  return match ? match[1].trim() : "";
}

export async function emailHasProAccess(email) {
  if (!email) return false;
  // Paid gating only when public Checkout is enabled; otherwise sign-in unlocks Pro
  // while Partner referrals remain the primary monetization path.
  if (!billingPublic()) {
    const confirmed = await sql(
      "select email from waitlist where email = $1 and confirmed_at is not null",
      [email],
    );
    return confirmed.length > 0;
  }
  const rows = await sql(
    "select status from subscriptions where lower(email) = lower($1) order by updated_at desc limit 1",
    [email],
  );
  return Boolean(rows[0] && isPaidStatus(rows[0].status));
}

async function ensureProToken(email) {
  await revokeExpiredProTokens();
  const tokens = await sql(
    `select token from pro_tokens
     where email = $1 and (expires_at is null or expires_at > now())
     order by created_at desc limit 1`,
    [email],
  );
  if (tokens[0]?.token) return tokens[0].token;
  return issueProToken(email);
}

async function proFromSession(request) {
  const user = await getSessionUser(request);
  if (!user?.email) return null;
  if (!(await emailHasProAccess(user.email))) return null;
  const token = await ensureProToken(user.email);
  return { ok: true, email: user.email, token, via: "session" };
}

export async function requireProToken(request, bodyToken) {
  await revokeExpiredProTokens();
  const token = tokenFromRequest(request, bodyToken);
  if (token && token.length <= 128) {
    const rows = await sql(
      `select t.email
       from pro_tokens t
       where t.token = $1
         and (t.expires_at is null or t.expires_at > now())`,
      [token],
    );
    if (rows.length && (await emailHasProAccess(rows[0].email))) {
      return { ok: true, email: rows[0].email, token };
    }
  }

  const fromSession = await proFromSession(request);
  if (fromSession) return fromSession;

  return { ok: false, status: 401, error: "pro_required" };
}
