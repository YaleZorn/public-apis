/**
 * Sends the waitlist confirmation email when RESEND_API_KEY is set.
 * Without the secret, callers get a sample/local confirmation path instead.
 */

const FALLBACK_FROM = "Stackpick <onboarding@resend.dev>";

export function mailConfigured() {
  return Boolean(process.env.RESEND_API_KEY?.trim());
}

function normalizeFrom(raw) {
  const value = String(raw || "").trim();
  if (!value) return FALLBACK_FROM;
  // Bare email → display name wrapper Resend accepts.
  if (/^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/.test(value)) {
    return `Stackpick <${value}>`;
  }
  return value;
}

function classifyProviderError(status, detail) {
  const msg = String(detail || "").toLowerCase();
  if (status === 401 || msg.includes("api key") || msg.includes("unauthorized")) {
    return "auth";
  }
  if (
    msg.includes("only send testing") ||
    msg.includes("own email") ||
    msg.includes("verify a domain") && msg.includes("recipients")
  ) {
    return "test_recipient";
  }
  if (
    msg.includes("from") ||
    msg.includes("domain") ||
    msg.includes("not verified") ||
    status === 422
  ) {
    return "from";
  }
  return "provider";
}

async function postResend({ apiKey, from, email, confirmUrl }) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: "Confirm your Stackpick Pro waitlist",
      text: `Confirm your email to unlock Stackpick Pro:\n\n${confirmUrl}\n\nIf you did not request this, ignore this message.`,
    }),
  });
  const detail = res.ok ? "" : (await res.text().catch(() => "")).slice(0, 300);
  return { ok: res.ok, status: res.status, detail };
}

export async function sendConfirmEmail({ email, confirmUrl }) {
  const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
  if (!apiKey) {
    return { sent: false, reason: "missing_secret" };
  }

  const preferredFrom = normalizeFrom(process.env.RESEND_FROM);
  let result = await postResend({
    apiKey,
    from: preferredFrom,
    email,
    confirmUrl,
  });

  // Custom FROM often fails until the domain is verified — retry once with Resend's test sender.
  if (!result.ok && preferredFrom !== FALLBACK_FROM) {
    const reason = classifyProviderError(result.status, result.detail);
    if (reason === "from" || reason === "provider") {
      result = await postResend({
        apiKey,
        from: FALLBACK_FROM,
        email,
        confirmUrl,
      });
      if (result.ok) {
        return { sent: true, from: "fallback" };
      }
    }
  }

  if (!result.ok) {
    return {
      sent: false,
      reason: classifyProviderError(result.status, result.detail),
      detail: result.detail,
    };
  }
  return { sent: true };
}
