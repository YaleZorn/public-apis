# Stackpick

Searchable explorer for the [public-apis](../README.md) catalog with shortlists, partner placements, sign-in, Stripe Pro subscriptions, share links, export, and health checks.

## Develop

```bash
python3 scripts/parse_apis.py   # from repo root, refresh catalog JSON
cd explorer
npm install
npm run dev                     # http://127.0.0.1:3000
```

Local API routes use in-memory PGlite when `DATABASE_URL` is unset. Published apps get Postgres via `cursor-app.json`.

## Build

```bash
cd explorer
npm run build
npm start
```

## Closed loops

| Flow | Endpoint / action |
| --- | --- |
| Browse / filter | `/data/apis.json` |
| Shortlist | localStorage (free 5 / Pro 25) |
| Sign in | Google / GitHub OAuth or `POST /api/waitlist` magic link |
| Subscribe (Pro) | `POST /api/billing/checkout` → Stripe Checkout |
| Manage billing | `POST /api/billing/portal` |
| Stripe webhooks | `POST /api/billing/webhook` |
| Share stack | `POST /api/stacks` → `/?stack=CODE` |
| Load shared | `GET /api/stacks/[code]` |
| Export | JSON / CSV download (Pro) |
| Health | `POST /api/health` (catalog URLs only, Pro) |
| Partners | labeled referral links |

## Monetization model (partner-first)

- **Free:** browse + shortlist up to 5 APIs.
- **Signed in:** unlocks Pro tools while paid checkout is closed (default).
- **Partner referrals:** labeled links — primary revenue path without requiring a merchant entity.
- **Paid Pro (optional later):** Stripe Checkout at $9/mo, only when explicitly enabled.

Public Subscribe / Portal stay **off** unless:

1. `STRIPE_SECRET_KEY` + `STRIPE_PRICE_ID` are set, and  
2. `STACKPICK_BILLING_PUBLIC=1`

### Stripe secrets (optional)

| Secret / env | Purpose |
| --- | --- |
| `STRIPE_SECRET_KEY` | Server SDK (`sk_test_…` / `sk_live_…`) |
| `STRIPE_PRICE_ID` | Recurring Price id for $9/month (`price_…`) |
| `STRIPE_WEBHOOK_SECRET` | Signing secret for `/api/billing/webhook` (`whsec_…`) |
| `STACKPICK_BILLING_PUBLIC=1` | Opt-in to show Checkout / Portal in the UI |

Webhook endpoint (when enabled): `https://stackpick.apps.grok.bot/api/billing/webhook`
