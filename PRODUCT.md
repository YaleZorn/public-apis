# Stackpick

## Purpose

Help developers pick a working public API stack in minutes instead of scrolling a 2000-line README.

## Users

Primary: indie hackers and product engineers evaluating APIs for a new feature or MVP.

## Jobs

- Search and filter the curated public-apis catalog by category, auth, HTTPS, and CORS.
- Save a shortlist (“stack”) of candidate APIs.
- Discover production-ready partner APIs when free options are not enough.

## Mechanism

Structured search over the public-apis README, plus a shortlist builder and partner placements that fund the product.

## Monetization (planned)

1. Partner / sponsored slots with referral links (APILayer and similar).
2. Freemium Pro: export stacks, sync shortlists, API health checks — waitlist in v1.
3. Later: paid featured listings for API providers.

## Platform

web

## Stack

Delegated: Vite + vanilla HTML/CSS/JS static app under `explorer/`.

## Constraints

- Catalog data is derived from `README.md` (community curated).
- Do not invent API capabilities, pricing, or uptime claims.
- Partner links must be clearly labeled as partners / sponsored.

## Assumptions (inferred — user asked to pick, ship, and monetize without a live interview)

- English UI is acceptable for a global developer audience.
- First surface is Operate (search + shortlist), with a light Persuade hero.
- No payment processor in v1; Pro is waitlist-only.
- App lives in `explorer/` so the upstream README contribution workflow stays intact.
