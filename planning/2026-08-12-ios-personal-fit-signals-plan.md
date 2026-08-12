# iOS Personal Fit Signals — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dead numeric fit-score UI in the iOS Schools feature with web-parity, on-device **Personal Fit signals** (Location / Campus Size / Cost), shown as a per-signal card on the detail page, a compact strength pill on each school tile, and a minimum-strength list filter.

**Architecture:** Pure, synchronous calculator over data the app already fetches (`School.academicInfo` + the athlete's `PlayerDetails`, loaded through the existing `PreferenceManaging` channel). No DB writes, no revived column, no numeric score. Mirrors `recruiting-compass-web/utils/fitScoreCalculation.ts` thresholds verbatim.

**Tech Stack:** Swift 6, SwiftUI, `@Observable @MainActor` ViewModels, XCTest. iPhone 17 / iOS 26.5 simulator.

## Global Constraints

- Path root for source: `TheRecruitingCompass/TheRecruitingCompass/`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/`. All `xcodebuild` runs from `TheRecruitingCompass/`.
- Every `@MainActor` class (production AND test) MUST declare `nonisolated deinit {}`.
- Do NOT edit `.xcodeproj` (file-system-synchronized groups auto-include new files).
- Swift line length ≤ 120.
- Thresholds are copied verbatim from the web calculator — never re-invent a number.
- Reuse existing primitives: `BadgeView` (`Shared/Components/BadgeView.swift`), `BadgeColor` (`.emerald/.orange/.red/.slate`), `Color.Semantic.*`.
- Strength→color mapping (cosmetic, tunable): signal `strong`→`.emerald`, `good`→`.orange`, `stretch`→`.red`, `unknown`→`.slate`. Overall pill: `Strong fit`→`.emerald`, `Good fit`→`.orange`, `Stretch`→`.red`.
- Build verify: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'` (from `TheRecruitingCompass/`). Trust the exit code, not a grep for "TEST SUCCEEDED".
- Test the affected classes only (full ~3700 suite exceeds one window): `-only-testing:TheRecruitingCompassTests/Features/Schools/...`.

---

### Task 1: Personal Fit models + calculator (parity core)

The heart of the feature: value types + a pure calculator, fully unit-tested against the web thresholds. Nothing UI here.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/PersonalFitSignals.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Utilities/PersonalFitCalculator.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Utilities/PersonalFitCalculatorTests.swift`

**Interfaces:**
- Consumes: `School` (`Features/Dashboard/Models/School.swift`) with `academicInfo: AcademicInfo?` (`state`, `studentSize: Int?`, `tuitionInState: Double?`, `tuitionOutOfState: Double?`) and top-level `state: String?`; `PlayerDetails` (`Features/Preferences/Models/PlayerDetails.swift`) with `schoolState: String?`, `campusSizePreference: String?` (`"small"|"medium"|"large"`), `costSensitivity: String?` (`"high"|"medium"|"low"`).
- Produces:
  - `enum FitSignalStrength: String, Sendable { case strong, good, stretch, unknown }`
  - `struct PersonalFitSignal: Sendable, Equatable { let label: String; let value: String?; let strength: FitSignalStrength; let explanation: String }`
  - `struct PersonalFitAnalysis: Sendable, Equatable { let location, campusSize, cost: PersonalFitSignal; var orderedSignals: [PersonalFitSignal]; var availableSignals: Int }`
  - `struct OverallPersonalFit: Sendable, Equatable { enum Strength: String, CaseIterable, Sendable { case strong, good, stretch }; let strength: Strength; let label: String; let badgeColor: BadgeColor }`
  - `enum PersonalFitCalculator { static func calculate(athlete: PlayerDetails?, school: School) -> PersonalFitAnalysis; static func overall(_ analysis: PersonalFitAnalysis) -> OverallPersonalFit? }`

- [ ] **Step 1: Write the failing tests**

Create `PersonalFitCalculatorTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class PersonalFitCalculatorTests: XCTestCase {

    // Helpers ---------------------------------------------------------------
    private func school(state: String? = "OH",
                        studentSize: Int? = nil,
                        tuitionOOS: Double? = nil,
                        tuitionIS: Double? = nil) -> School {
        let info = AcademicInfo(state: state,
                                studentSize: studentSize,
                                tuitionInState: tuitionIS,
                                tuitionOutOfState: tuitionOOS)
        return School.fixture(state: state, academicInfo: info)
    }

    private func athlete(homeState: String? = nil,
                         size: String? = nil,
                         cost: String? = nil) -> PlayerDetails {
        PlayerDetails.fixture(schoolState: homeState,
                              campusSizePreference: size,
                              costSensitivity: cost)
    }

    // Location --------------------------------------------------------------
    func testLocation_sameState_isStrong() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: "OH"),
                                                school: school(state: "OH"))
        XCTAssertEqual(a.location.strength, .strong)
        XCTAssertEqual(a.location.value, "In-state")
    }

    func testLocation_differentState_isStretch() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: "OH"),
                                                school: school(state: "MI"))
        XCTAssertEqual(a.location.strength, .stretch)
        XCTAssertEqual(a.location.value, "Out-of-state (MI)")
    }

    func testLocation_missingAthleteState_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: nil),
                                                school: school(state: "OH"))
        XCTAssertEqual(a.location.strength, .unknown)
    }

    // Campus size (buckets: <5000 small, 5000...25000 medium, >25000 large) --
    func testCampusSize_smallMatches() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "small"),
                                                school: school(studentSize: 4999))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_mediumBoundary5000IsMedium() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "medium"),
                                                school: school(studentSize: 5000))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_mediumBoundary25000IsMedium() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "large"),
                                                school: school(studentSize: 25000))
        XCTAssertEqual(a.campusSize.strength, .stretch) // 25000 is medium, not large
    }

    func testCampusSize_largeAbove25000() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "large"),
                                                school: school(studentSize: 25001))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_noData_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "small"),
                                                school: school(studentSize: nil))
        XCTAssertEqual(a.campusSize.strength, .unknown)
    }

    func testCampusSize_noPreference_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: nil),
                                                school: school(studentSize: 3000))
        XCTAssertEqual(a.campusSize.strength, .unknown)
    }

    // Cost (uses tuitionOutOfState ?? tuitionInState) -----------------------
    func testCost_highSensitivity_tiers() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 20000)).cost.strength, .strong)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 35000)).cost.strength, .good)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 35001)).cost.strength, .stretch)
    }

    func testCost_mediumSensitivity_tiers() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 35000)).cost.strength, .strong)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 55000)).cost.strength, .good)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 55001)).cost.strength, .stretch)
    }

    func testCost_lowSensitivity_alwaysStrong() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "low"),
            school: school(tuitionOOS: 90000)).cost.strength, .strong)
    }

    func testCost_fallsBackToInState() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: nil, tuitionIS: 15000))
        XCTAssertEqual(a.cost.strength, .strong)
    }

    func testCost_noData_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: nil, tuitionIS: nil))
        XCTAssertEqual(a.cost.strength, .unknown)
    }

    // availableSignals + overall rollup -------------------------------------
    func testAvailableSignals_countsNonUnknown() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "small", cost: "low"),
            school: school(state: "OH", studentSize: 3000, tuitionOOS: 10000))
        XCTAssertEqual(a.availableSignals, 3)
    }

    func testOverall_allStrong_isStrong() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "small", cost: "low"),
            school: school(state: "OH", studentSize: 3000, tuitionOOS: 10000))
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .strong)
    }

    func testOverall_mixedStrongStretch_meanBucketing() {
        // location strong(2) + campus stretch(0) = mean 1.0 -> good (>=0.75)
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "large"),
            school: school(state: "OH", studentSize: 3000))
        XCTAssertEqual(a.availableSignals, 2)
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .good)
    }

    func testOverall_bothStretch_isStretch() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "large"),
            school: school(state: "MI", studentSize: 3000))
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .stretch)
    }

    func testOverall_noSignals_isNil() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(), school: school())
        XCTAssertEqual(a.availableSignals, 0)
        XCTAssertNil(PersonalFitCalculator.overall(a))
    }
}
```

> If `School.fixture` / `PlayerDetails.fixture` / an `AcademicInfo` memberwise init with these params don't already exist, add minimal test fixtures in this test file (or a `Features/Schools/TestSupport` helper) — do NOT change production initializers to suit tests. Check existing tests first: `SchoolsListViewModelTests` already has a `makeSchool(id:)` helper to model after.

- [ ] **Step 2: Run tests, verify they fail**

Run (from `TheRecruitingCompass/`): `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/Features/Schools/Utilities/PersonalFitCalculatorTests`
Expected: FAIL to compile — `PersonalFitCalculator` / types not defined.

- [ ] **Step 3: Create the model types**

`PersonalFitSignals.swift`:

```swift
import Foundation

enum FitSignalStrength: String, Sendable, Equatable {
    case strong, good, stretch, unknown
}

struct PersonalFitSignal: Sendable, Equatable {
    let label: String
    let value: String?
    let strength: FitSignalStrength
    let explanation: String
}

struct PersonalFitAnalysis: Sendable, Equatable {
    let location: PersonalFitSignal
    let campusSize: PersonalFitSignal
    let cost: PersonalFitSignal

    var orderedSignals: [PersonalFitSignal] { [location, campusSize, cost] }
    var availableSignals: Int { orderedSignals.filter { $0.strength != .unknown }.count }
}

struct OverallPersonalFit: Sendable, Equatable {
    enum Strength: String, CaseIterable, Sendable { case strong, good, stretch

        var label: String {
            switch self {
            case .strong: return String(localized: "Strong fit")
            case .good: return String(localized: "Good fit")
            case .stretch: return String(localized: "Stretch")
            }
        }
        var badgeColor: BadgeColor {
            switch self {
            case .strong: return .emerald
            case .good: return .orange
            case .stretch: return .red
            }
        }
    }

    let strength: Strength
    var label: String { strength.label }
    var badgeColor: BadgeColor { strength.badgeColor }
}
```

- [ ] **Step 4: Implement the calculator**

`PersonalFitCalculator.swift` — port of `calculatePersonalFitSignals` (thresholds verbatim):

```swift
import Foundation

enum PersonalFitCalculator {

    static func calculate(athlete: PlayerDetails?, school: School) -> PersonalFitAnalysis {
        PersonalFitAnalysis(
            location: locationSignal(athleteState: athlete?.schoolState,
                                     schoolState: school.academicInfo?.state ?? school.state),
            campusSize: campusSizeSignal(preference: athlete?.campusSizePreference?.lowercased(),
                                         studentSize: school.academicInfo?.studentSize),
            cost: costSignal(sensitivity: athlete?.costSensitivity?.lowercased(),
                             cost: school.academicInfo?.tuitionOutOfState
                                   ?? school.academicInfo?.tuitionInState)
        )
    }

    static func overall(_ analysis: PersonalFitAnalysis) -> OverallPersonalFit? {
        let ranks: [Int] = analysis.orderedSignals.compactMap { signal in
            switch signal.strength {
            case .strong: return 2
            case .good: return 1
            case .stretch: return 0
            case .unknown: return nil
            }
        }
        guard !ranks.isEmpty else { return nil }
        let mean = Double(ranks.reduce(0, +)) / Double(ranks.count)
        let strength: OverallPersonalFit.Strength = mean >= 1.5 ? .strong : (mean >= 0.75 ? .good : .stretch)
        return OverallPersonalFit(strength: strength)
    }

    // MARK: - Signals

    private static func locationSignal(athleteState: String?, schoolState: String?) -> PersonalFitSignal {
        guard let athleteState, let schoolState else {
            return PersonalFitSignal(label: String(localized: "Location"), value: nil, strength: .unknown,
                explanation: String(localized: "Add your home state to see location fit."))
        }
        let sameState = athleteState == schoolState
        return PersonalFitSignal(
            label: String(localized: "Location"),
            value: sameState ? String(localized: "In-state")
                             : String(localized: "Out-of-state (\(schoolState))"),
            strength: sameState ? .strong : .stretch,
            explanation: sameState
                ? String(localized: "In-state tuition typically applies and you may have regional familiarity.")
                : String(localized: "Out-of-state — consider higher tuition costs and distance from home."))
    }

    private static func campusSizeSignal(preference: String?, studentSize: Int?) -> PersonalFitSignal {
        let label = String(localized: "Campus Size")
        guard let studentSize else {
            return PersonalFitSignal(label: label, value: nil, strength: .unknown,
                explanation: String(localized: "Campus size data not available for this school."))
        }
        let bucket: String = studentSize < 5000 ? "small" : (studentSize <= 25000 ? "medium" : "large")
        let display = String(localized: "\(bucketLabel(bucket)) (\(studentSize.formatted()) students)")
        guard let preference else {
            return PersonalFitSignal(label: label, value: display, strength: .unknown,
                explanation: String(localized: "Add your campus size preference in your profile to see fit."))
        }
        let matches = preference == bucket
        return PersonalFitSignal(label: label, value: display, strength: matches ? .strong : .stretch,
            explanation: matches
                ? String(localized: "Matches your \(preference) campus preference.")
                : String(localized: "This is a \(bucket) campus; you prefer \(preference)."))
    }

    private static func costSignal(sensitivity: String?, cost: Double?) -> PersonalFitSignal {
        let label = String(localized: "Cost")
        guard let cost else {
            return PersonalFitSignal(label: label, value: nil, strength: .unknown,
                explanation: String(localized: "Tuition data not available for this school."))
        }
        let display = String(localized: "$\(Int(cost).formatted())/yr")
        guard let sensitivity else {
            return PersonalFitSignal(label: label, value: display, strength: .unknown,
                explanation: String(localized: "Add your cost sensitivity in your profile to see fit."))
        }
        let (strength, explanation): (FitSignalStrength, String)
        switch sensitivity {
        case "high":
            if cost <= 20000 { (strength, explanation) = (.strong, String(localized: "Cost is well within range for your financial situation.")) }
            else if cost <= 35000 { (strength, explanation) = (.good, String(localized: "Cost is manageable but factor in scholarship potential.")) }
            else { (strength, explanation) = (.stretch, String(localized: "Cost may be a significant challenge — explore all aid options.")) }
        case "medium":
            if cost <= 35000 { (strength, explanation) = (.strong, String(localized: "Cost is reasonable for your situation.")) }
            else if cost <= 55000 { (strength, explanation) = (.good, String(localized: "Cost is on the higher end — factor in scholarship potential.")) }
            else { (strength, explanation) = (.stretch, String(localized: "Cost is high — ensure scholarship options are explored.")) }
        default: // "low"
            (strength, explanation) = (.strong, String(localized: "Cost is not a primary concern in your college search."))
        }
        return PersonalFitSignal(label: label, value: display, strength: strength, explanation: explanation)
    }

    private static func bucketLabel(_ bucket: String) -> String {
        switch bucket {
        case "small": return String(localized: "Small")
        case "medium": return String(localized: "Medium")
        default: return String(localized: "Large")
        }
    }
}
```

- [ ] **Step 5: Run tests, verify pass**

Run the same `-only-testing:...PersonalFitCalculatorTests`. Expected: PASS. Trust exit code 0.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/PersonalFitSignals.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Utilities/PersonalFitCalculator.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Utilities/PersonalFitCalculatorTests.swift
git commit -m "feat(schools): add Personal Fit signal models + calculator (web parity)"
```

---

### Task 2: Personal Fit UI components (card + pill)

SwiftUI presentation only, driven by Task 1 types. Verified by build + previews (SwiftUI views aren't unit-tested here).

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/PersonalFitPill.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/PersonalFitCard.swift`

**Interfaces:**
- Consumes: `OverallPersonalFit`, `PersonalFitAnalysis`, `PersonalFitSignal`, `FitSignalStrength` (Task 1); `BadgeView`, `BadgeColor`.
- Produces: `PersonalFitPill(overall: OverallPersonalFit?)`, `PersonalFitCard(analysis: PersonalFitAnalysis)`.

- [ ] **Step 1: Create `PersonalFitPill`**

```swift
import SwiftUI

/// Compact tile pill summarizing overall personal fit. Renders nothing when unknown.
struct PersonalFitPill: View {
    let overall: OverallPersonalFit?

    var body: some View {
        if let overall {
            BadgeView(text: overall.label, color: overall.badgeColor)
                .accessibilityLabel(String(localized: "Personal fit: \(overall.label)"))
        }
    }
}

#Preview {
    VStack {
        PersonalFitPill(overall: OverallPersonalFit(strength: .strong))
        PersonalFitPill(overall: OverallPersonalFit(strength: .good))
        PersonalFitPill(overall: OverallPersonalFit(strength: .stretch))
        PersonalFitPill(overall: nil)
    }
}
```

- [ ] **Step 2: Create `PersonalFitCard`** (SwiftUI port of `SchoolFitSignals.vue` Personal Fit card)

```swift
import SwiftUI

struct PersonalFitCard: View {
    let analysis: PersonalFitAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Fit").font(.headline)
                Spacer()
                Text("Based on your preferences")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if analysis.availableSignals == 0 {
                Text("Add your home state, campus size preference, and cost sensitivity in your profile to see personal fit.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(analysis.orderedSignals, id: \.label) { signal in
                    PersonalFitSignalRow(signal: signal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
    }
}

private struct PersonalFitSignalRow: View {
    let signal: PersonalFitSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                BadgeView(text: signal.label, color: signal.strength.badgeColor)
                if let value = signal.value {
                    Text(value).font(.subheadline).fontWeight(.medium)
                }
                Spacer()
            }
            Text(signal.explanation)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension FitSignalStrength {
    var badgeColor: BadgeColor {
        switch self {
        case .strong: return .emerald
        case .good: return .orange
        case .stretch: return .red
        case .unknown: return .slate
        }
    }
}

#Preview {
    PersonalFitCard(analysis: PersonalFitAnalysis(
        location: PersonalFitSignal(label: "Location", value: "In-state", strength: .strong,
            explanation: "In-state tuition typically applies."),
        campusSize: PersonalFitSignal(label: "Campus Size", value: "Large (30,000 students)", strength: .stretch,
            explanation: "This is a large campus; you prefer small."),
        cost: PersonalFitSignal(label: "Cost", value: "$18,000/yr", strength: .strong,
            explanation: "Cost is well within range.")))
    .padding()
}
```

> `FitSignalStrength.badgeColor` is declared `private` in this file. Task 1's `OverallPersonalFit.Strength.badgeColor` is separate and already public — no conflict.

- [ ] **Step 3: Build**

Run (from `TheRecruitingCompass/`): `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: exit 0, no new errors. (The old `FitScoreBadge`/`FitScoreSection` still exist and build fine — they're removed in Task 6.)

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/PersonalFitPill.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/PersonalFitCard.swift
git commit -m "feat(schools): add PersonalFitPill + PersonalFitCard views"
```

---

### Task 3: Wire detail page to Personal Fit

Load `PlayerDetails` into `SchoolDetailViewModel`, compute the analysis, and render `PersonalFitCard` in place of the numeric `FitScoreSection`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift` (props ~52-62, `loadFitScore()` ~423-446, its call site in `loadSchool()` ~160)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift:132-147`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `PersonalFitCalculator.calculate(athlete:school:)`, `PersonalFitAnalysis`, `PersonalFitCard`; `preferenceService.fetchPreferences(category: .player, userId:)`, `familyManager.selectedAthlete?.userId`.
- Produces: `SchoolDetailViewModel.personalFit: PersonalFitAnalysis?`, `func loadPersonalFit() async`.

- [ ] **Step 1: Write the failing test**

Add to `SchoolDetailViewModelTests.swift` (match its existing `@MainActor` + `nonisolated deinit {}` + mock-injection setup; the mock preference service is `MockPreferenceService`/`MockPreferenceManager` with Result-based stubbing — see `PlayerDetailsViewModelTests`):

```swift
func testLoadPersonalFit_computesFromProfileAndSchool() async {
    // Given a school in OH with size/tuition, and an in-state athlete
    mockSchoolsService.stubbedSchool = makeSchool(state: "OH", studentSize: 3000, tuitionOOS: 15000)
    mockPreferenceService.fetchPreferencesResult = .success(
        PlayerDetails.fixture(schoolState: "OH", campusSizePreference: "small", costSensitivity: "high"))

    await sut.loadSchool()

    XCTAssertEqual(sut.personalFit?.availableSignals, 3)
    XCTAssertEqual(sut.personalFit?.location.strength, .strong)
}

func testLoadPersonalFit_noProfile_signalsUnknown() async {
    mockSchoolsService.stubbedSchool = makeSchool(state: "OH", studentSize: 3000, tuitionOOS: 15000)
    mockPreferenceService.fetchPreferencesResult = .success(Optional<PlayerDetails>.none)

    await sut.loadSchool()

    XCTAssertEqual(sut.personalFit?.availableSignals, 0)
}
```

> Reuse/extend the test's existing `makeSchool` helper to accept `state/studentSize/tuitionOOS`. If the detail-VM test file lacks a `MockPreferenceService` in its `setUp`, add it to the `SchoolDetailViewModel(...)` init call (the param already exists).

- [ ] **Step 2: Run test, verify fail**

Run: `xcodebuild test ... -only-testing:TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelTests`
Expected: FAIL — `personalFit` not a member.

- [ ] **Step 3: Replace numeric fit props + loader in the ViewModel**

In `SchoolDetailViewModel.swift`, replace the `// MARK: - Fit Score` block (`fitScore`, `divisionRecommendation`, `isLoadingFitScore`) with:

```swift
// MARK: - Personal Fit
private(set) var personalFit: PersonalFitAnalysis?
private var athleteProfile: PlayerDetails?
```

Replace `loadFitScore()` (whole func) with:

```swift
/// Computes on-device Personal Fit signals from the athlete profile + school.
/// Signals are transparent comparisons — never an invented composite score.
func loadPersonalFit() async {
    if athleteProfile == nil {
        athleteProfile = try? await preferenceService.fetchPreferences(
            category: .player, userId: familyManager.selectedAthlete?.userId)
    }
    guard let school else { personalFit = nil; return }
    personalFit = PersonalFitCalculator.calculate(athlete: athleteProfile, school: school)
}
```

At the `loadFitScore()` call site inside `loadSchool()` (~line 160 and the post-fetch path), rename the call to `await loadPersonalFit()`. Remove the `fitScoreService` dependency (stored prop line ~83, init param line ~97, fallback line ~107, and the removed call) — it is deleted entirely in Task 6, but drop its usage here now.

> `fitScoreService` still exists as a type until Task 6. Removing its *usage* here keeps the file compiling. If leaving the unused stored property is cleaner for an intermediate build, keep the property but delete the `getDivisionRecommendations` call; Task 6 removes the property. Prefer removing the param now.

- [ ] **Step 4: Update the detail view**

In `SchoolDetailView.swift`, replace the `// 5. School Fit analysis` block (lines 132-147, including the `DivisionRecommendationBanner` at 147) with:

```swift
// 5. Personal Fit analysis
if let analysis = viewModel.personalFit {
    PersonalFitCard(analysis: analysis)
        .padding(.horizontal)
}
```

- [ ] **Step 5: Run test, verify pass; build**

Run the `-only-testing:...SchoolDetailViewModelTests`, then the full build command. Expected: tests PASS, build exit 0.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelTests.swift
git commit -m "feat(schools): compute + render Personal Fit on school detail"
```

---

### Task 4: Wire list ViewModel — filter + sort by personal fit

Load the athlete profile into `SchoolsListViewModel`, compute overall fit per school, and replace numeric min/max filtering + fit-score sort with minimum-strength filtering + strength sort.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolFilters.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolSortOption.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolsListViewModel.swift` (init ~148, `loadSchools()` home-location block ~204, `recomputeFilteredSchools()` ~66-113, `sorted(_:)` ~376-399, `activeFilterCount` extension ~403-415)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolsListViewModelTests.swift`

**Interfaces:**
- Consumes: `PersonalFitCalculator`, `OverallPersonalFit`, `PlayerDetails`.
- Produces: `SchoolFilters.minPersonalFit: OverallPersonalFit.Strength?`; `SchoolsListViewModel.overallFit(for: School) -> OverallPersonalFit?`.

- [ ] **Step 1: Write the failing tests**

Add to `SchoolsListViewModelTests.swift`:

```swift
func testFilter_minimumStrength_excludesWeakerAndUnknown() async {
    mockService.stubbedSchools = [
        makeSchool(id: "strong", state: "OH", studentSize: 3000, tuitionOOS: 10000),
        makeSchool(id: "stretch", state: "MI", studentSize: 40000, tuitionOOS: 60000),
        makeSchool(id: "unknown") // no academic_info -> no signals
    ]
    mockPreferenceService.fetchPreferencesResult = .success(
        PlayerDetails.fixture(schoolState: "OH", campusSizePreference: "small", costSensitivity: "high"))
    await sut.loadSchools()

    sut.filters.minPersonalFit = .strong

    XCTAssertEqual(sut.filteredSchools.map(\.id), ["strong"])
}

func testSort_personalFit_ordersStrongFirst() async {
    mockService.stubbedSchools = [
        makeSchool(id: "stretch", state: "MI", studentSize: 40000, tuitionOOS: 60000),
        makeSchool(id: "strong", state: "OH", studentSize: 3000, tuitionOOS: 10000)
    ]
    mockPreferenceService.fetchPreferencesResult = .success(
        PlayerDetails.fixture(schoolState: "OH", campusSizePreference: "small", costSensitivity: "high"))
    await sut.loadSchools()

    sut.filters.sortBy = .personalFit

    XCTAssertEqual(sut.filteredSchools.first?.id, "strong")
}
```

> Extend the existing `makeSchool` helper to accept `state/studentSize/tuitionOOS` (defaulting to nil), building an `AcademicInfo`. Add `mockPreferenceService` to the `setUp` `SchoolsListViewModel(...)` init (the `preferenceService` param already exists).

- [ ] **Step 2: Run tests, verify fail**

Run: `xcodebuild test ... -only-testing:TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolsListViewModelTests`
Expected: FAIL — `minPersonalFit` / `.personalFit` sort case not defined.

- [ ] **Step 3: Update `SchoolFilters`**

Replace `fitScoreMin`/`fitScoreMax` in `SchoolFilters.swift`:

```swift
var minPersonalFit: OverallPersonalFit.Strength?
```

- [ ] **Step 4: Update `SchoolSortOption`**

Rename the `fitScore` case to personal fit:

```swift
case personalFit = "personal_fit"
```
and its `displayName` arm to `return String(localized: "Personal Fit")`. Search for `.fitScore` sort references and repoint to `.personalFit`.

- [ ] **Step 5: Update the list ViewModel**

In `loadSchools()`, after the home-location fetch block (~220), load the athlete profile with the same template:

```swift
// Load athlete profile for Personal Fit signals.
athleteProfile = try? await preferenceService.fetchPreferences(
    category: .player, userId: familyManager.selectedAthlete?.userId)
```

Add the stored prop + helper near the other private state:

```swift
private var athleteProfile: PlayerDetails?

func overallFit(for school: School) -> OverallPersonalFit? {
    PersonalFitCalculator.overall(PersonalFitCalculator.calculate(athlete: athleteProfile, school: school))
}
```

In `recomputeFilteredSchools()`, delete the two `fitScoreMin`/`fitScoreMax` blocks and add:

```swift
if let minFit = filters.minPersonalFit {
    let threshold = rank(minFit)
    result = result.filter { school in
        guard let fit = overallFit(for: school) else { return false }
        return rank(fit.strength) >= threshold
    }
}
```

In `sorted(_:)`, replace the `.fitScore` case:

```swift
case .personalFit:
    return schools.sorted { rank(overallFit(for: $0)?.strength) > rank(overallFit(for: $1)?.strength) }
```

Add a private ranking helper (strong=2, good=1, stretch=0, nil=-1):

```swift
private func rank(_ strength: OverallPersonalFit.Strength?) -> Int {
    switch strength {
    case .strong: return 2
    case .good: return 1
    case .stretch: return 0
    case nil: return -1
    }
}
```

In the `activeFilterCount` extension, replace the `if fitScoreMin != nil || fitScoreMax != nil` line with `if minPersonalFit != nil { count += 1 }`.

> `clearFilters()` already resets by re-constructing `SchoolFilters(sortBy:)` — no change needed. Note the sort-by-fit path recomputes `overallFit` per comparison; for 94 schools this is fine. If profiling ever flags it, memoize per school id — out of scope now.

- [ ] **Step 6: Run tests, verify pass; build**

Run the `-only-testing:...SchoolsListViewModelTests`, then full build. Expected: PASS, exit 0.

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolFilters.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolSortOption.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolsListViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolsListViewModelTests.swift
git commit -m "feat(schools): filter + sort schools by Personal Fit strength"
```

---

### Task 5: Filter bar, chips, tile pill, sort UI

Replace the on-screen Fit Score Range sliders with a minimum-strength picker, update the active-filter chip, and swap the dead `FitScoreBadge` on the card for `PersonalFitPill`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolFilterBar.swift` (`row3` ~172-226)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolActiveFilterChips.swift:45-52`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift:117-136`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolsListView.swift` (pass athlete overall into the card — see note)

**Interfaces:**
- Consumes: `SchoolFilters.minPersonalFit`, `OverallPersonalFit.Strength`, `PersonalFitPill`, `SchoolsListViewModel.overallFit(for:)`.

- [ ] **Step 1: Replace `row3` in `SchoolFilterBar`** with a minimum-strength menu

```swift
// MARK: - Row 3: Minimum Personal Fit

@ViewBuilder
private var row3: some View {
    HStack {
        Text("Minimum Personal Fit").font(.subheadline).fontWeight(.medium)
        Spacer()
        Menu {
            Button("Any") { filters.minPersonalFit = nil }
            Button("Good or better") { filters.minPersonalFit = .good }
            Button("Strong only") { filters.minPersonalFit = .strong }
        } label: {
            Text(minFitLabel).font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.systemGray6)).clipShape(.rect(cornerRadius: 8))
        }
        .accessibilityLabel(String(localized: "Minimum personal fit filter"))
    }
    .padding(.horizontal, 4)
}

private var minFitLabel: String {
    switch filters.minPersonalFit {
    case .strong: return String(localized: "Strong only")
    case .good: return String(localized: "Good or better")
    case .stretch, nil: return String(localized: "Any")
    }
}
```

- [ ] **Step 2: Update the chip** in `SchoolActiveFilterChips.swift` (replace the fitScore block)

```swift
if let minFit = filters.minPersonalFit {
    let text = minFit == .strong ? "Fit: Strong" : "Fit: Good+"
    result.append((text, { filters.minPersonalFit = nil }))
}
```

- [ ] **Step 3: Swap the card badge.** In `SchoolCardView.swift` `badgesSection`, replace `FitScoreBadge(score: school.fitScore)` with `PersonalFitPill(overall: overall)`. `SchoolCardView` needs the overall value; add a `let overall: OverallPersonalFit?` stored property to `SchoolCardView` and pass it from the list.

In `SchoolsListView.swift` where `SchoolCardView(...)` is constructed inside `ForEach(viewModel.filteredSchools)`, pass `overall: viewModel.overallFit(for: school)`.

> If `SchoolCardView` is used in other call sites (e.g. previews, other lists), give `overall` a default of `nil` so those keep compiling: `let overall: OverallPersonalFit?` with the memberwise call updated. Grep `SchoolCardView(` before finalizing.

- [ ] **Step 4: Build**

Run full build. Expected: exit 0. (`FitScoreBadge` file still exists but is now unreferenced — deleted in Task 6.)

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolFilterBar.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolActiveFilterChips.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolCardView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolsListView.swift
git commit -m "feat(schools): personal-fit filter picker, chip, and tile pill"
```

---

### Task 6: Remove dead numeric fit-score scaffolding

Everything referencing the dropped `fit_score` column is now unused. Delete it and confirm a clean full build + suite.

**Files:**
- Delete: `Features/Schools/Components/FitScoreBadge.swift`
- Delete: `Features/Schools/Components/FitScoreSection.swift`
- Delete: `Features/Schools/Components/DivisionRecommendationBanner.swift`
- Delete: `Features/Schools/Models/DivisionRecommendation.swift`
- Delete: `Features/Schools/Services/FitScoreService.swift`
- Delete: `Features/Schools/Models/FitScore.swift`
- Delete: `Features/Schools/Models/FitScoreBreakdown.swift`
- Delete: `Features/Schools/Models/FitTier.swift`
- Modify: `Features/Dashboard/Models/School.swift` — remove `fitScore`/`fitTier` stored props (33-34), their CodingKeys (63-64), and `decodeIfPresent` lines (380-381)
- Delete any now-orphaned tests: `FitScoreBadgeTests`, `FitScoreServiceTests`, `FitTierTests`, `FitScoreBreakdownTests`, `DivisionRecommendation*Tests` (grep the tests dir).

- [ ] **Step 1: Grep for stragglers**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
grep -rn "fitScore\|FitScore\|fitTier\|FitTier\|DivisionRecommendation\|FitScoreService\|FitScoreManaging\|FitScoreBreakdown\|FitScoreResult" \
  TheRecruitingCompass/TheRecruitingCompass TheRecruitingCompass/TheRecruitingCompassTests
```
Expected after Tasks 1–5: hits only in the files listed for deletion above. Any hit elsewhere is a missed reference — fix it before deleting (do NOT force-delete a file with a live caller).

- [ ] **Step 2: Delete the files + edit `School.swift`**

Remove the 8 files above. In `School.swift` delete the two stored props, their `CodingKeys` cases, and their decode lines. Delete orphaned test files found in Step 1.

- [ ] **Step 3: Full build**

Run full build. Expected: exit 0, no unresolved references. Fix any remaining compile error by removing the dead reference (not by resurrecting a deleted type).

- [ ] **Step 4: Run the Schools test suite**

Run: `xcodebuild test ... -only-testing:TheRecruitingCompassTests/Features/Schools`
Expected: all pass. Investigate any failure per systematic-debugging.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(schools): remove dead numeric fit-score scaffolding

fit_score column was dropped on web; all readers now use Personal Fit signals."
```

---

## Self-Review

**Spec coverage:**
- On-device calculator, verbatim thresholds → Task 1. ✓
- Personal Fit card (detail) → Tasks 2, 3. ✓
- Tile strength pill → Tasks 2, 5. ✓
- Minimum-strength filter (single picker) → Tasks 4, 5. ✓
- Mean rollup, cutoffs 1.5/0.75, nil at 0 signals → Task 1 (`overall`). ✓
- Personal-fit sort → Task 4. ✓
- PlayerDetails via existing `preferenceService` → Tasks 3, 4. ✓
- Remove dead numeric scaffolding (badge, section, service, banner, DivisionRecommendation, FitScore/Breakdown/Tier, School.fitScore/fitTier) → Task 6. ✓
- Academic Fit deferred → not in plan (correct, it's a Non-Goal). ✓

**Placeholder scan:** No TBDs; every code step has concrete Swift. Test steps contain real assertions with explicit boundary values. ✓

**Type consistency:** `PersonalFitAnalysis`, `PersonalFitSignal`, `OverallPersonalFit(.Strength)`, `PersonalFitCalculator.calculate/overall`, `SchoolFilters.minPersonalFit`, `SchoolSortOption.personalFit`, `overallFit(for:)`, `PersonalFitPill(overall:)`, `PersonalFitCard(analysis:)` used consistently across tasks. ✓

**Known assumptions to verify during execution (flagged inline):** existence/signature of `School.fixture`/`PlayerDetails.fixture`/`AcademicInfo` memberwise init for tests; `MockPreferenceService` Result-stub field name; other `SchoolCardView(` call sites. Each has an inline fallback instruction.
