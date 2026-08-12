# iOS Personal Fit Signals — Design

**Date:** 2026-08-12
**Status:** Design — awaiting review
**Author:** Chris + Claude
**Scope:** iOS Schools feature — replace the dead numeric fit score with web-parity Personal Fit signals

---

## Problem

The iOS Schools feature ships a full numeric "fit score" subsystem — a `FitScoreBadge`
on each school card, a `FitScoreSection` on the detail page, a min/max slider filter, a
fit-score sort option, and `FitTier` classification. **None of it ever renders**, because
`school.fitScore` is nil for every school.

Root cause (verified against production Supabase, project `xpxzhqghxecsjhvklsqg`):

- The `schools.fit_score` column **does not exist** — it was intentionally dropped by the
  web team (`recruiting-compass-web` migration `20260315000003_remove_fit_score_from_schools.sql`).
- `schools.fit_tier` still exists but is **null on all 94 rows**.
- iOS decodes both via `decodeIfPresent`, so the missing/null keys silently yield nil and
  every fit UI element hides itself.

The numeric fit score was **deliberately deprecated on web** in favor of a transparent
two-signal model. iOS is stale: it carries the abandoned concept. Reviving the number would
fight a settled product decision.

The trigger for this work was a request to "filter by Fit Score and show it on the school
tile." That request is sound in spirit (surface fit on the tile + let users filter by it)
but was built on a concept that no longer exists. This design reframes it to the current
model.

## Decision

Bring iOS to parity with the web's **Personal Fit signal** model, computed on-device.
**Personal Fit only for v1.** Academic Fit is deferred (see Non-Goals).

### Why on-device / why not persist

Web computes fit signals client-side from `schools.academic_info` (JSONB) + the athlete's
profile, cached by school id, and **never persists a score**. That is exactly why dropping
the column was safe. iOS mirrors this: pure function over data the app already fetches. No
migration, no backend write, no revived column.

---

## Data feasibility (production, 94 schools)

Personal Fit inputs are well-populated; academic-range inputs are not.

| Input (source) | Populated |
|---|---|
| `academic_info.student_size` | 86/94 |
| `academic_info.tuition_out_of_state` | 84/94 |
| `academic_info.admission_rate` | 75/94 |
| `academic_info.sat_25th` / `sat_75th` / `act_25th` / `act_75th` | **2/94** |

iOS already decodes the Personal Fit inputs:

- **School** (`Features/Dashboard/Models/School.swift`) → nested `academicInfo: AcademicInfo?`
  (`Features/Dashboard/Models/AcademicInfo.swift`) carries `state`, `studentSize`,
  `tuitionInState`, `tuitionOutOfState`, `admissionRate`.
- **PlayerDetails** (`Features/Preferences/Models/PlayerDetails.swift`) carries `schoolState`,
  `campusSizePreference` (`"small"|"medium"|"large"`), `costSensitivity` (`"high"|"medium"|"low"`),
  plus `satScore`/`actScore` (unused in v1).

No new decode fields are required for Personal Fit. (Academic Fit would need `sat_25th`/
`sat_75th`/`act_25th`/`act_75th` added to `AcademicInfo` — out of scope for v1.)

---

## The algorithm (verbatim parity with web)

Port of `recruiting-compass-web/utils/fitScoreCalculation.ts` → `calculatePersonalFitSignals`.
Three independent signals, each returning a strength + human explanation. Thresholds copied
exactly — do not re-invent.

**Strength enum:** `strong` | `good` | `stretch` | `unknown`.

### Location
Inputs: athlete `schoolState` vs school `academicInfo.state`.
- either nil → `unknown` ("Add your home state to see location fit.")
- same state → `strong` ("In-state") — "In-state tuition typically applies…"
- different → `stretch` ("Out-of-state (XX)") — "Out-of-state — consider higher tuition…"

### Campus Size
Inputs: athlete `campusSizePreference` vs school `academicInfo.studentSize`.
- no `studentSize` → `unknown` ("Campus size data not available…")
- bucket: `< 5000` Small, `5000–25000` Medium, `> 25000` Large
- no preference → `unknown` (value shown, "Add your campus size preference…")
- preference matches bucket → `strong`; else → `stretch`

### Cost
Inputs: athlete `costSensitivity` vs school `academicInfo.tuitionOutOfState ?? tuitionInState`.
- no cost → `unknown` ("Tuition data not available…")
- no sensitivity → `unknown` (value shown, "Add your cost sensitivity…")
- `high`: `≤ 20000` strong / `≤ 35000` good / else stretch
- `medium`: `≤ 35000` strong / `≤ 55000` good / else stretch
- `low`: always strong ("Cost is not a primary concern…")

`availableSignals` = count of the three whose strength ≠ `unknown`.

---

## Overall Personal Fit rollup (new — not in web)

Web renders per-signal only; it has no single aggregate. The tile pill and the strength
filter both need one, so we define it here.

**Rule (proposed, open for review):** rank `strong=2`, `good=1`, `stretch=0` over the
*available* (non-unknown) signals, take the mean:

- mean `≥ 1.5` → **Strong fit** (emerald)
- mean `≥ 0.75` → **Good fit** (amber)
- else → **Stretch** (orange)
- `availableSignals == 0` → no pill (tile stays clean; detail shows the fill-your-profile prompt)

Rationale: an average (not the min) avoids one out-of-state signal dragging an otherwise
strong school down to "Stretch." Colors reuse existing `AppColors`.

> **Review flag:** this rollup + its cutoffs are the one genuinely new design choice. Confirm
> the aggregation (mean vs. worst-signal) and the labels before implementation.

---

## Components

### New

- **`Features/Schools/Models/PersonalFitSignals.swift`** — Codable/Sendable value types:
  `FitSignalStrength` enum, `PersonalFitSignal` (label, value, strength, explanation),
  `PersonalFitAnalysis` (three signals + availableSignals), `OverallPersonalFit` (strength +
  label + color role). Mirrors `types/schoolFit.ts`.
- **`Features/Schools/Utilities/PersonalFitCalculator.swift`** — pure functions:
  `calculatePersonalFitSignals(athlete:school:) -> PersonalFitAnalysis` and
  `overallPersonalFit(_:) -> OverallPersonalFit?`. No state, no async. The unit-test surface.
- **`Features/Schools/Components/PersonalFitCard.swift`** — SwiftUI port of
  `SchoolFitSignals.vue`'s Personal Fit card: header, one `PersonalFitSignalRow` per signal
  (strength pill + label + value + explanation), 0-available empty-state linking to the
  profile.
- **`Features/Schools/Components/PersonalFitPill.swift`** — the compact tile pill
  ("Strong fit" / "Good fit" / "Stretch"), color-coded; renders nothing when overall is nil.

### Changed

- **`Features/Schools/Components/SchoolCardView.swift`** — swap `FitScoreBadge(score:)` in the
  badges row for `PersonalFitPill(overall:)`, computed from the athlete profile + school.
- **`Features/Schools/Views/SchoolDetailView.swift`** — replace the `FitScoreSection` /
  "Calculating fit score…" block with `PersonalFitCard`.
- **`Features/Schools/ViewModels/SchoolDetailViewModel.swift`** — drop `loadFitScore()` /
  numeric `fitScore` / `divisionRecommendation`; compute `PersonalFitAnalysis` from the
  injected athlete profile + school.
- **`Features/Schools/ViewModels/SchoolsListViewModel.swift`** — the list VM needs the athlete
  `PlayerDetails` to compute each card's overall fit and to filter. Replace `fitScoreMin/Max`
  filtering (lines ~90/94) with strength-bucket filtering; replace the fitScore sort branch
  with a personal-fit sort (strong→stretch).
- **`Features/Schools/Models/SchoolFilters.swift`** — replace `fitScoreMin`/`fitScoreMax` with
  `personalFitStrength: Set<OverallPersonalFit.Strength>` (or single-select — see Open
  Questions).
- **`Features/Schools/Components/SchoolFilterBar.swift`** — replace the Fit Score Range dual
  sliders (row 3) with a strength picker.
- **`Features/Schools/Components/SchoolActiveFilterChips.swift`** — chip for the new filter.
- **`Features/Schools/Models/SchoolSortOption.swift`** — repoint the `fitScore` case to
  personal-fit ordering (or rename).

### Removed (dead — reference data that no longer exists)

- `Features/Schools/Components/FitScoreBadge.swift`
- `Features/Schools/Components/FitScoreSection.swift`
- `Features/Schools/Services/FitScoreService.swift` (division recommendation off a dead score)
- `Features/Schools/Components/DivisionRecommendationBanner.swift`,
  `Models/DivisionRecommendation.swift` — if only driven by the numeric score (verify no other
  caller during implementation)
- `Features/Schools/Models/FitScore.swift`, `FitScoreBreakdown.swift`, `FitTier.swift` — numeric
  model + tier cutoffs
- `School.fitScore` / `School.fitTier` decode + CodingKeys (the columns are gone). Keep an eye
  out for any other reader during implementation.

> **Removal discipline:** each deletion happens only after grep confirms no live caller
> outside the fit subsystem. Anything with an unexpected consumer gets flagged, not force-deleted.

---

## Data flow

```
PlayerDetails (athlete profile, already loaded for prefs)
        +                         → PersonalFitCalculator (pure) → PersonalFitAnalysis
School.academicInfo (already fetched)                              → OverallPersonalFit
                                                                        ├─ SchoolCardView → PersonalFitPill
                                                                        ├─ SchoolDetailView → PersonalFitCard
                                                                        └─ SchoolsListViewModel → filter + sort
```

The athlete `PlayerDetails` must reach `SchoolsListViewModel` and `SchoolDetailViewModel`.
Implementation confirms the existing injection path (a `PlayerDetails` provider/service likely
already exists for the Preferences feature) rather than adding a new fetch.

## Error handling

Pure functions, no throws. Missing data degrades to `unknown` per-signal and to "no pill" /
empty-state overall — never a crash, never an invented number. Matches web's honesty stance
(`SchoolDetailViewModel` old comment: "we never show a locally invented score" — signals are
transparent comparisons, not invented scores, so this principle is preserved).

## Testing

- **`PersonalFitCalculatorTests`** — table-driven over every threshold boundary for all three
  signals (in/out state, each size bucket edge at 5000/25000, each cost tier edge at
  20000/35000/55000 per sensitivity), plus every `unknown` path (nil inputs). This is the
  parity guarantee against the web thresholds.
- **Rollup tests** — mean cutoffs at 1.5 / 0.75, 0-available → nil.
- **ViewModel tests** — filter by strength returns the right subset; sort orders strong→stretch;
  update `SchoolsListViewModelTests` / `SchoolDetailViewModelTests` for the removed numeric API.
- Delete tests bound to removed numeric components.

## Non-Goals (v1)

- **Academic Fit** (SAT/ACT vs school percentile range) — only 2/94 schools have the range data
  and iOS has no College Scorecard enrich endpoint. Deferred until enrichment exists on iOS.
  When added: extend `AcademicInfo` decode with `sat_25th/75th/act_25th/75th`, port
  `calculateAcademicFitSignals`, add an Academic Fit card + "look up academic profile" action.
- Reviving any numeric fit score or the dropped column.
- Web-side changes (web already ships the signal model).

## Resolved Decisions (2026-08-12)

1. **Rollup semantics** — **mean** (rank strong=2/good=1/stretch=0 over available signals),
   cutoffs mean ≥1.5 Strong / ≥0.75 Good / else Stretch, as specified above. Confirmed.
2. **Filter shape** — **single "minimum strength" picker** (`Any` / `Good+` / `Strong`), not a
   multi-select set. `SchoolFilters` carries one `minPersonalFit: OverallPersonalFit.Strength?`
   (nil = Any). Schools with `availableSignals == 0` are excluded only when a minimum is set.

3. **`DivisionRecommendation` / `FitScoreService`** — verified: only callers are the Schools fit
   subsystem (`SchoolDetailViewModel` + `DivisionRecommendationBanner`). No independent value →
   **delete** with the rest of the numeric scaffolding.
4. **PlayerDetails injection** — verified: both `SchoolsListViewModel` and `SchoolDetailViewModel`
   already store `preferenceService: any PreferenceManaging`. Load via
   `fetchPreferences(category: .player, userId: familyManager.selectedAthlete?.userId)`, mirroring
   the existing home-location load. No new plumbing.
