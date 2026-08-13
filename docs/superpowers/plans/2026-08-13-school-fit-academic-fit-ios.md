# iOS School Fit — Academic Fit + Personal Fit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Academic Fit" comparison (athlete SAT/ACT vs school percentile ranges) to the iOS school-detail page, wrapped with the existing Personal Fit under one "School Fit" section, plus a "look up academic data" link that calls the web enrich endpoint when a school has no range data.

**Architecture:** iOS reads SAT/ACT ranges from the shared `schools.academic_info` JSONB (keys `sat_25th`/`sat_75th`/`act_25th`/`act_75th`) and populates them via the same `POST /api/schools/{id}/enrich` endpoint the web uses (Bearer + CSRF, copied from `PublicProfileServiceImpl`). A pure `AcademicFitCalculator` mirrors the web `calcTestScoreSignal` thresholds. New SwiftUI views render the section; `SchoolDetailViewModel` orchestrates the enrich flow.

**Tech Stack:** Swift 6, SwiftUI, `@Observable @MainActor` ViewModels, protocol-based DI, XCTest. Build/test destination: `platform=iOS Simulator,name=iPhone 17` from `TheRecruitingCompass/`.

## Global Constraints

- Source paths are double-nested: `TheRecruitingCompass/TheRecruitingCompass/Features/...`. Run all `xcodebuild` from `TheRecruitingCompass/`.
- Parity is mandatory: same `academic_info` keys web writes; same enrich endpoint (both steps); Academic Fit thresholds/labels/explanations identical to web `calcTestScoreSignal`; GPA excluded from Academic Fit.
- Every user-facing string wrapped in `String(localized:)`.
- ViewModels `@MainActor`; services `Sendable`, protocol-backed, injected with default concrete impls (no caller changes).
- `@MainActor` classes need `nonisolated deinit {}` (macOS 26 teardown). UIKit-touching test methods run `@MainActor`.
- SwiftLint: line length ≤ 120; run `swiftlint --config .swiftlint.yml`.
- Access token: `authManager.session?.accessToken`.
- Trust `xcodebuild` exit code, not a "TEST SUCCEEDED" grep. SourceKit "cannot find in scope" diagnostics are stale-index false positives — verify with a real build.
- Web parity references: `recruiting-compass-web/utils/fitScoreCalculation.ts:214-290`, `components/School/{SchoolFitSignals,FitSignalRow}.vue`, `server/api/schools/[id]/enrich.post.ts`.

---

### Task 1: Extend `AcademicInfo` with SAT/ACT ranges + `School.with(academicInfo:)`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/AcademicInfo.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/School.swift:178`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/Models/AcademicInfoRangeDecodingTests.swift` (create)

**Interfaces:**
- Produces: `AcademicInfo.sat25th/sat75th/act25th/act75th: Int?`; `School.with(academicInfo: AcademicInfo?) -> School`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class AcademicInfoRangeDecodingTests: XCTestCase {
  func test_decodesSatActPercentileRanges() throws {
    let json = """
    {"sat_25th": 1120, "sat_75th": 1330, "act_25th": 24, "act_75th": 30, "admission_rate": 0.42}
    """.data(using: .utf8)!
    let info = try JSONDecoder().decode(AcademicInfo.self, from: json)
    XCTAssertEqual(info.sat25th, 1120)
    XCTAssertEqual(info.sat75th, 1330)
    XCTAssertEqual(info.act25th, 24)
    XCTAssertEqual(info.act75th, 30)
    XCTAssertEqual(info.admissionRate, 0.42)
  }

  func test_missingRangesDecodeAsNil() throws {
    let json = "{\"admission_rate\": 0.5}".data(using: .utf8)!
    let info = try JSONDecoder().decode(AcademicInfo.self, from: json)
    XCTAssertNil(info.sat25th)
    XCTAssertNil(info.act25th)
  }

  func test_schoolWithAcademicInfoReplacesOnlyAcademicInfo() {
    let base = School(id: "s1", userId: "u1", name: "Test U", location: nil, city: nil,
      state: "CA", division: nil, conference: nil, ranking: nil, isFavorite: true,
      website: nil, faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, phone: nil,
      ncaaId: nil, status: .interested, statusChangedAt: nil, notes: nil, pros: nil, cons: nil,
      offerDetails: nil, academicInfo: nil, amenities: nil, coachingPhilosophy: nil,
      coachingStyle: nil, recruitingApproach: nil, communicationStyle: nil, successMetrics: nil,
      familyUnitId: "f1", createdBy: nil, updatedBy: nil, createdAt: nil, updatedAt: nil)
    let updated = base.with(academicInfo: AcademicInfo(sat25th: 1100))
    XCTAssertEqual(updated.academicInfo?.sat25th, 1100)
    XCTAssertTrue(updated.isFavorite)
    XCTAssertEqual(updated.state, "CA")
  }
}
```

> Note: if the `School(...)` memberwise argument list here drifts from the real initializer, copy the exact parameter order from `School.swift`'s `init` — do not invent fields.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/AcademicInfoRangeDecodingTests -quiet`
Expected: FAIL — `sat25th`/`with(academicInfo:)` not found.

- [ ] **Step 3: Add fields to `AcademicInfo`**

In `AcademicInfo.swift`, add four stored properties after `admissionRate`:
```swift
  let sat25th: Int?
  let sat75th: Int?
  let act25th: Int?
  let act75th: Int?
```
Add CodingKeys:
```swift
    case sat25th = "sat_25th"
    case sat75th = "sat_75th"
    case act25th = "act_25th"
    case act75th = "act_75th"
```
Add memberwise-init parameters (default `nil`) and assignments:
```swift
    sat25th: Int? = nil, sat75th: Int? = nil, act25th: Int? = nil, act75th: Int? = nil,
```
```swift
    self.sat25th = sat25th
    self.sat75th = sat75th
    self.act25th = act25th
    self.act75th = act75th
```
In the keyed branch of `init(from:)`:
```swift
      sat25th = try keyed.decodeIfPresent(Int.self, forKey: .sat25th)
      sat75th = try keyed.decodeIfPresent(Int.self, forKey: .sat75th)
      act25th = try keyed.decodeIfPresent(Int.self, forKey: .act25th)
      act75th = try keyed.decodeIfPresent(Int.self, forKey: .act75th)
```
In the legacy JSON-string branch (after `admissionRate = decoded.admissionRate`):
```swift
    sat25th = decoded.sat25th
    sat75th = decoded.sat75th
    act25th = decoded.act25th
    act75th = decoded.act75th
```

- [ ] **Step 4: Add `with(academicInfo:)` to `School`**

In `School.swift`, directly after the existing `with(isFavorite:)` method, add a twin that copies every field verbatim but swaps `academicInfo`:
```swift
  func with(academicInfo: AcademicInfo?) -> School {
    School(
      id: id, userId: userId, name: name, location: location, city: city, state: state,
      division: division, conference: conference, ranking: ranking, isFavorite: isFavorite,
      website: website, faviconUrl: faviconUrl, twitterHandle: twitterHandle,
      instagramHandle: instagramHandle, phone: phone, ncaaId: ncaaId, status: status,
      statusChangedAt: statusChangedAt, notes: notes, pros: pros, cons: cons,
      offerDetails: offerDetails, academicInfo: academicInfo, amenities: amenities,
      coachingPhilosophy: coachingPhilosophy, coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach, communicationStyle: communicationStyle,
      successMetrics: successMetrics, familyUnitId: familyUnitId, createdBy: createdBy,
      updatedBy: updatedBy, createdAt: createdAt, updatedAt: updatedAt
    )
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/AcademicInfo.swift TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/School.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/Models/AcademicInfoRangeDecodingTests.swift
git commit -m "feat(schools): decode SAT/ACT percentile ranges in AcademicInfo + School.with(academicInfo:)"
```

---

### Task 2: `AcademicFitSignals` model

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/AcademicFitSignals.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Models/AcademicFitSignalsTests.swift` (create)

**Interfaces:**
- Consumes: `BadgeColor` (`Shared/Components/BadgeColor.swift`).
- Produces:
  - `enum TestScoreStrength: String, Sendable { case above, inRange, below, unknown }` with `var label: String` and `var badgeColor: BadgeColor`.
  - `struct AcademicFitSignal: Sendable, Equatable { let label: String; let value: String?; let strength: TestScoreStrength; let explanation: String }`
  - `struct AcademicFitAnalysis: Sendable, Equatable { let sat: AcademicFitSignal; let act: AcademicFitSignal; let hasSchoolData: Bool; let admissionRate: Double?; var orderedSignals: [AcademicFitSignal]; var availableSignals: Int }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class AcademicFitSignalsTests: XCTestCase {
  func test_strengthBadgeColors() {
    XCTAssertEqual(TestScoreStrength.above.badgeColor, .emerald)
    XCTAssertEqual(TestScoreStrength.inRange.badgeColor, .emerald)
    XCTAssertEqual(TestScoreStrength.below.badgeColor, .orange)
    XCTAssertEqual(TestScoreStrength.unknown.badgeColor, .slate)
  }

  func test_strengthLabels() {
    XCTAssertEqual(TestScoreStrength.above.label, "Above range")
    XCTAssertEqual(TestScoreStrength.inRange.label, "In range")
    XCTAssertEqual(TestScoreStrength.below.label, "Below range")
    XCTAssertEqual(TestScoreStrength.unknown.label, "No data")
  }

  func test_analysisAvailableSignalsCountsKnown() {
    let sat = AcademicFitSignal(label: "SAT", value: nil, strength: .above, explanation: "")
    let act = AcademicFitSignal(label: "ACT", value: nil, strength: .unknown, explanation: "")
    let analysis = AcademicFitAnalysis(sat: sat, act: act, hasSchoolData: true, admissionRate: 0.4)
    XCTAssertEqual(analysis.availableSignals, 1)
    XCTAssertEqual(analysis.orderedSignals.map(\.label), ["SAT", "ACT"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/AcademicFitSignalsTests -quiet`
Expected: FAIL — types not found.

- [ ] **Step 3: Create the model**

```swift
import Foundation

/// Athlete test score vs a school's 25th–75th percentile range. Mirrors web
/// `TestScoreStrength` in types/schoolFit.ts.
enum TestScoreStrength: String, Sendable, Equatable {
  case above
  case inRange
  case below
  case unknown

  var label: String {
    switch self {
    case .above:   return String(localized: "Above range")
    case .inRange: return String(localized: "In range")
    case .below:   return String(localized: "Below range")
    case .unknown: return String(localized: "No data")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .above, .inRange: return .emerald
    case .below:           return .orange
    case .unknown:         return .slate
    }
  }
}

struct AcademicFitSignal: Sendable, Equatable {
  let label: String
  let value: String?
  let strength: TestScoreStrength
  let explanation: String
}

/// SAT + ACT comparison for one school. Mirrors web `calculateAcademicFitSignals`.
struct AcademicFitAnalysis: Sendable, Equatable {
  let sat: AcademicFitSignal
  let act: AcademicFitSignal
  /// True when the school has at least one percentile range (`sat_25th || act_25th`).
  let hasSchoolData: Bool
  let admissionRate: Double?

  var orderedSignals: [AcademicFitSignal] { [sat, act] }
  var availableSignals: Int { orderedSignals.filter { $0.strength != .unknown }.count }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/AcademicFitSignals.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Models/AcademicFitSignalsTests.swift
git commit -m "feat(schools): add AcademicFitSignals model (TestScoreStrength + analysis)"
```

---

### Task 3: `AcademicFitCalculator` (pure, mirrors web thresholds)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Utilities/AcademicFitCalculator.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Utilities/AcademicFitCalculatorTests.swift` (create)

**Interfaces:**
- Consumes: `PlayerDetails` (`satScore: Int?`, `actScore: Int?`), `School` (`academicInfo?.sat25th/sat75th/act25th/act75th/admissionRate`), `AcademicFitAnalysis`, `AcademicFitSignal`, `TestScoreStrength`.
- Produces: `enum AcademicFitCalculator { static func calculate(athlete: PlayerDetails?, school: School) -> AcademicFitAnalysis }`.

**Parity rules (from web `calcTestScoreSignal`), per test:**
- no athlete score → `unknown`, explanation `"Add your {SAT|ACT} score to your profile."`
- athlete score present but no school range (missing 25th or 75th) → `unknown`, explanation `"No {SAT|ACT} data available for this school."`
- `score >= 75th` → `above`, value `"{score} is above their 75th percentile ({25th}–{75th})."`
- `score >= 25th` → `inRange`, value `"{score} falls within their typical range ({25th}–{75th})."`
- else → `below`, value `"{score} is below their 25th percentile ({25th}–{75th})."`
- `hasSchoolData = academicInfo?.sat25th != nil || academicInfo?.act25th != nil`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class AcademicFitCalculatorTests: XCTestCase {
  private func school(sat25: Int? = nil, sat75: Int? = nil, act25: Int? = nil,
                      act75: Int? = nil, rate: Double? = nil) -> School {
    School(id: "s1", userId: "u1", name: "U", location: nil, city: nil, state: nil,
      division: nil, conference: nil, ranking: nil, isFavorite: false, website: nil,
      faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, phone: nil, ncaaId: nil,
      status: .interested, statusChangedAt: nil, notes: nil, pros: nil, cons: nil,
      offerDetails: nil,
      academicInfo: AcademicInfo(admissionRate: rate, sat25th: sat25, sat75th: sat75,
                                 act25th: act25, act75th: act75),
      amenities: nil, coachingPhilosophy: nil, coachingStyle: nil, recruitingApproach: nil,
      communicationStyle: nil, successMetrics: nil, familyUnitId: "f1", createdBy: nil,
      updatedBy: nil, createdAt: nil, updatedAt: nil)
  }
  private func athlete(sat: Int? = nil, act: Int? = nil) -> PlayerDetails {
    var p = PlayerDetails(); p.satScore = sat; p.actScore = act; return p
  }

  func test_satAboveRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1400),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .above)
    XCTAssertTrue(a.hasSchoolData)
  }
  func test_satInRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1200),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .inRange)
  }
  func test_satBelowRange() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: 1000),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .below)
  }
  func test_noAthleteScoreIsUnknownWithProfilePrompt() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(sat: nil),
                                            school: school(sat25: 1120, sat75: 1330))
    XCTAssertEqual(a.sat.strength, .unknown)
    XCTAssertEqual(a.sat.explanation, "Add your SAT score to your profile.")
  }
  func test_noSchoolRangeIsUnknownWithNoDataMessage() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(act: 28), school: school())
    XCTAssertEqual(a.act.strength, .unknown)
    XCTAssertEqual(a.act.explanation, "No ACT data available for this school.")
    XCTAssertFalse(a.hasSchoolData)
  }
  func test_hasSchoolDataTrueWhenOnlyActRangePresent() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(), school: school(act25: 24, act75: 30))
    XCTAssertTrue(a.hasSchoolData)
  }
  func test_admissionRatePassedThrough() {
    let a = AcademicFitCalculator.calculate(athlete: athlete(), school: school(rate: 0.37))
    XCTAssertEqual(a.admissionRate, 0.37)
  }
}
```

> If `PlayerDetails()` has no zero-arg init or `satScore`/`actScore` are `let`, construct it via its real initializer/JSON decode instead — check `Features/Preferences/Models/PlayerDetails.swift`. The behavioral assertions stay identical.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/AcademicFitCalculatorTests -quiet`
Expected: FAIL — `AcademicFitCalculator` not found.

- [ ] **Step 3: Implement the calculator**

```swift
import Foundation

/// Pure Academic Fit computation. Mirrors web `calcTestScoreSignal`
/// (utils/fitScoreCalculation.ts). GPA is intentionally not used (web parity).
enum AcademicFitCalculator {
  static func calculate(athlete: PlayerDetails?, school: School) -> AcademicFitAnalysis {
    let info = school.academicInfo
    let sat = signal(test: String(localized: "SAT"), score: athlete?.satScore,
                     p25: info?.sat25th, p75: info?.sat75th)
    let act = signal(test: String(localized: "ACT"), score: athlete?.actScore,
                     p25: info?.act25th, p75: info?.act75th)
    let hasSchoolData = info?.sat25th != nil || info?.act25th != nil
    return AcademicFitAnalysis(sat: sat, act: act, hasSchoolData: hasSchoolData,
                               admissionRate: info?.admissionRate)
  }

  private static func signal(test: String, score: Int?, p25: Int?, p75: Int?)
    -> AcademicFitSignal {
    guard let score else {
      return AcademicFitSignal(
        label: test, value: nil, strength: .unknown,
        explanation: String(localized: "Add your \(test) score to your profile."))
    }
    guard let p25, let p75 else {
      return AcademicFitSignal(
        label: test, value: nil, strength: .unknown,
        explanation: String(localized: "No \(test) data available for this school."))
    }
    let strength: TestScoreStrength
    let phrase: String
    if score >= p75 {
      strength = .above
      phrase = String(localized: "\(score) is above their 75th percentile (\(p25)–\(p75)).")
    } else if score >= p25 {
      strength = .inRange
      phrase = String(localized: "\(score) falls within their typical range (\(p25)–\(p75)).")
    } else {
      strength = .below
      phrase = String(localized: "\(score) is below their 25th percentile (\(p25)–\(p75)).")
    }
    return AcademicFitSignal(label: test, value: nil, strength: strength, explanation: phrase)
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Utilities/AcademicFitCalculator.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Utilities/AcademicFitCalculatorTests.swift
git commit -m "feat(schools): add AcademicFitCalculator mirroring web test-score thresholds"
```

---

### Task 4: `SchoolEnrichmentService` (enrich endpoint client)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/SchoolEnrichmentService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Services/SchoolEnrichmentDecodingTests.swift` (create)

**Interfaces:**
- Consumes: `SupabaseConfig.apiBaseURL`, `AcademicInfo`. CSRF/Bearer pattern from `Features/PublicProfile/Services/PublicProfileServiceImpl.swift`.
- Produces:
  - `struct ScorecardMatch: Identifiable, Sendable, Equatable { var id: Int { scorecardId }; let scorecardId: Int; let name: String; let city: String?; let state: String?; let studentSize: Int?; let admissionRate: Double? }`
  - `enum SchoolEnrichmentError: Error, Equatable { case notConfigured, unauthorized, forbidden, server(Int) }`
  - `protocol SchoolEnriching: Sendable { func searchMatches(schoolId: String, schoolName: String, accessToken: String?) async throws -> [ScorecardMatch]; func confirm(schoolId: String, scorecardId: Int, accessToken: String?) async throws -> AcademicInfo }`
  - `struct SchoolEnrichmentServiceImpl: SchoolEnriching`

The endpoint wraps payloads as `{ "success": true, "data": { ... } }`. Step 1 `data.matches` is `[ScorecardMatch]`; step 2 `data.academicInfo` is an `AcademicInfo` (snake keys). Define private `Codable` response wrappers.

- [ ] **Step 1: Write the failing test (response decoding — no live network)**

```swift
import XCTest
@testable import TheRecruitingCompass

final class SchoolEnrichmentDecodingTests: XCTestCase {
  func test_decodeSearchMatches() throws {
    let json = """
    {"success":true,"data":{"matches":[
      {"scorecardId":123,"name":"State U","state":"CA","city":"Davis",
       "studentSize":30000,"admissionRate":0.42}],"instruction":"x"}}
    """.data(using: .utf8)!
    let matches = try SchoolEnrichmentServiceImpl.decodeMatches(json)
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches[0].scorecardId, 123)
    XCTAssertEqual(matches[0].id, 123)
    XCTAssertEqual(matches[0].city, "Davis")
    XCTAssertEqual(matches[0].admissionRate, 0.42)
  }

  func test_decodeConfirmAcademicInfo() throws {
    let json = """
    {"success":true,"data":{"schoolId":"s1","message":"ok",
     "academicInfo":{"sat_25th":1120,"sat_75th":1330,"act_25th":24,"act_75th":30,
     "admission_rate":0.42,"student_size":30000}}}
    """.data(using: .utf8)!
    let info = try SchoolEnrichmentServiceImpl.decodeAcademicInfo(json)
    XCTAssertEqual(info.sat25th, 1120)
    XCTAssertEqual(info.act75th, 30)
    XCTAssertEqual(info.admissionRate, 0.42)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolEnrichmentDecodingTests -quiet`
Expected: FAIL — symbols not found.

- [ ] **Step 3: Implement the service**

```swift
import Foundation
import OSLog

struct ScorecardMatch: Identifiable, Sendable, Equatable, Decodable {
  var id: Int { scorecardId }
  let scorecardId: Int
  let name: String
  let city: String?
  let state: String?
  let studentSize: Int?
  let admissionRate: Double?
}

enum SchoolEnrichmentError: Error, Equatable {
  case notConfigured, unauthorized, forbidden, server(Int)
}

protocol SchoolEnriching: Sendable {
  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch]
  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo
}

struct SchoolEnrichmentServiceImpl: SchoolEnriching {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "SchoolEnrich")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  // MARK: Decoding wrappers (static → unit-testable without network)

  private struct SearchResponse: Decodable { let data: Payload
    struct Payload: Decodable { let matches: [ScorecardMatch] } }
  private struct ConfirmResponse: Decodable { let data: Payload
    struct Payload: Decodable { let academicInfo: AcademicInfo } }

  static func decodeMatches(_ data: Data) throws -> [ScorecardMatch] {
    try JSONDecoder().decode(SearchResponse.self, from: data).data.matches
  }
  static func decodeAcademicInfo(_ data: Data) throws -> AcademicInfo {
    try JSONDecoder().decode(ConfirmResponse.self, from: data).data.academicInfo
  }

  // MARK: API

  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch] {
    let data = try await post(schoolId: schoolId, accessToken: accessToken,
                              body: ["schoolName": schoolName])
    return try Self.decodeMatches(data)
  }

  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo {
    let data = try await post(schoolId: schoolId, accessToken: accessToken,
                              body: ["scorecardId": scorecardId, "confirmed": true])
    return try Self.decodeAcademicInfo(data)
  }

  private func post(schoolId: String, accessToken: String?,
                    body: [String: Any]) async throws -> Data {
    guard let baseURL, let token = accessToken, !token.isEmpty else {
      throw SchoolEnrichmentError.notConfigured
    }
    let csrf = try await fetchCSRFToken(baseURL: baseURL)
    let safeId = schoolId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? schoolId
    let url = baseURL.appendingPathComponent("api/schools").appendingPathComponent(safeId)
      .appendingPathComponent("enrich")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await session.data(for: request)
    try Self.mapStatus(response)
    return data
  }

  private static func mapStatus(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { throw SchoolEnrichmentError.server(-1) }
    switch http.statusCode {
    case 200...299: return
    case 401: throw SchoolEnrichmentError.unauthorized
    case 403: throw SchoolEnrichmentError.forbidden
    default: throw SchoolEnrichmentError.server(http.statusCode)
    }
  }

  /// Copies PublicProfileServiceImpl.fetchCSRFToken: GET /api/csrf-token, read csrf-token cookie.
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    let url = baseURL.appendingPathComponent("api/csrf-token")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw SchoolEnrichmentError.server(-1)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrfCookie = cookies.first(where: { $0.name == "csrf-token" }) else {
      throw SchoolEnrichmentError.server(-1)
    }
    return csrfCookie.value
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/SchoolEnrichmentService.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/Services/SchoolEnrichmentDecodingTests.swift
git commit -m "feat(schools): add SchoolEnrichmentService (enrich endpoint, Bearer+CSRF)"
```

---

### Task 5: Wire enrich flow into `SchoolDetailViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift` (deps ~77-105; `loadPersonalFit` ~415-424; add new methods)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailAcademicFitTests.swift` (create)

**Interfaces:**
- Consumes: `SchoolEnriching`, `ScorecardMatch`, `AcademicFitCalculator`, `AcademicFitAnalysis`, `School.with(academicInfo:)`, `authManager.session?.accessToken`.
- Produces (new on `SchoolDetailViewModel`): `var academicFit: AcademicFitAnalysis?`; `var isEnriching: Bool`; `var enrichMatches: [ScorecardMatch]`; `var enrichError: String?`; `func lookupAcademicData() async`; `func confirmEnrich(_ match: ScorecardMatch) async`.

- [ ] **Step 1: Write the failing test (mock enricher)**

```swift
import XCTest
@testable import TheRecruitingCompass

private final class MockEnricher: SchoolEnriching, @unchecked Sendable {
  var matches: [ScorecardMatch] = []
  var confirmInfo = AcademicInfo(sat25th: 1120, sat75th: 1330)
  var searchCalls = 0, confirmCalls = 0
  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch] {
    searchCalls += 1; return matches
  }
  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo {
    confirmCalls += 1; return confirmInfo
  }
}

@MainActor
final class SchoolDetailAcademicFitTests: XCTestCase {
  private func match(_ id: Int) -> ScorecardMatch {
    ScorecardMatch(scorecardId: id, name: "U\(id)", city: nil, state: nil,
                   studentSize: nil, admissionRate: nil)
  }

  // Construct the VM the way the app does; inject the mock enricher and a loaded school.
  // See existing SchoolDetailViewModel tests for the exact constructor + how `school` is set.

  func test_singleMatchAutoConfirmsAndPopulatesAcademicFit() async {
    let mock = MockEnricher(); mock.matches = [match(1)]
    let vm = makeVM(enricher: mock)          // helper defined per existing test conventions
    await vm.lookupAcademicData()
    XCTAssertEqual(mock.confirmCalls, 1)
    XCTAssertTrue(vm.enrichMatches.isEmpty)
    XCTAssertEqual(vm.school?.academicInfo?.sat25th, 1120)
    XCTAssertNotNil(vm.academicFit)
    XCTAssertTrue(vm.academicFit?.hasSchoolData ?? false)
  }

  func test_multipleMatchesShowsChooserWithoutConfirming() async {
    let mock = MockEnricher(); mock.matches = [match(1), match(2)]
    let vm = makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertEqual(mock.confirmCalls, 0)
    XCTAssertEqual(vm.enrichMatches.count, 2)
  }

  func test_noMatchesSetsError() async {
    let mock = MockEnricher(); mock.matches = []
    let vm = makeVM(enricher: mock)
    await vm.lookupAcademicData()
    XCTAssertNotNil(vm.enrichError)
    XCTAssertFalse(vm.isEnriching)
  }
}
```

> `makeVM(enricher:)` is a per-file helper: build `SchoolDetailViewModel` with the existing test constructor (mock `schoolsService`/`authManager`/`familyManager`/`preferenceService`), assign a loaded `school`, and pass the new `enrichService` parameter. Copy the constructor call from the nearest existing `SchoolDetailViewModel*Tests` file so argument labels match exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolDetailAcademicFitTests -quiet`
Expected: FAIL — new members / `enrichService` param not found.

- [ ] **Step 3: Add dependency + state**

In the stored-properties block (~77-83) add:
```swift
  private let enrichService: any SchoolEnriching
```
In `init(...)` add a parameter (default nil) alongside the others:
```swift
    enrichService: (any SchoolEnriching)? = nil,
```
and assign:
```swift
    self.enrichService = enrichService ?? SchoolEnrichmentServiceImpl()
```
Add observable state near other `@Observable` properties:
```swift
  var academicFit: AcademicFitAnalysis?
  var isEnriching = false
  var enrichMatches: [ScorecardMatch] = []
  var enrichError: String?
```

- [ ] **Step 4: Compute academic fit in `loadPersonalFit`**

At the end of `loadPersonalFit()`, after `personalFit = ...`, add:
```swift
    academicFit = AcademicFitCalculator.calculate(athlete: athleteProfile, school: school)
```

- [ ] **Step 5: Add enrich methods**

```swift
  // MARK: - Academic Data Lookup (enrich)

  private var accessToken: String? { authManager.session?.accessToken }

  func lookupAcademicData() async {
    guard let schoolName = school?.name else { return }
    isEnriching = true
    enrichError = nil
    do {
      let matches = try await enrichService.searchMatches(
        schoolId: schoolId, schoolName: schoolName, accessToken: accessToken)
      if matches.isEmpty {
        enrichError = String(localized: "No matching schools found in College Scorecard.")
        isEnriching = false
      } else if matches.count == 1 {
        await confirmEnrich(matches[0])
      } else {
        enrichMatches = matches
        isEnriching = false
      }
    } catch SchoolEnrichmentError.forbidden {
      enrichError = String(localized: "Only athlete accounts can look up academic data.")
      isEnriching = false
    } catch {
      enrichError = String(localized: "Failed to look up academic data. Please try again.")
      logger.error("Enrich search failed: \(error.localizedDescription)")
      isEnriching = false
    }
  }

  func confirmEnrich(_ match: ScorecardMatch) async {
    isEnriching = true
    enrichError = nil
    enrichMatches = []
    do {
      let info = try await enrichService.confirm(
        schoolId: schoolId, scorecardId: match.scorecardId, accessToken: accessToken)
      if let school { self.school = school.with(academicInfo: info) }
      await loadPersonalFit()   // recomputes personalFit AND academicFit
      await invalidateSchoolCache()
    } catch {
      enrichError = String(localized: "Failed to save academic data. Please try again.")
      logger.error("Enrich confirm failed: \(error.localizedDescription)")
    }
    isEnriching = false
  }
```

> `invalidateSchoolCache()` already exists (used by `lookupCollegeData`). `logger` and `schoolId` are existing members.

- [ ] **Step 6: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailAcademicFitTests.swift
git commit -m "feat(schools): wire academic-fit enrich flow into SchoolDetailViewModel"
```

---

### Task 6: UI — `AcademicFitCard`, `SchoolFitSection`, `SchoolMatchChooserSheet`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/AcademicFitCard.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolFitSection.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolMatchChooserSheet.swift`

**Interfaces:**
- Consumes: `PersonalFitCard` (existing, takes `analysis: PersonalFitAnalysis`), `AcademicFitAnalysis`, `AcademicFitSignal`, `ScorecardMatch`, `BadgeView(text:color:)`.
- Produces: three SwiftUI views (signatures below), consumed by Task 7.

These are presentation-only views; they carry no branching logic beyond what Task 5's ViewModel state drives (already unit-tested). Verification is a clean build + `#Preview`s; no XCTest is added for the views (consistent with existing Schools components, which are not unit-tested).

- [ ] **Step 1: Create `AcademicFitCard`**

```swift
import SwiftUI

struct AcademicFitCard: View {
  let analysis: AcademicFitAnalysis
  let isEnriching: Bool
  let enrichError: String?
  let onLookup: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Academic Fit").font(.headline)
        Text("Test score comparison").font(.caption).foregroundStyle(.secondary)
      }

      if analysis.hasSchoolData {
        ForEach(analysis.orderedSignals, id: \.label) { signal in
          AcademicFitSignalRow(signal: signal)
        }
        if let rate = analysis.admissionRate {
          Text("Acceptance rate: \(Int((rate * 100).rounded()))%")
            .font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text("No academic data for this school yet.")
          .font(.subheadline).foregroundStyle(.secondary)
        Button(action: onLookup) {
          if isEnriching {
            ProgressView()
          } else {
            Text("Look up this school's academic profile")
          }
        }
        .disabled(isEnriching)
        .accessibilityLabel(String(localized: "Look up this school's academic profile"))
        if let enrichError {
          Text(enrichError).font(.caption).foregroundStyle(.red)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }
}

private struct AcademicFitSignalRow: View {
  let signal: AcademicFitSignal
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(signal.label).font(.subheadline).fontWeight(.medium)
        Spacer()
        BadgeView(text: signal.strength.label, color: signal.strength.badgeColor)
      }
      Text(signal.explanation).font(.caption).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("Has data") {
  AcademicFitCard(
    analysis: AcademicFitAnalysis(
      sat: AcademicFitSignal(label: "SAT", value: nil, strength: .above,
        explanation: "1400 is above their 75th percentile (1120–1330)."),
      act: AcademicFitSignal(label: "ACT", value: nil, strength: .inRange,
        explanation: "28 falls within their typical range (24–30)."),
      hasSchoolData: true, admissionRate: 0.42),
    isEnriching: false, enrichError: nil, onLookup: {})
  .padding()
}

#Preview("Missing data") {
  AcademicFitCard(
    analysis: AcademicFitAnalysis(
      sat: AcademicFitSignal(label: "SAT", value: nil, strength: .unknown,
        explanation: "No SAT data available for this school."),
      act: AcademicFitSignal(label: "ACT", value: nil, strength: .unknown,
        explanation: "No ACT data available for this school."),
      hasSchoolData: false, admissionRate: nil),
    isEnriching: false, enrichError: nil, onLookup: {})
  .padding()
}
```

- [ ] **Step 2: Create `SchoolFitSection`**

```swift
import SwiftUI

/// "School Fit" card wrapping Personal Fit (first) then Academic Fit (second),
/// mirroring web components/School/SchoolSidebar.vue + SchoolFitSignals.vue.
struct SchoolFitSection: View {
  let personalFit: PersonalFitAnalysis?
  let academicFit: AcademicFitAnalysis?
  let isEnriching: Bool
  let enrichError: String?
  let onLookup: () -> Void

  var body: some View {
    if personalFit != nil || academicFit != nil {
      VStack(alignment: .leading, spacing: 16) {
        Text("School Fit").font(.title3).fontWeight(.semibold)
          .accessibilityAddTraits(.isHeader)

        if let personalFit {
          PersonalFitCard(analysis: personalFit)
        }
        if let academicFit {
          AcademicFitCard(analysis: academicFit, isEnriching: isEnriching,
                          enrichError: enrichError, onLookup: onLookup)
        }
        Text("Academic data from the U.S. College Scorecard.")
          .font(.caption2).foregroundStyle(.secondary)
      }
      .padding(.horizontal)
    }
  }
}
```

> Verify `PersonalFitCard`'s exact initializer label before building — the spec records it as `PersonalFitCard(analysis:)`. If it differs, match the real signature.

- [ ] **Step 3: Create `SchoolMatchChooserSheet`**

```swift
import SwiftUI

struct SchoolMatchChooserSheet: View {
  let matches: [ScorecardMatch]
  let onSelect: (ScorecardMatch) -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      List(matches) { match in
        Button { onSelect(match) } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(match.name).font(.body).foregroundStyle(.primary)
            if let sub = subtitle(for: match) {
              Text(sub).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("Select the Correct School")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }
      }
    }
  }

  private func subtitle(for match: ScorecardMatch) -> String? {
    [match.city, match.state].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
  SchoolMatchChooserSheet(
    matches: [ScorecardMatch(scorecardId: 1, name: "State University", city: "Davis",
      state: "CA", studentSize: 30000, admissionRate: 0.42)],
    onSelect: { _ in }, onCancel: {})
}
```

- [ ] **Step 4: Build to verify the views compile**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0, no `error:` lines.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/AcademicFitCard.swift TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolFitSection.swift TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolMatchChooserSheet.swift
git commit -m "feat(schools): add School Fit section, Academic Fit card, match chooser sheet"
```

---

### Task 7: Mount `SchoolFitSection` in `SchoolDetailView`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift` (~line 133, the standalone `PersonalFitCard` block)

**Interfaces:**
- Consumes: `SchoolFitSection`, `SchoolMatchChooserSheet`, and the Task 5 ViewModel members.

- [ ] **Step 1: Replace the standalone PersonalFitCard**

Find (around line 133):
```swift
        if let analysis = viewModel.personalFit {
          PersonalFitCard(analysis: analysis)
            .padding(.horizontal)
        }
```
Replace with:
```swift
        SchoolFitSection(
          personalFit: viewModel.personalFit,
          academicFit: viewModel.academicFit,
          isEnriching: viewModel.isEnriching,
          enrichError: viewModel.enrichError,
          onLookup: { Task { await viewModel.lookupAcademicData() } }
        )
```

> Match the exact indentation and the real member/label names in the file; the excerpt above may differ slightly from the current source.

- [ ] **Step 2: Present the chooser sheet**

Attach to the detail content container (the same `VStack`/`ScrollView` that hosts the sections — pick the outermost view already carrying modifiers). Bind presentation to `enrichMatches` non-empty:
```swift
      .sheet(isPresented: Binding(
        get: { !viewModel.enrichMatches.isEmpty },
        set: { if !$0 { viewModel.enrichMatches = [] } }
      )) {
        SchoolMatchChooserSheet(
          matches: viewModel.enrichMatches,
          onSelect: { match in Task { await viewModel.confirmEnrich(match) } },
          onCancel: { viewModel.enrichMatches = [] }
        )
      }
```

- [ ] **Step 3: Build to verify**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0, no `error:` lines.

- [ ] **Step 4: Run the full new-test set + lint**

Run:
```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AcademicInfoRangeDecodingTests \
  -only-testing:TheRecruitingCompassTests/AcademicFitSignalsTests \
  -only-testing:TheRecruitingCompassTests/AcademicFitCalculatorTests \
  -only-testing:TheRecruitingCompassTests/SchoolEnrichmentDecodingTests \
  -only-testing:TheRecruitingCompassTests/SchoolDetailAcademicFitTests -quiet
swiftlint --config .swiftlint.yml --quiet TheRecruitingCompass/TheRecruitingCompass/Features/Schools
```
Expected: tests exit 0; lint reports 0 violations in the new files.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift
git commit -m "feat(schools): mount School Fit section (Academic + Personal) on detail page"
```

---

## Acceptance criteria (verify after Task 7)
1. School with `sat_25th`/`act_25th` in `academic_info` → "School Fit" shows Personal Fit then Academic Fit with SAT/ACT rows, badges, acceptance rate.
2. School without range data → Academic Fit shows "Look up this school's academic profile"; tapping runs enrich.
3. Single Scorecard match → data saved, Academic Fit populates, no chooser.
4. Multiple matches → chooser sheet; selecting one saves + populates.
5. No athlete SAT/ACT → rows read "Add your {SAT|ACT} score to your profile."
6. Parent account → look-up shows "Only athlete accounts can look up academic data." (403), no crash.
7. `xcodebuild build` clean; the five new test classes pass.

## Manual verification note
Steps 1–4 of the acceptance criteria exercise the real web enrich endpoint. Verify against a
deployed `API_BASE_URL` with a signed-in athlete account and a school that lacks range data
(recall only ~2/94 schools currently have ranges, so most schools start in the "look up" state).
```
