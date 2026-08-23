# Baseball Hard-Coding Audit — Web + iOS

**Date:** 2026-08-22
**Goal:** Find everything still hard-coded to baseball so it can be driven by the athlete's **primary sport** (which may not be baseball).

## TL;DR

Both apps already have a genuine **sport-aware registry** (17 sports):
- iOS: `MetricRegistry` + `CanonicalPositions`
- Web: `utils/metrics/canonical.ts` + `utils/positions/canonical.ts`

The problem is **not** a missing abstraction — it's that many surfaces **bypass the registry** or carry **baseball-only fields/copy**. Three recurring root causes:

1. **Registry bypass** — a hand-rolled baseball metric/position map used instead of the sport registry. Non-baseball athletes see raw keys, wrong labels, or empty analytics.
2. **Baseball as the nil/unknown fallback** — `defaultOrder = baseball` on both platforms. An athlete with null/unrecognized sport gets baseball vocabulary, not neutral/empty.
3. **Baseball-only data model + copy** — `bats`/`throws`, Perfect Game / Prep Baseball IDs, showcase/travel-ball prose, "Baseball Recruiting Compass" branding. Some are correctly sport-gated; the fields/copy themselves have no other-sport analogue.

**Web has the larger defect surface** (whole Performance UI hard-codes the 7-metric baseball map; legacy `utils/positions.ts` still live; coach search only offers baseball/softball). **iOS is cleaner** (registry used more consistently) but has a fully baseball-locked analytics correlation, a `.velocity` default, and icon/digit special-casing.

---

## Priority fixes (highest impact first)

| # | Platform | Issue | Files |
|---|----------|-------|-------|
| P1 | Web | Entire Performance UI hard-codes the 7-metric baseball label/icon map; ignores `metrics/canonical.ts`. Non-baseball metrics show raw keys. | `PerformanceDashboard.vue`, `PerformanceRadarChart.vue`, `PerformanceChart.vue`, `MetricCategoryChart.vue`, `PerformanceSummary.vue`, `pages/performance/*`, `pages/events/[id].vue`, `useEventMetricsSection.ts`, `AdvancedFilters.vue` |
| P2 | Web | DB seed mismatches break registry lookups: sport seeded as **"Hockey"** vs registry key **"Ice Hockey"**; **Softball** flagged `has_position_list=false` but registry gives it full positions. | `supabase/migrations/20260902000000_seed_sports_and_positions.sql:15,19` |
| P3 | Web | Coach-search Sport filter offers only baseball/softball/other — other 14 sports unreachable. | `components/Search/AdvancedFilters.vue:107-111` |
| P4 | iOS | Performance-correlation analytic hard-filters `.exitVelo`/`.velocity`, labels "Exit Velo vs Fastball Velo" → empty/wrong for every non-baseball sport. | `AnalyticsServiceImpl.swift:165-186`, `AnalyticsDashboardViewModel.swift:471-472` |
| P5 | iOS | New event-metric defaults to `.velocity` (baseball pitching) regardless of sport. | `Events/Models/NewMetricData.swift:4` |
| P6 | iOS | Metric icon + decimal-digit special-casing bypass registry (only baseball keys mapped; `on_base_pct`/`slugging_pct` mis-formatted). | `Dashboard/Components/MetricRow.swift:10-19`, `Performance/Models/MetricFormState.swift:51` |
| P7 | Both | `defaultOrder = baseball` fallback for nil/unknown sport. Decide: neutral set vs empty vs baseball. | iOS `MetricRegistry.swift:38-39`; Web `utils/metrics/canonical.ts:283,306-308` |
| P8 | Both | Timeline task seed copy is baseball-worded for ALL users ("college baseball camp", "baseball-specific training program"). | Web `supabase/migrations/20260727000002_*.sql`, `server/migrations/003_seed_timeline_tasks.sql` — iOS reads these from backend |

---

## iOS findings

### Copy / strings (Localizable.xcstrings + views)
- **Sport-name (9 shipped + Perfect Game×4):** `AthleticsTab.swift:214-216` ("Prep Baseball ID", prepbaseballreport.com URL); `PublicProfileSections.swift:45` ("Prep Baseball"); xcstrings 6391/6394/4156/9014.
- **Metric labels/prose (13 + 11 xcstrings):** `MetricRegistry.swift:117-138` (Fastball Velocity, Exit Velocity, Batting Average, 60-Yard Dash, Pop Time, ERA, Slugging %, WHIP, Strikeouts); `AnalyticsDashboardViewModel.swift:471` ("Exit Velocity (mph)"); `AnalyticsServiceImpl.swift:186` ("Exit Velo vs Fastball Velo"); `QuickCommunicationView.swift:659` ("a 60 time, exit velo").
- **Equipment / handedness (3):** `AthleticsTab.swift:70,79,95` ("Batting & Throwing", "Bats", "Throws") — sport-gated but baseball framing.
- **Showcase/summer prose (7 + 10 xcstrings):** `SuggestionHelpContent.swift:43-55,140`; `HelpSectionDetailView.swift:198` — baseball recruiting model assumed.
- **Positions:** literals live only in `CanonicalPositions.swift:36-37,116-117` (registry) — surfaced sport-aware. Good.

### Logic / data
- **registry-bypass (2):** `AnalyticsServiceImpl.swift:165-186` + `AnalyticsDashboardViewModel.swift:471` (P4).
- **metric-default (5):** `NewMetricData.swift:4` (P5); `MetricRow.swift:10-19` icon map (P6); `MetricFormState.swift:51` digit special-case (P6); `MetricType.swift:27-34` 8 legacy baseball static constants (anchors for every `== .velocity`); `PerformanceMetricsWidget.swift:85-100` preview-only.
- **default-sport (2):** `PlayerDetails.swift:87-90` `isBaseballOrSoftball` (`sport == "baseball" || "softball"`); `EventMetricForm.swift:12-13` baseball fallback path.
- **profile-field (3):** `PlayerDetails.swift:24-25` `bats`/`throws_`; `AthleticsTab.swift:64-110` Bats/Throws card (gated); `perfectGameId`/`prepBaseballId` columns.
- **position-list (1 soft):** `MetricRegistry.swift:38-39` `defaultOrder = baseball` (P7). Note inconsistency: `CanonicalPositions.positions(for:)` returns `[]` for unknown — safer pattern.
- **validation-range: 0.** No baseball numeric clamps found.
- **Internal keys (~15, non-visible):** `baseballFacilityAddress`/`"baseball_facility_address"` (`AcademicInfo.swift`), `"prep_baseball_id"`, `MetricRow.swift:15` `battingAvg → "baseball"` SF Symbol, various comments.

### Templates
The ~33 coach-outreach templates are **backend-seeded**, not in the iOS repo. Only baseball reference: comment `TemplateComputed.swift:109`.

### Registry used correctly (contrast)
`EventMetricForm.swift:21`, `PerformanceDashboardViewModel.swift:84`, `MetricFormView.swift:27`, `PositionChipsView.swift:9`, `TemplateComputed.swift:101,112`, `TemplateContextBuilder.swift:48-52`, `OnboardingViewModel.swift:75`.

---

## Web findings (Nuxt/Vue + Supabase)

### Copy / strings
- **Sport-name (24):** `school-preferences.vue:536`; `PublicProfileCard.vue:328`; `PlayerDetailsAthleticsTab.vue:285,299`; `useProfile.ts:40`; `useProfileEditHistory.ts:25`; `agent-content/profile.ts:42`; `phaseCalculation.ts:87`; `parentReassurance.ts:32,56`; `parentWorries.ts:111-131`; `printExport.ts:120` ("Baseball Recruiting Compass • Confidential"); `reportExport.ts:117` ("Baseball Recruiting Report"); `ncaaRecruitingCalendar.ts:3,27`; `ncaaDatabase.ts:2,17`; `useGeocoding.ts`/`geocoding.ts` User-Agent "BaseballRecruitingTracker/1.0".
- **Metric labels (~20 files):** 7-metric baseball map repeated across `pages/performance/index.vue`, `timeline.vue`, `pages/events/[id].vue`, `pages/analytics/index.vue:97`, `AdvancedFilters.vue:242-248`, `PerformanceSummary.vue:174-194` (incl. `batting_avg:"🏏"`, `strikeouts:"⚾"`), `PerformanceDashboard.vue`, `MetricCategoryChart.vue`, `PerformanceRadarChart.vue`, `PerformanceChart.vue`, `useEventMetricsSection.ts`, `performanceExport.ts`, `textTemplates.ts`. Plus "Hitting/Pitching" section headers (`timeline.vue`, `PerformanceDashboard.vue`). Plus Perfect Game (3), travel ball (`statusScoreCalculation.ts:292,309`), showcase season (`RecruitingCalendar.vue:158`).
- **Equipment (4):** `PlayerDetailsAthleticsTab.vue:79`, `useProfile.ts:31`, `useProfileEditHistory.ts:16`, `player-details.vue:150`.
- **Template scaffolding (3):** `TemplateEditor.vue:59,245` ("Baseball Recruitment Inquiry", `position:"Shortstop"`), `templateVariables.ts:54`. Bodies are DB-seeded.
- **Marketing docs (~30 lines / 5 files):** `docs/marketing/*.md` — landing/feature/email/blog/press/social. Not rendered pages but user-facing collateral (#BaseballRecruiting, @BaseballAmerica, "baseball blue", etc.).
- **⚾ emoji (6):** `reports/timeline.vue`, `InteractionStats.vue`, `UpcomingDeadlines.vue`, `EventsSummary.vue`, `InteractionForm.vue`.

### Logic / data
- **registry-bypass (4):** `useEventMetricsSection.ts:32-44` baseball label map + `:60-68` closed baseball union type; `usePlayerDetailsForm.ts:6-9` imports legacy `utils/positions.ts`; `pages/onboarding/index.vue:426-444` hand-listed sports vs registry.
- **position-list (2):** `utils/positions.ts:12-75` entire legacy `BASEBALL_POSITIONS` module still live; `AdvancedFilters.vue:107-111` sport filter (P3).
- **metric-default (3):** `utils/metrics/canonical.ts:283,306-308` `defaultOrder = baseball` (P7) + doc at `:22`/`LogMetricModal.vue:23`.
- **schema-field (6):** `types/models.ts:369-370` `bats`/`throws`; `validation/schemas.ts:297-298` Zod; `models.ts:378,468` `prep_baseball_id`/`perfect_game_id`; `PlayerDetailsAthleticsTab.vue` gated fields; `database-helpers.ts:81` `baseball_facility_address` on School; `useProfile.ts`/`useProfileEditHistory.ts` label maps.
- **db-migration/seed (5):** `20260902000000_seed_sports_and_positions.sql:15` Hockey vs Ice Hockey (P2), `:19` Softball `has_position_list=false` (P2); `server/migrations/029_create_positions_table.sql:37` baseball-only seed; timeline task copy (P8); `20260820000000_contact_window_rules.sql` — baseball/softball/football explicit rows + `'*'` default (soft, mechanism is sport-agnostic).
- **api-route (1):** `server/api/public/profile/[slug].get.ts:165-166` + `agent-content/profile.ts:41-42` emit `prep_baseball_id` unconditionally.

### Registry used correctly (contrast)
`LogMetricModal.vue`, `metricFormat.ts`, `PublicProfileCard.vue`, `PlayerDetailsAthleticsTab.vue` (positions), `useSportsPositionLookup.ts`, onboarding position dropdown, `usePlayerDetailsForm.ts` load/save path.

---

## Cross-platform parity notes

- **Same baseball fallback on both:** `defaultOrder = baseball` (iOS `MetricRegistry.swift:38-39` / Web `canonical.ts:283`). Fix together (P7).
- **Same baseball-only fields on both models:** `bats`/`throws`, `prep_baseball_id`, `perfect_game_id`, `baseball_facility_address`. Any schema change must land on both platforms + DB.
- **Web-only defect:** legacy `utils/positions.ts` and the hard-coded Performance metric maps have **no iOS equivalent** — iOS Performance already routes through the registry. Web needs to catch up to iOS here.
- **iOS-only defect:** analytics correlation baseball-lock (P4) — check whether web's analytics has the same issue (not flagged by web agent; verify).
- **Shared backend:** coach-outreach templates + timeline task seeds live in Supabase. De-baseballing those is a **DB/seed change** affecting both apps at once — needs sport-parameterization strategy, not just a string swap.

## Open questions for the team

1. **Fallback policy** for null/unknown primary sport: neutral generic metrics, empty, or keep baseball? (drives P7)
2. **Baseball-only external IDs** (Perfect Game, Prep Baseball): keep gated as-is, or generalize to a per-sport "recruiting service ID" concept?
3. **`bats`/`throws`:** generalize to a sport-driven handedness/laterality concept (shooting hand, dominant foot), or leave gated to baseball/softball?
4. **Templates + timeline tasks** (DB-seeded): sport-parameterize via tokens (`{{sport}}`) or maintain per-sport template sets? Biggest content lift.
5. **Marketing branding** ("Baseball Recruiting Compass", geocoding User-Agent): rename to sport-agnostic brand — product decision.
