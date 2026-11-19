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

## Billing model

- **Free:** browse + shortlist up to 5 APIs.
- **Signed in:** account session (required before checkout).
- **Pro ($9/mo via Stripe):** export, share sync, health checks, shortlist up to 25.

When `STRIPE_SECRET_KEY` + `STRIPE_PRICE_ID` are unset (local sample), confirmed sign-in still unlocks Pro so demos keep working.

### Stripe secrets

| Secret | Purpose |
| --- | --- |
| `STRIPE_SECRET_KEY` | Server SDK (`sk_test_…` / `sk_live_…`) |
| `STRIPE_PRICE_ID` | Recurring Price id for $9/month (`price_…`) |
| `STRIPE_WEBHOOK_SECRET` | Signing secret for `/api/billing/webhook` (`whsec_…`) |

Webhook events to enable: `checkout.session.completed`, `customer.subscription.created|updated|deleted`, `invoice.payment_failed`.

Endpoint URL: `https://stackpick.apps.grok.bot/api/billing/webhook`
