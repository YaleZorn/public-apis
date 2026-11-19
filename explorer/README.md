# Stackpick

Searchable explorer for the [public-apis](../README.md) catalog with shortlists, partner placements, Pro waitlist, share links, export, and health checks.

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
| Shortlist | localStorage (+ Pro cap 25) |
| Pro waitlist | `POST /api/waitlist` → DB |
| Share stack | `POST /api/stacks` → `/?stack=CODE` |
| Load shared | `GET /api/stacks/[code]` |
| Export | JSON / CSV download (Pro) |
| Health | `POST /api/health` (catalog URLs only, Pro) |
| Partners | labeled referral links |
