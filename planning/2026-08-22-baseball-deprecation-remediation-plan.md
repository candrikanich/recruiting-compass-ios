# Baseball → Sport-Agnostic Remediation Plan (Web + iOS)

**Date:** 2026-08-22
**Source audit:** `planning/2026-08-22-baseball-hardcoding-audit.md`
**Parity:** every phase lands on **both** web (Nuxt/Vue + Supabase) and iOS (SwiftUI), plus shared DB.

## Decisions locked (2026-08-22)

1. **Nil sport → force at onboarding.** `primary_sport` becomes required. Baseball fallback (`defaultOrder = baseball`) gets removed; nil never reaches vocab lookups. Existing null-sport rows need a backfill/prompt migration.
2. **Recruiting-service IDs → keep PG/PBR gated**, but research + add common services for other sports (NCSA cross-sport, Hudl, sport-specific ranking sites). New per-sport services registry.
3. **`bats`/`throws` → leave gated to baseball/softball**, but each sport surfaces its **own** athlete-model concepts (shooting hand, dominant foot, stance, …). Registry-driven per-sport attribute set.
4. **DB-seeded templates + timeline tasks → tokenize now, per-sport later.** Strip baseball words to `{{sport}}`/neutral tokens first; per-sport polish is a later pass.

---

## Phase ordering rationale

Phase 1 first because it's the only tier that **actively breaks the UI** for non-baseball athletes (raw metric keys, empty charts, unreachable sport filter). Phase 2 fixes data correctness + enables killing the fallback. Phase 3 adds real multi-sport model depth (the two scope-expanders). Phase 4 = DB content. Phase 5 = cosmetic copy/brand.

---

## Phase 1 — Registry-bypass fixes (athlete-breaking) 🔴

Goal: no non-baseball athlete ever sees a raw metric key, wrong label, or empty analytic.

### Web
- **P1 Performance UI → route through `utils/metrics/canonical.ts`.** Replace the hand-rolled 7-metric label/icon/unit maps in: `PerformanceDashboard.vue`, `PerformanceRadarChart.vue`, `PerformanceChart.vue`, `MetricCategoryChart.vue`, `PerformanceSummary.vue`, `pages/performance/index.vue`, `pages/performance/timeline.vue`, `pages/events/[id].vue`, `pages/analytics/index.vue`, `performanceExport.ts`, `textTemplates.ts`. Use `metricTypesForSport(sport)` + `getMetricDef`.
- **useEventMetricsSection.ts:32-44,60-68** — replace baseball label map + closed baseball union type with registry lookup + open metric_type.
- **P3 `AdvancedFilters.vue:107-111,242-248`** — sport filter options + metric filter options from registry, not hard-coded baseball/softball.
- **"Hitting/Pitching" section headers** (`timeline.vue`, `PerformanceDashboard.vue`) — drive from metric category metadata in registry, not literal baseball categories.

### iOS
- **P4 `AnalyticsServiceImpl.swift:165-186` + `AnalyticsDashboardViewModel.swift:471-472`** — performance-correlation must pick correlated metrics from the sport's registry (or hide the card when the sport lacks a correlatable pair). Kill hard `.exitVelo`/`.velocity` filter + "Exit Velo vs Fastball Velo" label.
- **P5 `NewMetricData.swift:4`** — default `metricType` = first registry metric for the athlete's sport, not `.velocity`.
- **P6 `MetricRow.swift:10-19`** — add an `icon` field to `MetricRegistry` defs; map from registry instead of 7 baseball keys. `MetricRow.swift:15` `battingAvg → "baseball"` SF Symbol goes away.
- **P6 `MetricFormState.swift:51`** — read decimal digits from `MetricRegistry.def(for:).format` instead of special-casing `.battingAvg`/`.era` (fixes `on_base_pct`/`slugging_pct` mis-format).

**Exit criteria:** pick a non-baseball sport (e.g. Basketball) end-to-end on both apps — metrics log, chart, filter, and analytics all show correct labels. Parity check per `platform-parity` skill.

---

## Phase 2 — DB seed correctness + fallback removal 🟠

- **P2 `20260902000000_seed_sports_and_positions.sql:15,19`** — new migration: `Hockey → Ice Hockey` (match registry key), Softball `has_position_list = true`. Audit every seeded sport name against `SPORT_POSITIONS`/`SPORT_METRICS` keys; fix all mismatches.
- **`server/migrations/029_create_positions_table.sql:37`** — baseball-only positions seed → seed from full sport/position map (or retire table if unused).
- **Force sport at onboarding (decision #1):** make `primary_sport` required in both onboarding flows (`pages/onboarding/index.vue` + iOS onboarding); backfill migration for existing null-sport rows (prompt on next login or infer). 
- **Kill baseball fallback (P7):** once nil is impossible — iOS `MetricRegistry.swift:38-39` + web `canonical.ts:283,306-308`. Fallback becomes empty/neutral safety net, not baseball.
- **Retire legacy `utils/positions.ts` (web):** migrate the 2 sport-agnostic helpers still imported by `usePlayerDetailsForm.ts` into `positions/canonical.ts`, delete `BASEBALL_POSITIONS` module + its test.

**Exit criteria:** every seeded sport resolves to a non-empty position + metric set; no `defaultOrder = baseball` remains; `grep BASEBALL_POSITIONS` web = 0.

---

## Phase 3 — Per-sport athlete model (decisions #2 + #3) 🟡 — biggest lift

Two new registries. **Needs a research spike before build.**

### Spike 3a — per-sport athlete attributes (#3)
Design a sport-keyed attribute registry (parallel to metrics/positions): baseball/softball → bats/throws; basketball/hockey → shooting hand; soccer → dominant foot; etc. Decide storage: typed columns vs JSONB `athlete_attributes`. Output: field list per sport + schema.

### Spike 3b — per-sport recruiting services (#2)
Research common recruiting services per sport (NCSA is cross-sport; Hudl broad; PG/PBR baseball; sport-specific ranking sites). Output: services registry keyed by sport, with URL + label + ID-field.

### Build (after spikes approved)
- Schema migration (both platforms + Zod + Swift models): generalized attribute + service storage.
- `AthleticsTab.swift` / `PlayerDetailsAthleticsTab.vue` render attributes + services from registry by sport; keep PG/PBR gated to baseball/softball.
- Update profile display + edit-history label maps (`useProfile.ts`, `useProfileEditHistory.ts`, iOS equivalents) to be registry-driven.
- Public profile + `agent-content/profile.ts` emit gated/registry-driven service IDs, not hard-coded `prep_baseball_id`.

**Exit criteria:** basketball athlete sees shooting hand + relevant services; baseball athlete unchanged; no hard-coded `prep_baseball_id` in server output.

---

## Phase 4 — DB-seeded content tokenization (decision #4, P8) 🟢

- **Timeline task seeds** (`20260727000002_*.sql`, `server/migrations/003_seed_timeline_tasks.sql`) — replace "baseball camp", "baseball-specific training", "Beyond Baseball" with `{{sport}}`/neutral tokens. Migration to update existing rows.
- **Coach-outreach templates** (`communication_templates` table, ~33) — audit bodies for baseball phrasing; tokenize with `{{sport}}` + existing `[[gate|text]]` optional-token syntax.
- Verify token renderer resolves `{{sport}}` on both apps (iOS `TemplateContextBuilder`, web `useCommunicationTemplates`). Add if missing.

**Exit criteria:** render a timeline + a template for a non-baseball sport — no "baseball" appears unless the athlete's sport is baseball.

---

## Phase 5 — Copy / branding cleanup 🔵 (cosmetic, lowest risk)

- **iOS:** showcase/summer prose (`SuggestionHelpContent.swift`, `HelpSectionDetailView.swift`), QuickComm hint (`QuickCommunicationView.swift:659`), remaining xcstrings. Most metric-label strings already registry-sourced.
- **Web:** `parentReassurance.ts`, `parentWorries.ts`, `phaseCalculation.ts:87`, `printExport.ts:120`, `reportExport.ts:117`, `ncaaRecruitingCalendar.ts`/`ncaaDatabase.ts` comments, ⚾ emojis (6 files), `useGeocoding.ts`/`geocoding.ts` User-Agent, `TemplateEditor.vue` placeholders.
- **Marketing docs** (`docs/marketing/*.md`) — collateral, not live pages; batch-edit or defer.
- **Brand "Baseball Recruiting Compass"** (`printExport`, `reportExport`, User-Agent) → sport-agnostic name. **Product decision — flag, don't guess.**

**Exit criteria:** `grep -ri baseball` on both app source (excluding registry sport-name entries + gated baseball features) → only intentional baseball-sport references remain.

---

## Open items needing input
- **Storage shape** for Phase 3 attributes/services (typed columns vs JSONB) — decide in spike.
- **Null-sport backfill** strategy (Phase 2) — prompt-on-login vs infer vs bulk-default.
- **Brand rename** (Phase 5) — product call on new name.
- **iOS analytics correlation (P4):** confirm web analytics doesn't have the same baseball-lock (web agent didn't flag it — verify).

## Suggested execution
Phases 1→2 back-to-back (unblock athletes + fix data). Phase 3 gated on the two spikes. Phase 4 independent (can parallel Phase 3). Phase 5 anytime / trailing. Each phase: build-verify both platforms, parity check, commit per platform.
