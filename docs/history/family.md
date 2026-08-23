# Family History

## 2026-08-08 — Suggestions endpoint parent resolution
Web: extracted a `resolveAthleteId` helper so a parent's dismiss/complete of a suggestion resolves to the linked player before scoping the update.

## 2026-08-09 — Family shared player profile
Fix so a parent can view AND edit the athlete's player profile (per-user `user_preferences` rows had the parent seeing stale/empty data). Phases 1–4 complete: RLS + athlete-aware read/write landed.
