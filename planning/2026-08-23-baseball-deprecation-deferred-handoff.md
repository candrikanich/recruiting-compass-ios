# Handoff — Baseball-Deprecation Deferred Items (discovery + planning)

**Date:** 2026-08-23 · **For:** a fresh session to pick up the REMAINING sport-agnostic work.
Read this first, then `planning/2026-08-22-baseball-deprecation-remediation-plan.md` (master plan),
`planning/2026-08-22-phase3-registry-contract.md` (registry contract incl. Services v2 table),
`planning/2026-08-23-metric-grouping-contract.md` (grouping spec), and memory
`baseball-deprecation-parity.md`.

## Context (what already shipped)
5-phase effort made both apps sport-agnostic (was baseball-only). ALL 5 PHASES MERGED:
- P1 registry-bypass fixes (iOS #46 / web #425)
- P2 DB seed parity + kill baseball fallback + require sport at onboarding + null-sport login gate (iOS #47 / web #427)
- P3 per-sport athlete attributes + recruiting services registries (iOS #48 / web #429)
- P4 de-baseball seeded template + timeline tasks (web #430)
- P5 copy cleanup + rebrand "The Recruiting Compass" (iOS #49 / web #431)

Two prod migrations applied (Supabase project `xpxzhqghxecsjhvklsqg` "Recruiting Tracker 2025"):
`fix_sport_registry_parity`, `debaseball_seed_content`. Registries are BYTE-IDENTICAL across
platforms and are the pattern to keep matching: iOS `Core/Utilities/{MetricRegistry,CanonicalPositions,
AthleteAttributes,RecruitingServices,RecruitingLinks}.swift`, web `utils/{metrics,positions,attributes,
services}/canonical.ts` + `utils/recruitingLinks.ts`.

## UPDATE 2026-08-23 (end of session): buildable items DONE + PR'd
Branch `feat/deferred-cleanup` → **iOS PR #50 (base main), web PR #432 (base develop)** — awaiting merge.
Contains: (1) prune dead `isBaseballOrSoftball`, (2) Services v2 (10 services, byte-identical, public-card
wired), (3) metric grouping narrow (log picker, 6 sports). All green (iOS build 0 / web type-check+lint 0,
tests pass). Registries byte-identical (URLs + categories verified). Once #50/#432 merge, the ONLY remaining
items are the 3 DISCOVERY tasks below (items 3, 4 + services deferred-4). Everything in "in-flight state"
below is now historical.

## Current in-flight state (verify before acting)
Active branch `feat/deferred-cleanup` in BOTH repos (NOT yet pushed/PR'd):
- iOS worktree `.claude/worktrees/deferred-cleanup` — commits: `8720ff7a` (prune dead `isBaseballOrSoftball`), `f29edc5d` (services v2). Release.xcconfig copied in.
- web worktree `.worktrees/deferred-cleanup` — commit `6a0f9ab1` (services v2).
- **Services v2 = DONE + committed** (10 services, byte-identical both platforms, full https signupUrls verified matching, public-profile card wired). iOS build 0 / web type-check+lint 0.
- **Metric grouping (narrow) = IN PROGRESS** (2 agents, per `planning/2026-08-23-metric-grouping-contract.md`). NEXT SESSION: check `git status` — if grouping edits present + green, commit; else re-run from that spec.
- Then: rebase `feat/deferred-cleanup` onto fresh `origin/main` (iOS) / `origin/develop` (web), PR both (web push `--no-verify`).
- iOS main = `6a9b48ed`, web develop = `d14a6b23` (all 5 phases merged).
- Minor known gap (services): web `ProfilePreview.vue` projection omits v1 `ncsa_id`/`hudl_url` (pre-existing, endpoint has them) — tidy if touching that file.

Web note: pre-push hook `npm run lint` crashes (Abort trap 6) — push with `--no-verify` after running type-check + lint directly.

---

## REMAINING WORK (priority order)

### 1. Services v2 — READY, likely mid-build (finish it)
10 verified sport-specific recruiting services to add to the services registry. Full drop-in table
(keys, urlTemplate, valueKind, sports) is in `planning/2026-08-22-phase3-registry-contract.md` →
"Services v2" section. Zero DB migration (flat JSONB keys). Renderers already registry-driven.
- id-kind (template `{value}`): athletic_net_id, swimcloud_id, utr_id, tennis_recruiting_id, elite_prospects_id, sportsrecruits_id, concept2_id
- url-kind (store full URL, like Hudl): milesplit_url, on3_url, sports247_url
- **DEFERRED-4 (no verifiable public URL — need a live device profile check to capture a real URL before adding):** TopDrawerSoccer (Soccer), Junior Golf Scoreboard (Golf), TrackWrestling + FloWrestling (Wrestling). These are the discovery task for services.
- **Verification caveats to confirm on-device:** Athletic.net `/athlete/{id}` + Elite Prospects `/player/{id}` rely on a bare-id→slug 301 redirect — confirm still redirects (agent's fetch hit 403 bot-protection). Concept2 + Tennis Recruiting profiles may be privacy/login-gated (link still valid, just say so in UI copy, not the template).

### 2. Metric grouping (narrow) — APPROVED, spec ready, NOT built
Build per `planning/2026-08-23-metric-grouping-contract.md`: add a per-sport `SPORT_METRIC_GROUPS` /
`sportMetricGroups` map (NOT a `category` field on MetricDef — shared key `assists` = Setting/Attacking
clash) for 6 dense sports (Baseball, Softball, Basketball, Football, Track & Field, Volleyball). Wire
into the LOG-METRIC PICKER only (iOS `MetricFormView.swift` `Section`, web `LogMetricModal.vue`
`<optgroup>`). Other 11 sports render flat (no entry, zero change). Dashboard grouping deferred.
Dispatch AFTER services v2 is committed (avoid concurrent builds in the shared worktree).

### 3. Per-sport NCAA recruiting calendar — DEFERRED, needs a data source (discovery)
`utils/ncaaRecruitingCalendar.ts` `BASEBALL_SIGNING_PERIODS_2026` holds baseball signing/contact dates
and is shown regardless of sport → **non-baseball users see WRONG dates** (known, accepted for now).
Real fix needs accurate NCAA signing + contact-period dates PER SPORT PER DIVISION (D1/D2/D3) from a
maintained source, plus an upkeep plan (dates change yearly). Decision was DEFER (do not guess dates).
Discovery task: find an authoritative data source; design a `SPORT_RECRUITING_CALENDAR` structure
(sport → division → periods) mirroring the registry pattern; decide render (per-sport, or hide when
unknown). Until built, consider whether to hide/label the calendar for non-baseball to avoid wrong info.

### 4. `positions` DB table drop — reclassified RISKY, needs audit (do NOT blind-drop)
`positions` table: 68 seeded rows, ZERO app queries (registry drives positions client-side), BUT 2
inbound FKs from `users.primary_position_id` / `secondary_position_id`, and 2 of 21 users have
`primary_position_id` populated. Dropping requires altering the `users` schema + touching real data.
Discovery task: grep BOTH repos for any read of `primary_position_id`/`secondary_position_id` (server
+ client + generated types usage, not just the table). If truly unread, plan: null the 2 rows / drop
the FK columns / drop the table (one migration, CASCADE-safe). If read anywhere, leave it. Low value —
only do if clean.

### 5. Minor / documented (probably skip)
- iOS template `{{sport}}` token reads only `prefs.primary_sport`; web reads FK (`users.primary_sport_id`
  → `sports.name`) first, then prefs. Never diverges in practice (onboarding always writes prefs). Align
  only if it ever bites.
- `category`-on-`MetricDef` is an ANTI-PATTERN (shared-key clash) — if anyone proposes it, use the
  per-sport group map instead (see item 2).
- iOS `MetricDef` has no `icon` field but web does (web icon is emoji, iOS uses SF Symbol on the def) —
  intentional per-platform presentation, not a parity bug.

## Parity discipline (applies to every item)
Any registry change lands BYTE-IDENTICAL on both platforms: same key strings, same option/token values,
same urlTemplate strings, same sport-membership arrays. Only display labels may localize. New flat-JSONB
keys need: iOS PlayerDetails optional var + snake_case CodingKey + `stringFieldKeyPaths`; web
`types/models.ts` field + `utils/validation/schemas.ts` Zod. No DB migration for flat keys.

## How to resume
1. `git -C <each worktree> status` + build/type-check to see if services v2 landed; commit or redo.
2. Rebase `feat/deferred-cleanup` onto fresh `origin/main` (iOS) / `origin/develop` (web).
3. Build metric grouping (item 2).
4. Commit + PR both (iOS→main, web→develop; web push `--no-verify`).
5. Items 3 (calendar) + 4 (positions) are DISCOVERY tasks — brainstorm/plan before building.
