# Design — Per-Sport NCAA Recruiting Calendar (web + iOS)

**Date:** 2026-08-23 · **Status:** DESIGN (awaiting review) · **Type:** Architectural, multi-phase, cross-repo
**Related:** `planning/2026-08-23-baseball-deprecation-deferred-handoff.md` (item 3), memory `baseball-deprecation-parity.md`
**Repos:** `recruiting-compass-web` (develop) + `recruiting-compass-ios` (main)

---

## 1. Problem

`utils/ncaaRecruitingCalendar.ts` hard-codes a **baseball-only** D1 recruiting calendar
(`RECRUITING_CALENDAR_2026` / signing periods) and serves it to **every** athlete regardless of
sport. Non-baseball users see **wrong dead/quiet/contact windows and wrong milestones**. This is not
cosmetic: the dates feed `server/utils/ruleEngine.ts` (`isDeadPeriod`) which generates timeline
tasks, plus the dashboard dead-period message, the `RecruitingCalendar` widget, and timeline
milestones. iOS has no calendar data at all — only a `recruitingCalendar` widget-visibility bool.

Goal: make the recruiting calendar **sport-aware and division-aware** across both platforms so the
app is usable by all HS athletes, sourced from NCAA's official calendars, with a durable refresh plan.

## 2. Goals / Non-goals

**Goals**
- Sport-correct recruiting periods + signing/milestone dates for all 17 app sports.
- Division-aware (D1/D2/D3), athlete can view any division.
- Gender-aware where NCAA splits calendars; graceful fallback when gender unknown.
- Byte-identical calendar registry + resolver on web and iOS (registry-parity discipline).
- Durable quarterly job that flags when NCAA publishes the next cycle.

**Non-goals**
- No automated PDF parsing (NCAA calendars are graphical grids; auto-parsed compliance dates are
  too risky). Data is hand-transcribed and human-verified.
- No per-school (FBS vs FCS is a school property, not an athlete one) auto-detection — handled by a
  view toggle.
- No historical calendars — current cycle (2026-27) only, refreshed annually.

## 3. Source of truth (researched 2026-08-23)

NCAA publishes official per-sport D1 recruiting-calendar PDFs at a stable S3 pattern:

```
https://ncaaorg.s3.amazonaws.com/compliance/recruiting/calendar/{SEASON}/{SEASON}D1Rec_{CODE}RecruitingCalendar.pdf
e.g. .../2026-27/2026-27D1Rec_MBARecruitingCalendar.pdf
```

2026-27 distinct D1 codes: `FBS`, `FCS`, `MBA`, `MBB`, `MGO`, `MLA`, `SVB` (beach VB, not app),
`WBB`, `WLA`, `WSB`, `WVB`, `XCTF`, plus `Other` (the shared default; filename uses an en-dash:
`2026–27D1Rec_OtherRecruitingCalendar.pdf`). Football breaks the infix mold
(`FBSRecruitingCalendar` / `FCSRecruitingCalendar`). D2 publishes **one** combined
`2026-27D2Rec_RecruitingCalendar_AllSports.pdf`. D3 publishes no per-sport calendar.

**NCAA default (sports with no established calendar → `Other`):** no specified recruiting periods
except enumerated dead + quiet periods; any date not designated dead/quiet is a contact period.
Non-calendar sports are also capped at seven recruiting opportunities per prospect.

### 3.1 App sport → NCAA calendar mapping

| app sport      | D1 resolution                | notes |
|----------------|------------------------------|-------|
| Baseball       | `MBA`                        | men's only |
| Softball       | `WSB`                        | women's only |
| Basketball     | gender → `MBB` / `WBB`        | split by gender |
| Football       | subdivision toggle → `FBS` / `FCS` | school property; view toggle, default FBS |
| Track & Field  | `XCTF`                       | combined XC+Track PDF |
| Cross Country  | `XCTF`                       | same PDF as Track |
| Volleyball     | `WVB`                        | women's indoor; men's indoor → `Other` (via gender) |
| Golf           | gender → `MGO` / `Other`     | no WGO published; women's golf → Other |
| Lacrosse       | gender → `MLA` / `WLA`       | split by gender |
| Soccer         | `Other`                      | no distinct 2026-27 calendar |
| Swimming       | `Other`                      | |
| Tennis         | `Other`                      | |
| Wrestling      | `Other`                      | |
| Ice Hockey     | `Other`                      | |
| Field Hockey   | `Other`                      | special bylaw rules but no standalone calendar |
| Rowing         | `Other`                      | NCAA sponsors women's rowing only |
| Water Polo     | `Other`                      | |

**Division behavior:** D1 = per-key data above. D2 = the single AllSports calendar for **every**
sport. D3 = fall back to `Other` (or "no periods beyond dead/quiet"). Athlete chooses division in
the view; default D1.

## 4. Gender field (Phase 1 foundation)

No gender/sex column exists anywhere in the DB (verified). Add `gender` as an optional profile enum.

- **Storage:** the `user_preferences` **`player_details` JSON blob** (JSONB, schema-less → **no DB
  migration**), mirroring the existing optional profile enums `campus_size_preference` /
  `cost_sensitivity` (blob-only on both platforms, confirmed via recon). **Not** a `users` column.
  Rationale: eliminates migration + `database.ts` regen + column whitelist + blob↔column sync
  trigger, and the calendar resolver reads gender off the already-loaded profile. If P3's
  server-side rule engine later needs a queryable column, add it then (YAGNI).
- **Values:** `male | female | other | prefer_not_to_say`, nullable/optional.
- **Resolution rule:** `male`→men's calendar, `female`→women's calendar; `other` /
  `prefer_not_to_say` / `null` → **self-select toggle** on the calendar view (M/W), default men's.
- **Web:** `types/models.ts` `PlayerDetails` field, `utils/validation/schemas.ts` `playerDetailsSchema`
  (`z.enum(...).nullable().optional()`), `utils/preferenceValidation.ts` runtime guard, `GENDER_OPTIONS`
  const + Basics-tab `<select>` + onboarding step. Family-shared parent-edit is free (settings page
  `isReadOnly=false`; both parent and player edit the one profile).
- **iOS:** `PlayerDetails.gender: String?` + snake_case `CodingKey`, `Gender` enum in `Core/Models/`
  (mirror `UserRole`, byte-identical rawValues incl. `prefer_not_to_say`), Basics-tab Picker +
  onboarding step. Persistence + parent-edit scope free (blob round-trip + `targetUserId`).
- **Privacy:** gender is optional, self-reported, used only to pick a calendar; never required to use
  the app. `prefer_not_to_say` is a first-class value, not an error state.

## 5. Calendar data structure (Phase 2, web canonical)

Mirror the existing registry pattern (byte-identical string keys across platforms).

```ts
type NcaaCalendarKey =
  | "MBA" | "WSB" | "MBB" | "WBB" | "FBS" | "FCS"
  | "XCTF" | "WVB" | "MGO" | "MLA" | "WLA" | "Other";
type Division = "D1" | "D2" | "D3";

interface RecruitingPeriod {           // existing shape, WIDENED taxonomy
  // 5 types (spike finding): baseball uses recruiting_shutdown (stricter than dead —
  // no calls/texts/correspondence at all) and has NO evaluation; basketball/football
  // use evaluation. Each sport's calendar uses only its real subset.
  type: "dead" | "quiet" | "contact" | "evaluation" | "recruiting_shutdown";
  start: string;  // ISO date (switch off `new Date("…")` per lint rule)
  end: string;    // ISO date
  description: string;
  confidence?: "HIGH" | "MEDIUM" | "LOW"; // transcription confidence (L1/L2 audit trail)
}
interface CalendarMilestone {          // signing dates, test dates, deadlines
  date: string; title: string;
  type: "test" | "deadline" | "ncaa-period" | "application" | "signing";
  url?: string; description?: string;
}
interface SportCalendar {
  periods: RecruitingPeriod[];
  milestones: CalendarMilestone[];
  source: string;      // exact NCAA PDF URL this calendar was transcribed from (Layer 1)
  verifiedOn: string;  // ISO date a human last verified against the source (Layer 1 CI guard)
}

// D1: per-key. D2: one shared AllSports SportCalendar. D3: Other/fallback.
const D1_CALENDARS: Record<NcaaCalendarKey, SportCalendar>;
const D2_ALL_SPORTS: SportCalendar;
const D3_FALLBACK: SportCalendar;      // = Other or empty-beyond-dead/quiet
```

**Resolver:**

```ts
function resolveCalendarKey(
  sport: AppSport,
  opts: { gender?: Gender | null; footballSubdivision?: "FBS" | "FCS" }
): NcaaCalendarKey
function getSportCalendar(sport, division, opts): SportCalendar
```

`SEASON = "2026-27"` constant so the annual bump is one edit. Retire `RECRUITING_CALENDAR_2026` /
`BASEBALL_SIGNING_PERIODS_2026` (keep thin re-exports only if needed to avoid a big-bang consumer
rewrite in the same commit — see Phase 3).

**Curation scope (I transcribe from 2026-27 PDFs):** all 11 distinct D1 calendars (MBA, WSB, MBB,
WBB, FBS, FCS, XCTF, WVB, MGO, MLA, WLA) + `Other` + D2 AllSports. Each period + signing date
verified against the PDF. Sources cited inline in the data file.

## 6. Rewire web consumers (Phase 3)

Point every consumer at `getSportCalendar(sport, division, opts)` instead of the baseball constant:
- `server/utils/ruleEngine.ts` — `isDeadPeriod(date, sport, division, opts)` — **kills the wrong
  timeline-task generation** for non-baseball.
- `pages/dashboard.vue` — `getDeadPeriodMessage`.
- `components/Dashboard/RecruitingCalendar.vue` (+ `DashboardCharts.vue` gating).
- `components/Timeline/UpcomingMilestones.vue`, `pages/timeline/index.vue` — `getUpcomingMilestones`.
- `scripts/seed-system-calendar.ts` — reseed against new structure if it writes calendar rows.

Athlete's sport comes from `primary_sport` (prefs) / `primary_sport_id` (FK); gender from
`users.gender`; division + football subdivision from view state (default D1 / FBS).

## 7. iOS calendar (Phase 4, new)

- `Core/Utilities/RecruitingCalendar.swift` — byte-identical `D1_CALENDARS` / `D2_ALL_SPORTS` /
  resolver (same key strings, same dates, same sport-membership).
- Wire the existing `WidgetVisibility.recruitingCalendar` bool to a real **dashboard widget**
  matching web `RecruitingCalendar.vue` (periods + upcoming milestones, division selector, M/W +
  FBS/FCS toggle when unresolved).
- Reuse `Division`, sport keys, gender from Phase 1.

## 8. Refresh job (Phase 5)

- **Durable quarterly cloud routine** (via the `schedule` skill — CronCreate is session-only and
  dies with the session). Checks the NCAA S3 pattern for the **next** season code (e.g. `2027-28`).
- On detecting a new cycle it **opens a draft GitHub issue** pre-filled with the new PDF links + the
  list of calendars to re-transcribe, and **sends an alert** (email/push) — it does **NOT** auto-parse
  or auto-write dates (Layer 5). A human transcribes; the change lands via PR (Layer 4).
- Cadence: quarterly **check**, annual **data refresh** (NCAA posts next cycle in spring/summer).
- Doc: `docs/` note on the annual transcription procedure + PDF source pattern.

## 8.1 Data integrity & change control (user-approved mitigations)

The dataset is compliance-sensitive but small and low-frequency (~annual). Governance is
code-review-based, not a runtime approval system.

- **L1 — Source-anchored + CI guard:** every `SportCalendar` carries `source` (NCAA PDF URL) +
  `verifiedOn`. A snapshot test fails CI if any date changes without bumping `verifiedOn` → no silent
  edits.
- **L2 — Cross-check (initial build), REVISED per spike:** a fully independent second source does
  NOT exist for the just-released 2026-27 calendars (third parties lag the NCAA PDF by weeks). So L2
  is satisfied by THREE weaker-but-real checks instead: (a) the PDF's own day-grid coloring
  cross-verifies its date-range labels (two redundant encodings in the same authoritative doc);
  (b) the prior-year same-sport PDF confirms period count/order/type (dates shift ±1-3 days around
  fixed anchors); (c) opportunistic milestone corroboration (signing day, contact-open) from
  NextCommit/NCSA where available. Each date carries a `confidence` (HIGH = anchor/holiday or
  externally corroborated; MEDIUM = single authoritative PDF + structural prior-year match). Because
  the PDF IS the authority, single-source MEDIUM is acceptable — but it makes L6a (disclaimer + link
  to the official PDF) more load-bearing. Extraction MUST use render-to-image + vision read; plain
  text extraction returns nothing from these graphical PDFs.
- **L3 — Plausibility test:** assert dead/quiet periods fall in expected month ranges (Thanksgiving
  dead ≈ late Nov, winter ≈ late Dec, etc.). Catches fat-finger typos (a July "dead period" fails).
- **L4 — CODEOWNERS PR approval:** the calendar data file(s) (web + iOS) require the user's review
  before merge. The PR diff *is* the approval flow — diffable, reversible, audited.
- **L6a — Runtime disclaimer + PDF link:** calendar UI shows "Based on NCAA {SEASON}, verified
  {verifiedOn} — confirm with your compliance office" + a link to the official NCAA PDF so families
  verify the primary source themselves.
- **L6b — Staleness banner:** if `today` is past the season's end and no newer data exists, show a
  "calendar may be out of date — verify" banner instead of confidently-wrong old dates.
- **Explicitly NOT building:** an in-app admin approval UI. PR review is a stronger, cheaper audit
  trail for ~annual edits.

## 9. Phasing & parity discipline

Each registry/data change lands **byte-identical** on both platforms in the same PR pair: same key
strings, same ISO date strings, same sport-membership, same resolver semantics. Only display labels
localize. New flat field (`gender`) needs: iOS `PlayerDetails` optional var + snake_case CodingKey +
`stringFieldKeyPaths`; web `types/models.ts` + Zod. `users.gender` is a real column (not flat JSONB)
→ one DB migration.

| Phase | Web | iOS | DB |
|-------|-----|-----|-----|
| 1 Gender field | Zod + preferenceValidation + models + onboarding + Basics tab | PlayerDetails + Gender enum + onboarding + Basics tab | none (JSON blob) |
| 2 Calendar data + resolver | new canonical file (curated) | — (Phase 4 mirrors) | none |
| 3 Rewire consumers | ruleEngine + timeline + dashboard | — | none |
| 4 iOS calendar | — | registry + widget | none |
| 5 Refresh job | cloud routine + doc | — | none |

Suggested PR order: P1 (both) → P2+P3 (web) → P4 (iOS) → P5. P1 ships independently (gender field is
useful on its own and de-risks the rest).

## 10. Risks / open items

- **Data accuracy** — hand-transcription is the main risk. Mitigated by the §8.1 layer stack
  (L1 source-anchor + CI guard, L2 two-source cross-check, L3 plausibility test, L4 CODEOWNERS PR
  review, L6a/b runtime disclaimer + staleness). Wrong dates = real recruiting harm.
- **`new Date("YYYY-MM-DD")` lint rule** — the existing file suppresses `local/no-date-only-string-constructor`
  everywhere. New data uses ISO strings parsed via the project's approved date util (not the raw
  constructor) to avoid re-suppressing.
- **Consumer signature churn** — adding `sport`/`gender`/`opts` to `isDeadPeriod` et al. touches
  several call sites; Phase 3 is a focused sweep, keep thin back-compat re-exports only if needed
  within the transition commit.
- **iOS calendar UI surface** — `RecruitingCalendar.vue` is the visual spec to match; confirm the
  iOS widget slot + division/gender toggle affordance during Phase 4.
- **D3 data** — NCAA publishes nothing per-sport; `Other`/dead-quiet-only fallback is the honest
  answer. Label it as such in UI.

## 11. Verification per phase

- P1: web type-check + Zod/preferenceValidation tests + onboarding/profile render; iOS build +
  PlayerDetails Codable round-trip test (`{"gender":"prefer_not_to_say"}` → snake_case); gender
  persists via blob round-trip + parent-edit scope works. No DB migration (JSON blob).
- P2: unit tests on resolver (every sport → expected key incl. gender/subdivision/null-fallback);
  L1 snapshot/`verifiedOn` CI guard; L3 plausibility test (period month-range asserts); L2
  cross-check completed + mismatches resolved; L4 CODEOWNERS entry added for the calendar files;
  L6a/b UI states rendered.
- P3: ruleEngine + timeline + dashboard tests green with non-baseball sports; baseball unchanged.
- P4: iOS registry byte-identical assertion (diff vs web keys/dates); widget renders per sport.
- P5: routine created + dry-run of the S3-check logic.

---

## Open questions (resolve before/at plan time)
1. Gender values confirmed: `male|female|other|prefer_not_to_say`, text+CHECK, nullable. ✅ (user-approved)
2. Athlete targets all divisions → view selector, default D1. ✅ (user-approved)
3. iOS UI matches web widget. ✅ (user-approved)
4. **TBD:** does `scripts/seed-system-calendar.ts` write DB rows that Phase 3 must reseed, or is it
   dev-only? (audit in Phase 3)
5. **TBD:** exact iOS dashboard widget slot + toggle affordance (Phase 4 design detail).
