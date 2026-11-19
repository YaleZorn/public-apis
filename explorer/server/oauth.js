import { createHash, randomBytes } from "node:crypto";
import { sql } from "./db.js";
import { publicOrigin } from "./publicOrigin.js";
import { issueProToken } from "./proAuth.js";

export function oauthConfigured(provider) {
  if (provider === "google") {
    return Boolean(
      process.env.GOOGLE_CLIENT_ID?.trim() && process.env.GOOGLE_CLIENT_SECRET?.trim(),
    );
  }
  if (provider === "github") {
    return Boolean(
      process.env.GITHUB_CLIENT_ID?.trim() && process.env.GITHUB_CLIENT_SECRET?.trim(),
    );
  }
  return false;
}

export function authProvidersStatus() {
  return {
    google: oauthConfigured("google"),
    github: oauthConfigured("github"),
    sampleLogin:
      !process.env.DATABASE_URL?.trim() && process.env.STACKPICK_ALLOW_SAMPLE_CONFIRM === "1",
  };
}

export function callbackUrl(request, provider) {
  return `${publicOrigin(request)}/api/auth/${provider}/callback`;
}

function pkcePair() {
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}

export async function beginOAuth(request, provider) {
  if (!oauthConfigured(provider)) {
    return { error: "not_configured", status: 503 };
  }

  const state = randomBytes(24).toString("base64url");
  const { verifier, challenge } = pkcePair();
  await sql(
    `insert into oauth_states (state, provider, code_verifier, expires_at)
     values ($1, $2, $3, now() + interval '15 minutes')`,
    [state, provider, verifier],
  );
  await sql("delete from oauth_states where expires_at < now()").catch(() => {});

  const redirectUri = callbackUrl(request, provider);
  if (provider === "google") {
    const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    url.searchParams.set("client_id", process.env.GOOGLE_CLIENT_ID.trim());
    url.searchParams.set("redirect_uri", redirectUri);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", "openid email profile");
    url.searchParams.set("state", state);
    url.searchParams.set("code_challenge", challenge);
    url.searchParams.set("code_challenge_method", "S256");
    url.searchParams.set("prompt", "select_account");
    return { url: url.toString() };
  }

  const url = new URL("https://github.com/login/oauth/authorize");
  url.searchParams.set("client_id", process.env.GITHUB_CLIENT_ID.trim());
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", "read:user user:email");
  url.searchParams.set("state", state);
  return { url: url.toString() };
}

async function exchangeGoogle(code, redirectUri, verifier) {
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: process.env.GOOGLE_CLIENT_ID.trim(),
      client_secret: process.env.GOOGLE_CLIENT_SECRET.trim(),
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
      code_verifier: verifier,
    }),
  });
  if (!res.ok) {
    return { error: "token_exchange", detail: await res.text().catch(() => "") };
  }
  const tokens = await res.json();
  const profileRes = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
    headers: { authorization: `Bearer ${tokens.access_token}` },
  });
  if (!profileRes.ok) {
    return { error: "profile", detail: await profileRes.text().catch(() => "") };
  }
  const profile = await profileRes.json();
  return {
    providerUserId: String(profile.sub || ""),
    email: String(profile.email || "")
      .trim()
      .toLowerCase(),
    name: String(profile.name || profile.email || "Google user"),
    avatarUrl: String(profile.picture || ""),
  };
}

async function exchangeGithub(code, redirectUri) {
  const res = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      client_id: process.env.GITHUB_CLIENT_ID.trim(),
      client_secret: process.env.GITHUB_CLIENT_SECRET.trim(),
      code,
      redirect_uri: redirectUri,
    }),
  });
  if (!res.ok) {
    return { error: "token_exchange", detail: await res.text().catch(() => "") };
  }
  const tokens = await res.json();
  if (!tokens.access_token) {
    return { error: "token_exchange", detail: JSON.stringify(tokens).slice(0, 200) };
  }

  const userRes = await fetch("https://api.github.com/user", {
    headers: {
      authorization: `Bearer ${tokens.access_token}`,
      accept: "application/vnd.github+json",
      "user-agent": "StackpickAuth/1.0",
    },
  });
  if (!userRes.ok) {
    return { error: "profile", detail: await userRes.text().catch(() => "") };
  }
  const user = await userRes.json();

  let email = String(user.email || "")
    .trim()
    .toLowerCase();
  if (!email) {
    const emailsRes = await fetch("https://api.github.com/user/emails", {
      headers: {
        authorization: `Bearer ${tokens.access_token}`,
        accept: "application/vnd.github+json",
        "user-agent": "StackpickAuth/1.0",
      },
    });
    if (emailsRes.ok) {
      const emails = await emailsRes.json();
      const primary = (emails || []).find((e) => e.primary && e.verified) ||
        (emails || []).find((e) => e.verified) ||
        (emails || [])[0];
      email = String(primary?.email || "")
        .trim()
        .toLowerCase();
    }
  }

  return {
    providerUserId: String(user.id || ""),
    email,
    name: String(user.name || user.login || "GitHub user"),
    avatarUrl: String(user.avatar_url || ""),
  };
}

export async function finishOAuth(request, provider, { code, state }) {
  if (!oauthConfigured(provider)) {
    return { error: "not_configured", status: 503 };
  }
  if (!code || !state || state.length > 128) {
    return { error: "invalid_state", status: 400 };
  }

  const states = await sql(
    `select state, code_verifier from oauth_states
     where state = $1 and provider = $2 and expires_at > now()`,
    [state, provider],
  );
  await sql("delete from oauth_states where state = $1", [state]);
  if (!states.length) {
    return { error: "invalid_state", status: 400 };
  }

  const redirectUri = callbackUrl(request, provider);
  const profile =
    provider === "google"
      ? await exchangeGoogle(code, redirectUri, states[0].code_verifier)
      : await exchangeGithub(code, redirectUri);

  if (profile.error || !profile.providerUserId) {
    return { error: profile.error || "profile", status: 502 };
  }
  if (!profile.email) {
    return { error: "email_required", status: 400 };
  }

  const existingAccount = await sql(
    "select user_id from oauth_accounts where provider = $1 and provider_user_id = $2",
    [provider, profile.providerUserId],
  );

  let userId;
  if (existingAccount.length) {
    userId = existingAccount[0].user_id;
    await sql(
      `update users set
         email = coalesce(nullif($2, ''), email),
         name = $3,
         avatar_url = $4,
         last_login_at = now()
       where id = $1`,
      [userId, profile.email, profile.name.slice(0, 120), profile.avatarUrl.slice(0, 500)],
    );
  } else {
    const byEmail = await sql("select id from users where email = $1", [profile.email]);
    if (byEmail.length) {
      userId = byEmail[0].id;
      await sql(
        `update users set name = $2, avatar_url = $3, last_login_at = now() where id = $1`,
        [userId, profile.name.slice(0, 120), profile.avatarUrl.slice(0, 500)],
      );
    } else {
      const created = await sql(
        `insert into users (email, name, avatar_url)
         values ($1, $2, $3)
         returning id`,
        [profile.email, profile.name.slice(0, 120), profile.avatarUrl.slice(0, 500)],
      );
      userId = created[0].id;
    }
    await sql(
      `insert into oauth_accounts (provider, provider_user_id, user_id, raw_email)
       values ($1, $2, $3, $4)
       on conflict (provider, provider_user_id) do update set user_id = excluded.user_id`,
      [provider, profile.providerUserId, userId, profile.email],
    );
  }

  // OAuth proves email ownership — mark waitlist confirmed and issue Pro token.
  const wait = await sql("select email from waitlist where email = $1", [profile.email]);
  if (!wait.length) {
    await sql(
      `insert into waitlist (email, source, confirmed_at, confirm_token)
       values ($1, $2, now(), null)`,
      [profile.email, `oauth:${provider}`],
    );
  } else {
    await sql(
      `update waitlist set confirmed_at = coalesce(confirmed_at, now()), confirm_token = null
       where email = $1`,
      [profile.email],
    );
  }
  const proToken = await issueProToken(profile.email);

  return {
    userId,
    email: profile.email,
    name: profile.name,
    avatarUrl: profile.avatarUrl,
    proToken,
  };
}
