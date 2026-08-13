# iOS School Fit — Academic Fit + Personal Fit parity

**Date:** 2026-08-13
**Status:** Approved (design). Awaiting spec review → implementation plan.
**Goal:** Mirror the web school-detail "School Fit" card on iOS: a section wrapping
**Personal Fit** (existing) and a new **Academic Fit** (SAT/ACT vs school percentile ranges),
including the "look up academic data" link shown when a school has no range data.

**Non-negotiable:** maintain parity with the web process. The single source of truth for
SAT/ACT range data is the shared `schools.academic_info` JSONB, populated by the web
`POST /api/schools/{id}/enrich` endpoint (College Scorecard). iOS reads/writes the same
columns via the same endpoint — it does **not** grow a parallel SAT/ACT fetch path.

---

## Web reference (parity source)

| Concern | Web location |
|---|---|
| Section container ("School Fit" card) | `components/School/SchoolSidebar.vue:120-132` |
| Two stacked cards (Personal first, Academic second) | `components/School/SchoolFitSignals.vue` |
| Signal row (badge + explanation) | `components/School/FitSignalRow.vue:37-70` |
| Academic Fit computation | `utils/fitScoreCalculation.ts:214-290` (`calculateAcademicFitSignals`, `calcTestScoreSignal`) |
| Enrich endpoint | `server/api/schools/[id]/enrich.post.ts` |
| Scorecard → academic_info mapping | `server/utils/collegeScorecard.ts` (`scorecardToAcademicInfo`) |
| Types | `types/schoolFit.ts` |

### Web Academic Fit rules (to reimplement verbatim)
Inputs: athlete `sat_score` / `act_score` (Int); school `sat_25th`, `sat_75th`, `act_25th`,
`act_75th`, `admission_rate` from `academic_info`. **GPA is not used.**

Per test (SAT, then ACT):
- no athlete score **or** school has no range for that test → `unknown`
  - explanation: `"Add your {SAT|ACT} score to your profile."` (missing athlete score) or
    `"No {SAT|ACT} data available for this school."` (missing school range)
- `athleteScore >= school75th` → `above` — value `"{score} is above their 75th percentile ({25th}–{75th})."`
- `athleteScore >= school25th` → `in-range` — `"{score} falls within their typical range ({25th}–{75th})."`
- else → `below` — `"{score} is below their 25th percentile ({25th}–{75th})."`

Analysis-level:
- `hasSchoolData = !!(sat_25th || act_25th)` — drives the missing-data / look-up branch.
- `admissionRate = admission_rate ?? null` — displayed as `"Acceptance rate: {round(rate*100)}%"`.
- `availableSignals` = count of signals whose strength != `unknown`.

Badge/label map (`FitSignalRow.vue`), reused for iOS `TestScoreStrength`:
| strength | label | iOS BadgeColor |
|---|---|---|
| above | "Above range" | `.emerald` |
| in-range | "In range" | `.emerald` |
| below | "Below range" | `.orange` (web amber) |
| unknown | "No data" | `.slate` |

### Web enrich contract (`enrich.post.ts`) — athletes only, school scoped to family unit
- **Step 1 (search):** `POST /api/schools/{id}/enrich` body `{ "schoolName": "<name>" }`
  (empty falls back to the school's stored name). Response:
  ```json
  { "success": true, "data": { "matches": [
      { "scorecardId": 123, "name": "...", "state": "..", "city": "..",
        "studentSize": 12345, "admissionRate": 0.42 } ],
    "instruction": "..." } }
  ```
- **Step 2 (confirm):** `POST /api/schools/{id}/enrich` body `{ "scorecardId": 123, "confirmed": true }`.
  Server merges `scorecardToAcademicInfo(match)` into `academic_info` and returns:
  ```json
  { "success": true, "data": { "schoolId": "..", "academicInfo": { ...merged... },
    "message": "Academic data updated from College Scorecard." } }
  ```
- `academicInfo` in the step-2 response is authoritative — iOS applies it in-memory, no refetch.
- `scorecardToAcademicInfo` writes composite SAT (`sat_25th = sat25Reading + sat25Math`, same
  for 75th), ACT from cumulative, `admission_rate`, `student_size`, tuition, `state`, `city`,
  `scorecard_id`, `scorecard_fetched_at`. iOS does **not** recompute any of this — it only reads.

---

## iOS current state (baseline)

- Personal Fit exists and is complete: `Models/PersonalFitSignals.swift`,
  `Utilities/PersonalFitCalculator.swift`, `Components/PersonalFitCard.swift`,
  `Components/PersonalFitPill.swift`. Strengths `strong/good/stretch/unknown`.
- `SchoolDetailView.swift:133` renders standalone `PersonalFitCard` (only `if let analysis =
  viewModel.personalFit`), right after `CollegeDataSection` (line 124).
- `AcademicInfo` (`Features/Dashboard/Models/AcademicInfo.swift`) decodes `academic_info` with
  snake_case CodingKeys. Has `admissionRate: Double?`, `studentSize`, tuition, single-value
  `satRequirement`/`actRequirement` — but **no SAT/ACT percentile range fields**.
- `PlayerDetails` (`Features/Preferences/Models/PlayerDetails.swift`) has `satScore: Int?`,
  `actScore: Int?`. Loaded into `SchoolDetailViewModel.athleteProfile` in `loadPersonalFit()`.
- `BadgeColor` cases: `blue, emerald, orange, purple, red, slate`.
- Web-API-with-Bearer+CSRF template: `Features/PublicProfile/Services/PublicProfileServiceImpl.swift`
  (`updateProfile` mutating pattern + `fetchCSRFToken` via `GET /api/csrf-token`, cookie in
  `HTTPCookieStorage.shared`, `x-csrf-token` header). Copy this for enrich.
- Existing CollegeDataSection "Lookup" button hits iOS's own `api/colleges/search` proxy
  (no SAT/ACT). **Left unchanged.** The new academic-data look-up is a separate link.

---

## Design

### 1. Data model — extend `AcademicInfo`
Add optional Int fields with snake CodingKeys (decode from shared `academic_info`):
`sat25th (sat_25th)`, `sat75th (sat_75th)`, `act25th (act_25th)`, `act75th (act_75th)`.
Additive only; existing fields untouched.

### 2. New model — `Features/Schools/Models/AcademicFitSignals.swift`
```
enum TestScoreStrength: String, Sendable { case above, inRange, below, unknown
  var label: String   // localized "Above range"/"In range"/"Below range"/"No data"
  var badgeColor: BadgeColor // above/inRange=.emerald, below=.orange, unknown=.slate
}
struct AcademicFitSignal: Sendable, Equatable { label: String; value: String?
  strength: TestScoreStrength; explanation: String }
struct AcademicFitAnalysis: Sendable, Equatable {
  sat: AcademicFitSignal; act: AcademicFitSignal
  hasSchoolData: Bool; admissionRate: Double?
  var orderedSignals: [AcademicFitSignal] { [sat, act] }
  var availableSignals: Int // count strength != .unknown
}
```

### 3. Calculator — `Features/Schools/Utilities/AcademicFitCalculator.swift`
Pure `enum` with `static func calculate(athlete: PlayerDetails?, school: School) ->
AcademicFitAnalysis`, mirroring web `calcTestScoreSignal` thresholds and explanation strings
(see rules above). Reads school ranges from `school.academicInfo`. `hasSchoolData =
academicInfo?.sat25th != nil || academicInfo?.act25th != nil`.

### 4. Enrich service — `Features/Schools/Services/SchoolEnrichmentService.swift`
Protocol `SchoolEnriching: Sendable` + `struct SchoolEnrichmentServiceImpl`:
```
struct ScorecardMatch: Identifiable, Sendable, Equatable {
  var id: Int { scorecardId }; let scorecardId: Int
  let name: String; let city: String?; let state: String?
  let studentSize: Int?; let admissionRate: Double? }

func searchMatches(schoolId: String, schoolName: String, accessToken: String?)
  async throws -> [ScorecardMatch]                // POST step 1
func confirm(schoolId: String, scorecardId: Int, accessToken: String?)
  async throws -> AcademicInfo                     // POST step 2, decode data.academicInfo
```
Bearer + CSRF (`x-csrf-token`) + shared cookie, copied from `PublicProfileServiceImpl`.
Base URL = `SupabaseConfig.apiBaseURL`. Reuse a `SchoolEnrichmentError` enum
(notConfigured / unauthorized(401) / forbidden(403) / server(code)) like `PublicProfileAPIError`.

### 5. UI
- **`Features/Schools/Components/SchoolFitSection.swift`** — a card titled "School Fit"
  wrapping `PersonalFitCard` (first) then `AcademicFitCard` (second), matching web order.
  Renders when personal fit or academic analysis is present. Footer caption:
  `"Academic data from the U.S. College Scorecard."`
- **`Features/Schools/Components/AcademicFitCard.swift`** — header "Academic Fit" + caption
  "Test score comparison".
  - `!hasSchoolData` → text "No academic data for this school yet." + button
    **"Look up this school's academic profile"** → `onLookup()`. Shows `ProgressView` while
    `isEnriching`; shows `enrichError` if present.
  - else → SAT row + ACT row (badge `signal.strength.badgeColor` + `signal.label`, optional
    value, explanation caption), then `"Acceptance rate: N%"` when `admissionRate != nil`.
  - Signal row styled like `PersonalFitCard`'s private `PersonalFitSignalRow` (local row,
    no premature shared-component extraction).
- **`Features/Schools/Components/SchoolMatchChooserSheet.swift`** — `List` of `ScorecardMatch`
  showing name + "city, state"; tap → `onSelect(match)`. Presented only when > 1 match.

### 6. ViewModel — `SchoolDetailViewModel`
- New published state: `academicFit: AcademicFitAnalysis?`, `isEnriching: Bool`,
  `enrichMatches: [ScorecardMatch]`, `enrichError: String?`.
- Extend the existing fit load (currently `loadPersonalFit`) to also compute
  `academicFit = AcademicFitCalculator.calculate(athlete: athleteProfile, school: school)`.
- `func lookupAcademicData()`:
  1. `isEnriching = true`, clear error.
  2. `matches = try await enrichService.searchMatches(schoolId:schoolName:accessToken:)`.
  3. `matches.isEmpty` → error "No matching schools found in College Scorecard."
  4. exactly 1 → `await confirmEnrich(matches[0])`.
  5. > 1 → `enrichMatches = matches` (view presents the chooser sheet).
- `func confirmEnrich(_ match: ScorecardMatch)`:
  1. `let info = try await enrichService.confirm(schoolId:scorecardId:accessToken:)`.
  2. Apply `info` to the in-memory `school.academicInfo` (source of truth for the recompute).
  3. Recompute `academicFit` and `personalFit`. Clear `enrichMatches`, `isEnriching`.
  4. On throw → set `enrichError`, clear `isEnriching`.
- Access token from the same source PublicProfile flows use (`AuthManager` session token).

### 7. Wiring — `SchoolDetailView.swift`
Replace the standalone `PersonalFitCard` block (line ~133) with `SchoolFitSection(...)`,
passing personal analysis, academic analysis, enrich state, and the `onLookup` closure.
`.sheet(isPresented:)` bound to `!enrichMatches.isEmpty` presents `SchoolMatchChooserSheet`.

---

## Parity checklist (must all hold)
- [ ] iOS reads SAT/ACT ranges from the same `academic_info` keys web writes (`sat_25th`, …).
- [ ] iOS look-up calls the same `POST /api/schools/{id}/enrich` (both steps) — no parallel fetch.
- [ ] Academic Fit thresholds/labels/explanations match `calcTestScoreSignal` exactly.
- [ ] GPA excluded from Academic Fit (parity — web ignores it).
- [ ] Section order Personal Fit → Academic Fit, under one "School Fit" header.
- [ ] Missing-data branch gated on `sat_25th || act_25th`, same as web `hasSchoolData`.
- [ ] Multi-match → chooser sheet; single match → auto-confirm (mirrors web `handleEnrich`).
- [ ] Athletes-only enrich (endpoint enforces `assertNotParent`; iOS surfaces 403 gracefully).

## Acceptance criteria
1. School **with** range data in `academic_info`: detail page shows "School Fit" → Personal Fit
   then Academic Fit with SAT/ACT rows, correct badges, acceptance rate.
2. School **without** range data: Academic Fit shows the "Look up this school's academic
   profile" link; tapping it runs the enrich flow.
3. Single Scorecard match → data saved and Academic Fit populates without a chooser.
4. Multiple matches → chooser sheet; selecting one saves and populates.
5. No athlete SAT/ACT on profile → those rows read "Add your {SAT|ACT} score to your profile."
6. Parent account → look-up surfaces a graceful "athletes only" message (403), no crash.
7. `xcodebuild build` clean; new unit tests for `AcademicFitCalculator` (above/in-range/below/
   unknown per test) and `AcademicInfo` range decoding pass.

## Out of scope
- Changing the existing CollegeDataSection "Lookup" button / iOS scorecard proxy.
- Any composite Personal Fit score UI (web doesn't show one either).
- GPA-based fit, majors, cost/campus changes to Personal Fit.
- Seeding range data server-side beyond what enrich already does.

## Open questions
None outstanding — data source (reuse web enrich) and multi-match handling (chooser sheet)
resolved with Chris on 2026-08-13.
