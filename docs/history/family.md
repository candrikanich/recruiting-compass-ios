# Family History

## 2026-09-03 — Family entitlement plumbing (Phase 0)
Shipped the free-launch entitlement gate across web, iOS, and prod DB: a `family_subscriptions` row per family (`founding` before the pricing flip, `trialing` after) enforced by a `family_can_write` RESTRICTIVE RLS policy, an `EntitlementStore`/`useEntitlement` client layer exposing a Settings "Plan" row, and a ToS subscription clause — all gates open at launch, no paywall or IAP yet. Follow-up PR #595 (merged 2026-09-03) locked down entitlement-function grants; the broader web API service-role RLS bypass remains open, tracked as [web #912](https://github.com/candrikanich/recruiting-compass-web/issues/912).

## 2026-08-08 — Suggestions endpoint parent resolution
Web: extracted a `resolveAthleteId` helper so a parent's dismiss/complete of a suggestion resolves to the linked player before scoping the update.

## 2026-08-09 — Family shared player profile
Fix so a parent can view AND edit the athlete's player profile (per-user `user_preferences` rows had the parent seeing stale/empty data). Phases 1–4 complete: RLS + athlete-aware read/write landed.
