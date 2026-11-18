# Stackpick

Searchable explorer for the [public-apis](../README.md) catalog, with shortlist stacks and partner placements.

## Develop

```bash
# refresh catalog JSON from the root README
python3 scripts/parse_apis.py

cd explorer
npm install
npm run dev
```

## Build

```bash
cd explorer
npm run build
npm run preview
```

## Monetization hooks

- **Partner strip** — referral links to production API suites (clearly labeled).
- **Pro waitlist** — email capture for export / sync / health-check features ($9/mo planned).
- **Free shortlist cap** — 5 APIs locally; larger stacks gate toward Pro.
