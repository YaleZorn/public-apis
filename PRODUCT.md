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

## Monetization

1. Partner / sponsored slots with referral links (APILayer and similar).
2. Freemium Pro via waitlist unlock (planned $9/mo billing later): export, shareable stacks, health checks, larger shortlist.
3. Later: paid featured listings for API providers + Stripe checkout.

## Platform

web

## Stack

Delegated: Next.js app under `explorer/` with Postgres (`cursor-app.json`) and PGlite local fallback.

## Constraints

- Catalog data is derived from `README.md` (community curated).
- Do not invent API capabilities, pricing, or uptime claims.
- Partner links must be clearly labeled as partners / sponsored.

## Assumptions (inferred — user asked to pick, ship, and monetize without a live interview)

- English UI is acceptable for a global developer audience.
- First surface is Operate (search + shortlist), with a light Persuade hero.
- No payment processor in v1; waitlist join unlocks Pro tools on-device and persists email server-side.
- App lives in `explorer/` so the upstream README contribution workflow stays intact.
- Health checks only probe curated catalog URLs (SSRF guard).
