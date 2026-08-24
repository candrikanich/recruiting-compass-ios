# Sport Calendar — Phase 4: iOS Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bring the sport-aware NCAA recruiting calendar to iOS at byte-identical parity with the finished web module, and surface it as a dashboard widget (wiring the existing `recruitingCalendar` visibility toggle).

**Architecture:** A pure Swift `RecruitingCalendar` registry (`Core/Utilities/`) mirroring web `utils/recruitingCalendar/` — same 21 calendar keys, same ISO period data (type/start/end/description/confidence), same resolver (17 app sports → key incl. gender-split / football subdivision / Other-bundle / null-gender→men's). A `RecruitingCalendarWidget` (SwiftUI) rendering the current period + upcoming windows + milestones with M/W + FBS/FCS toggles, an L6a disclaimer, and an L6b staleness banner — gated on `WidgetVisibility.recruitingCalendar` in `DashboardChartsAndDataSection`. `DashboardViewModel` gains sport/gender by fetching `PlayerDetails`.

**Tech Stack:** SwiftUI / Swift / XCTest.

**Spec:** `planning/2026-08-23-sport-recruiting-calendar-design.md` (§7). **Web reference (source of truth to port, read these):** `recruiting-compass-web/.worktrees/sport-recruiting-calendar/utils/recruitingCalendar/{types,calendarData,resolver}.ts`.

## Global Constraints

- **TDD mandatory** (user directive: tests for all new logic). Tests first, RED, implement, GREEN.
- **BYTE-IDENTICAL to web:** same `NcaaCalendarKey` string set (21: MBA,WSB,MBB,WBB,FBS,FCS,XCTF,WVB,MGO,MLA,WLA,Other + OTHER_MSOCCER,OTHER_WSOCCER,OTHER_SWIM,OTHER_MICEHOCKEY,OTHER_WICEHOCKEY,OTHER_ROWING,OTHER_FIELDHOCKEY,OTHER_MWRESTLING,OTHER_WWRESTLING); same 17 AppSport strings (title-case, from `CanonicalPositions`/onboarding — "Track & Field","Ice Hockey","Water Polo", etc.); same ISO date strings; same period types (`dead|quiet|contact|evaluation|recruiting_shutdown`); same confidence tags; same resolver semantics (gender null/other/prefer_not_to_say → men's; Golf male→MGO else Other; Football default FBS). Only display labels localize.
- **No baseball fallback:** unknown/nil sport resolves to `Other` (generic), never Baseball — matches web + the `CanonicalPositions` no-fallback contract (assert it).
- **Dates:** store ISO `"yyyy-MM-dd"` strings; chronological compare lexically (valid for this format); parse for display via the existing `Shared/Utilities/DateFormatting.swift` helpers. "Today within [start,end]" = `start <= todayISO && todayISO <= end` on strings.
- **Localization:** all display strings via `String(localized:)`.
- **@MainActor / nonisolated deinit:** any new `@MainActor` class (incl. XCTestCase subclasses holding such) needs `nonisolated deinit {}` (macOS 26 teardown).
- **Branch:** continue on the iOS `feat/sport-recruiting-calendar` worktree (`.claude/worktrees/sport-recruiting-calendar`, off main, has Phase-1 gender). Build/test from the `TheRecruitingCompass/` subdir; destination `platform=iOS Simulator,name=iPhone 17`; trust xcodebuild exit code + counts, not a grep.

---

## File Structure
- Create `Core/Utilities/RecruitingCalendar.swift` — `enum RecruitingCalendar` namespace: the `RecruitingPeriod`/`CalendarMilestone`/`SportCalendar` structs, `NcaaCalendarKey`, the `d1Calendars`/`d2AllSports`/`d3Fallback` static data, `resolveCalendarKey`, `getSportCalendar`, `isDeadPeriod`/`isQuietPeriod`/`deadPeriodMessage`/`nextDeadPeriod`/`upcomingMilestones`, `SEASON`/`SEASON_END`, `NO_SPORT_FALLBACK`. (Split into 2-3 files under `Core/Utilities/RecruitingCalendar/` if it grows >800 lines.)
- Create `Features/Dashboard/Components/RecruitingCalendarWidget.swift` — the SwiftUI widget.
- Modify `Features/Dashboard/ViewModels/DashboardViewModel.swift` — fetch PlayerDetails sport/gender.
- Modify `Features/Dashboard/Components/DashboardChartsAndDataSection.swift` + `Features/Dashboard/Views/DashboardView.swift` — mount + gate the widget, thread props.
- Tests: `TheRecruitingCompassTests/Core/Utilities/RecruitingCalendarTests.swift`, `…/Features/Dashboard/ViewModels/DashboardViewModelTests.swift` (extend), a widget/logic test.

---

## Task 1: RecruitingCalendar data + resolver + queries (byte-identical port)

**Files:** Create `Core/Utilities/RecruitingCalendar.swift`; Test `TheRecruitingCompassTests/Core/Utilities/RecruitingCalendarTests.swift`

**Interfaces:** `enum RecruitingCalendar` with structs `RecruitingPeriod { type: PeriodType; start: String; end: String; description: String; confidence: Confidence }`, `CalendarMilestone`, `SportCalendar { periods, milestones, source, verifiedOn }`; `enum PeriodType: String { dead, quiet, contact, evaluation, recruitingShutdown = "recruiting_shutdown" }`; `enum NcaaCalendarKey: String` (21 keys); `static func resolveKey(sport: String?, gender: String? = nil, footballSubdivision: String? = nil) -> NcaaCalendarKey`; `static func calendar(sport: String?, division: String, gender:..., footballSubdivision:...) -> SportCalendar`; `static func isDeadPeriod(_ todayISO: String, sport:..., division:..., gender:...) -> Bool` (recruitingShutdown counts as dead); plus `isQuietPeriod`, `deadPeriodMessage`, `nextDeadPeriod`, `upcomingMilestones`.

**Port source (read + transcribe faithfully):**
`/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/.worktrees/sport-recruiting-calendar/utils/recruitingCalendar/calendarData.ts` (the 21 calendars) and `.../resolver.ts` (mapping + query semantics). Copy every period's type/start/end/description/confidence verbatim; keep `source` URLs identical (incl. the EN-DASH `2026–27` Other URL — it is the real working URL, do NOT ASCII-ify); `verifiedOn = "2026-08-23"`.

- [ ] **Step 1: Write failing resolver + integrity + plausibility + parity tests FIRST** (`RecruitingCalendarTests.swift`, mirror `CanonicalPositionsTests`/`MetricRegistryTests` flat-func style):

```swift
import XCTest
@testable import TheRecruitingCompass

final class RecruitingCalendarTests: XCTestCase {
    // resolver — all 17 sports incl. gender/subdivision/null-default
    func test_resolveKey_singleAndSplitSports() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Baseball"), .MBA)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Softball"), .WSB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "male"), .MBB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "female"), .WBB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: nil), .MBB) // default men's
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "Female"), .WBB) // case-insensitive
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Lacrosse", gender: "female"), .WLA)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Golf", gender: "male"), .MGO)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Golf", gender: "female"), .Other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football"), .FBS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football", footballSubdivision: "FCS"), .FCS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Track & Field"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Cross Country"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Soccer", gender: "female"), .OTHER_WSOCCER)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Wrestling", gender: "male"), .OTHER_MWRESTLING)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Tennis"), .Other)
    }
    func test_resolveKey_unknownAndNil_returnsOther_noBaseballFallback() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: nil), .Other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Quidditch"), .Other)
    }
    // integrity: every key has a calendar with source+verifiedOn + non-empty periods
    func test_everyCalendarWellFormed() {
        for key in NcaaCalendarKey.allCases {
            let cal = RecruitingCalendar.calendarFor(key: key)
            XCTAssertTrue(cal.source.contains("ncaaorg.s3.amazonaws.com"), "\(key)")
            XCTAssertEqual(cal.verifiedOn, "2026-08-23", "\(key)")
            for p in cal.periods {
                XCTAssertTrue(p.start <= p.end, "\(key) \(p.description)")
                XCTAssertEqual(p.start.count, 10) // yyyy-MM-dd
            }
        }
    }
    // plausibility (L3): dead/shutdown in sane months
    func test_plausibility_holidayMonths() {
        for key in NcaaCalendarKey.allCases {
            for p in RecruitingCalendar.calendarFor(key: key).periods {
                let month = Int(p.start.dropFirst(5).prefix(2))!
                if p.description.lowercased().contains("thanksgiving") { XCTAssertEqual(month, 11, "\(key)") }
                if p.description.lowercased().contains("july 4") || p.description.lowercased().contains("independence") { XCTAssertEqual(month, 7, "\(key)") }
            }
        }
    }
    // PARITY GUARD: per-key period counts match web (fill EXPECTED from the web calendarData.ts you port from)
    func test_parity_periodCounts() {
        let expected: [NcaaCalendarKey: Int] = [ /* .MBA: 12, .WSB: 13, ... fill from web */ ]
        for (key, n) in expected { XCTAssertEqual(RecruitingCalendar.calendarFor(key: key).periods.count, n, "\(key)") }
    }
    // sport-specificity regression (mirrors web): July-4 dead for Baseball, not Tennis
    func test_isDeadPeriod_sportSpecific() {
        XCTAssertTrue(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Baseball", division: "D1"))
        XCTAssertFalse(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Tennis", division: "D1"))
    }
}
```

- [ ] **Step 2: Run → FAIL** (`xcodebuild test … -only-testing:TheRecruitingCompassTests/RecruitingCalendarTests`).
- [ ] **Step 3: Implement** `RecruitingCalendar.swift` by porting the web files. Fill the parity-count `expected` map from the web data as you transcribe (count periods per key in the web `calendarData.ts`). `NcaaCalendarKey: CaseIterable`. Query fns compare ISO strings lexically; `isDeadPeriod` treats `.dead` AND `.recruitingShutdown` as blocking; resolver `isMen = (gender ?? "").lowercased() != "female"`.
- [ ] **Step 4: Run → PASS.** A plausibility/parity failure = a transcription error; fix the datum, never weaken the test.
- [ ] **Step 5: Build clean** (`xcodebuild build … -quiet`, exit 0).
- [ ] **Step 6: Commit** `feat(calendar): iOS RecruitingCalendar registry + resolver (byte-identical to web)`.

## Task 2: DashboardViewModel sport/gender wiring

**Files:** Modify `Features/Dashboard/ViewModels/DashboardViewModel.swift`; Test extend `…/DashboardViewModelTests.swift`

**Interfaces:** DashboardViewModel exposes `var athleteSport: String?` + `var athleteGender: String?` populated during load from `PlayerDetails`.

- [ ] **Step 1: Write failing VM test** — inject a mock `PreferenceManaging` returning a `PlayerDetails` with `primarySport = "Softball"`, `gender = "female"`; assert after load `viewModel.athleteSport == "Softball"` / `athleteGender == "female"`. (Mirror the existing mock-injection setUp; add a `MockPreferenceService` if not already used there — reuse `TheRecruitingCompassTests/Mocks/MockPreferenceService.swift`.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — inject `PreferenceManaging` into `DashboardViewModel` (constructor, defaulting to the real service like the other deps), and in `fetchDashboardData()` fetch `PlayerDetails` (`fetchPreferences(category: .player, userId:)`) and set `athleteSport`/`athleteGender`. Handle fetch failure gracefully (nil → widget resolves to Other).
- [ ] **Step 4: Run → PASS. Build clean. Commit** `feat(dashboard): expose athlete sport/gender on DashboardViewModel`.

## Task 3: RecruitingCalendarWidget + mount + disclaimer/staleness/toggles

**Files:** Create `Features/Dashboard/Components/RecruitingCalendarWidget.swift`; Modify `DashboardChartsAndDataSection.swift`, `DashboardView.swift`; Test a widget-logic test.

**Interfaces:** `struct RecruitingCalendarWidget: View { init(sport: String?, gender: String?, division: String = "D1") }`. Gated in `DashboardChartsAndDataSection` on `visibility.recruitingCalendar`.

- [ ] **Step 1: Write failing test** for the widget's pure selection logic — factor the "current period = most-restrictive covering today" into a testable static/helper (severity `recruitingShutdown > dead > evaluation > quiet > contact`, tie-break shortest span — MATCH web's fix). Assert: for Baseball on `"2027-07-04"`, current period type is `.dead` (not `.contact`); on `"2026-11-25"`, `.recruitingShutdown`. Also assert `isStale("2027-08-01") == true`, `isStale("2027-01-01") == false` (SEASON_END = 2027-07-31).
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement the widget** mirroring `UpcomingEventsWidget` chrome (`Color.Surface.card`, `cornerRadius 12`, `brandShadowSm`, empty-state, `String(localized:)` labels): resolve `RecruitingCalendar.calendar(sport:division:gender:footballSubdivision:)`; show the most-restrictive current period, upcoming periods/milestones; a Men's/Women's `Picker`/segmented toggle when the sport is gender-split AND stored gender is null/other/prefer_not_to_say (default men's); an FBS/FCS toggle for Football (default FBS) — both `@State`, overriding the resolver opts; the L6a disclaimer line ("Based on NCAA \(SEASON), verified \(verifiedOn) — confirm with your compliance office") + a `Link`/`.tint` anchor to the resolved `source` URL; the L6b staleness banner when today > SEASON_END.
- [ ] **Step 4: Mount + gate** — thread `athleteSport`/`athleteGender` from `DashboardView` → `DashboardChartsAndDataSection` init, and inside its `body` add:
  `if visibility.recruitingCalendar { RecruitingCalendarWidget(sport: athleteSport, gender: athleteGender) }`
  (no `!isEmpty` guard needed — the widget renders its own empty/placeholder state; but only show for sports that resolve to a non-empty calendar, which is all of them).
- [ ] **Step 5: Build clean + run** `RecruitingCalendarTests` + the widget-logic test + `DashboardViewModelTests`. If sim stalls: `xcrun simctl shutdown all && killall -9 CoreSimulatorService`, retry once.
- [ ] **Step 6: Commit** `feat(dashboard): RecruitingCalendar widget with toggles, disclaimer + staleness (iOS)`.

---

## Parity Checkpoint (after all tasks)
- [ ] iOS `NcaaCalendarKey` set == web (21 keys); resolver branches match web `resolver.spec.ts`; per-key period counts match web (Task 1 parity test).
- [ ] `xcodebuild build` clean; `RecruitingCalendarTests` + `DashboardViewModelTests` + widget test green.
- [ ] Widget renders per sport with the correct current period (most-restrictive), disclaimer + staleness present, toggle appears only for split sports w/ unset gender.
- [ ] Update iOS PR #52 (or a fresh commit range on the branch) noting Phase 4 lands the calendar; parity with web PR #434.

## Self-Review Notes (author)
- **Spec §7 coverage:** registry + resolver (byte-identical), widget matching web, wired to `recruitingCalendar` visibility bool, disclaimer/staleness, toggles — all have tasks.
- **Parity risk:** the TS→Swift data port is the main risk; mitigated by the per-key count parity test + plausibility test + no-baseball-fallback contract test. A future shared-JSON source could make parity exact (deferred).
- **No DB / no migration.** Web PR #434 is the data source of truth; keep values identical.
