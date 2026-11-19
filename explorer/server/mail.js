/**
 * Sends the waitlist confirmation email when RESEND_API_KEY is set.
 * Without the secret, callers get a sample/local confirmation path instead.
 */
export function mailConfigured() {
  return Boolean(process.env.RESEND_API_KEY?.trim());
}

export async function sendConfirmEmail({ email, confirmUrl }) {
  const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
  if (!apiKey) {
    return { sent: false, reason: "missing_secret" };
  }

  const from = process.env.RESEND_FROM?.trim() || "Stackpick <onboarding@resend.dev>";
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

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    return { sent: false, reason: "provider_error", detail: detail.slice(0, 200) };
  }
  return { sent: true };
}
