# Multi-Sport Performance Metrics — iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every offered sport gets sport-appropriate, correctly-formatted performance-metric types; the logger offers the athlete's sport's metrics (+ `other`); coach templates render them with proper labels.

**Architecture:** Mirror the canonical-positions pattern. Introduce a `Format` enum, a `MetricDef` value type, and a `MetricRegistry` (`defs: [String: MetricDef]` + `sportMetrics: [String: [String]]`) shared byte-identical with web. Critically, `MetricType` is **redefined from a closed `enum` to a `struct` wrapping a `String` rawValue** with the 8 legacy keys kept as `static let` constants — this keeps every existing `== .velocity`, `[MetricType: …]` dictionary, and Codable site compiling while making the type open to arbitrary sport keys. All display logic (`displayName`, `format`, `defaultUnit`, `isLowerBetter`, `unitIsFixed`) delegates to `MetricRegistry.def(for:)`.

**Tech Stack:** Swift 6, SwiftUI, XCTest. iOS 26.5 simulator (`iPhone 17`). No DB migration (`metric_type` is free `text`).

**Spec:** `planning/2026-08-21-multi-sport-metrics-spec.md`

## Global Constraints

- **Byte-identical registry across platforms.** `MetricDef` keys, labels, units, formats, and per-sport ordering must match the web `metricDefs` / `sportMetrics` (web plan is a sibling — this plan lands iOS; web mirrors it). Source of truth for content = the tables in Phase 4 of this plan.
- **Percent convention (locked):** basketball shooting rates (`field_goal_pct`, `three_point_pct`, `free_throw_pct`) render as `45.0%` (`.percent(1)`). ALL other rate stats — baseball `batting_avg`/`on_base_pct`/`slugging_pct`/`fielding_pct`, volleyball `hitting_pct`, hockey `save_pct` — render baseball-style `.450` (`.decimal(3, dropLeadingZero: true)`, no `%`).
- **Text-valued metrics excluded (locked):** no wrestling W-L `record`, no tennis `singles_record`. Registry holds only numeric value+unit metrics. No `.text` Format kind.
- **Zero data migration.** All 8 legacy keys (`velocity, exit_velo, sixty_time, pop_time, batting_avg, era, strikeouts, other`) remain valid registry entries with byte-identical formatting to today. Existing rows keep their `metric_type` strings.
- **Back-compat fallback:** unknown/legacy keys → `MetricRegistry.def(for:)` returns a synthesized def (humanized label from the key, unit `""`, `.decimal(2, dropLeadingZero: false)`, `lowerIsBetter: false`). `TemplateComputed` keeps its `nf` fallback for keys the registry doesn't know (see Task 8).
- **SwiftLint:** line length ≤ 120 (repo `.swiftlint.yml`). Run `swiftlint --config .swiftlint.yml` on touched files.
- **@MainActor classes need `nonisolated deinit {}`** (macOS 26 test-teardown double-free). Not expected here (no new classes), but applies if any is added.
- Build/test dir: `TheRecruitingCompass/`. Source root: `TheRecruitingCompass/TheRecruitingCompass/`.

---

## File Structure

**New files (Core — shared, sport-agnostic):**
- `Core/Utilities/MetricFormat.swift` — `Format` enum + `apply(_:)`.
- `Core/Utilities/MetricDef.swift` — `MetricDef` struct.
- `Core/Utilities/MetricRegistry.swift` — `defs`, `sportMetrics`, `def(for:)`, `knownDef(for:)`, `types(forSport:)`.
- Tests: `TheRecruitingCompassTests/Core/Utilities/MetricFormatTests.swift`, `MetricRegistryTests.swift`.

**Modified (Performance feature):**
- `Features/Performance/Models/MetricType.swift` — enum → struct wrapper, delegate to registry.
- `Features/Performance/Models/MetricFormState.swift` — `populate` via def; `other` custom-name field.
- `Features/Performance/Components/MetricFormView.swift` — sport-filtered picker; custom-name field.
- `Features/Performance/Models/PerformanceMetric.swift` — `displayName`/`formattedValue` via def (no signature change).
- `Features/Performance/ViewModels/PerformanceDashboardViewModel.swift` — `availableMetricTypes` from registry not `allCases`.

**Modified (Events feature — second logger surface):**
- `Features/Events/Components/EventDetail/EventMetricForm.swift`, `Features/Events/Models/NewMetricData.swift`.

**Modified (Templates resolver):**
- `Features/CommunicationTemplates/Models/TemplateComputed.swift` — `humanizeMetricLabel` prefers `knownDef.label`.

**Modified (misc consumers — verify only, likely no change):**
- `Features/Dashboard/Components/MetricRow.swift` (icon switch), `Features/Analytics/Services/AnalyticsServiceImpl.swift` (`== .exitVelo`), `Features/Performance/Utilities/PerformancePDFGenerator.swift`.

---

## Phase 1 — Registry + Formatter (foundation; behavior identical to today)

### Task 1: `Format` enum + `apply`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricFormat.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/MetricFormatTests.swift`

**Interfaces:**
- Produces: `enum Format: Equatable, Sendable` with cases `.decimal(digits: Int, dropLeadingZero: Bool)`, `.integer`, `.percent(digits: Int)`, `.duration`, and `func apply(_ value: Double) -> String` (number only — callers append unit).

- [ ] **Step 1: Write the failing tests**

```swift
// MetricFormatTests.swift
import XCTest
@testable import TheRecruitingCompass

final class MetricFormatTests: XCTestCase {
  func test_decimal_dropsLeadingZero() {
    XCTAssertEqual(Format.decimal(digits: 3, dropLeadingZero: true).apply(0.410), ".410")
    XCTAssertEqual(Format.decimal(digits: 3, dropLeadingZero: true).apply(1.000), "1.000")
  }
  func test_decimal_keepsLeadingZero() {
    XCTAssertEqual(Format.decimal(digits: 2, dropLeadingZero: false).apply(3.45), "3.45")
    XCTAssertEqual(Format.decimal(digits: 1, dropLeadingZero: false).apply(82.3), "82.3")
  }
  func test_integer() {
    XCTAssertEqual(Format.integer.apply(12.0), "12")
    XCTAssertEqual(Format.integer.apply(12.7), "13") // rounds
  }
  func test_percent() {
    XCTAssertEqual(Format.percent(digits: 1).apply(45.0), "45.0")
    XCTAssertEqual(Format.percent(digits: 1).apply(82.34), "82.3")
  }
  func test_duration_minutesSeconds() {
    XCTAssertEqual(Format.duration.apply(112.34), "1:52.34")   // 1:52.34
    XCTAssertEqual(Format.duration.apply(9.41), "0:09.41")
    XCTAssertEqual(Format.duration.apply(581.0), "9:41.00")
  }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/MetricFormatTests`
Expected: FAIL — `cannot find 'Format' in scope`.

- [ ] **Step 3: Implement `MetricFormat.swift`**

```swift
import Foundation

/// How a raw metric value renders (number only — callers append the unit).
/// Byte-identical with web `Format`. `.percent` renders the number without the
/// `%` sign (the sign is the unit). `.duration` renders MM:SS.hh from seconds.
enum Format: Equatable, Sendable {
  case decimal(digits: Int, dropLeadingZero: Bool)
  case integer
  case percent(digits: Int)
  case duration

  func apply(_ value: Double) -> String {
    switch self {
    case let .decimal(digits, dropLeadingZero):
      let s = String(format: "%.\(digits)f", value)
      if dropLeadingZero, s.hasPrefix("0.") { return String(s.dropFirst()) }
      return s
    case .integer:
      return String(Int(value.rounded()))
    case let .percent(digits):
      return String(format: "%.\(digits)f", value)
    case .duration:
      let totalHundredths = (value * 100).rounded()
      let minutes = Int(totalHundredths) / 6000
      let seconds = (Int(totalHundredths) % 6000) / 100
      let hundredths = Int(totalHundredths) % 100
      return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }
  }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2. Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricFormat.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/MetricFormatTests.swift
git commit -m "feat(performance): add Format enum for multi-sport metric rendering"
```

---

### Task 2: `MetricDef` value type

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricDef.swift`

**Interfaces:**
- Consumes: `Format` (Task 1).
- Produces: `struct MetricDef: Equatable, Sendable { let key: String; let label: String; let unit: String; let format: Format; let lowerIsBetter: Bool }`.

- [ ] **Step 1: Implement (no separate test — exercised via registry in Task 3)**

```swift
import Foundation

/// One metric type's definition. `key` is stored verbatim in
/// `performance_metrics.metric_type`. Byte-identical with web `MetricDef`.
struct MetricDef: Equatable, Sendable {
  let key: String
  let label: String
  let unit: String
  let format: Format
  let lowerIsBetter: Bool

  init(_ key: String, _ label: String, _ unit: String,
       _ format: Format, lowerIsBetter: Bool = false) {
    self.key = key
    self.label = label
    self.unit = unit
    self.format = format
    self.lowerIsBetter = lowerIsBetter
  }
}
```

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricDef.swift
git commit -m "feat(performance): add MetricDef value type"
```

---

### Task 3: `MetricRegistry` (baseball keys only, this phase)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricRegistry.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/MetricRegistryTests.swift`

**Interfaces:**
- Consumes: `MetricDef`, `Format`.
- Produces:
  - `static let defs: [String: MetricDef]`
  - `static let sportMetrics: [String: [String]]`
  - `static func knownDef(for key: String) -> MetricDef?` — nil when key absent.
  - `static func def(for key: String) -> MetricDef` — never nil; synthesizes a fallback (humanized label, unit `""`, `.decimal(2, dropLeadingZero: false)`).
  - `static func types(forSport sport: String?) -> [String]` — ordered keys for the sport with `"other"` appended; when the sport is nil/unknown/has no entry, returns `defaultOrder` (all baseball keys) + `"other"`.
  - `static let otherKey = "other"`.

> Phase 1 seeds ONLY the 8 legacy keys so behavior is provably identical to today. Phase 4 fills every sport.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import TheRecruitingCompass

final class MetricRegistryTests: XCTestCase {
  func test_legacyKeys_matchOldFormatting() {
    XCTAssertEqual(MetricRegistry.def(for: "batting_avg").format.apply(0.410), ".410")
    XCTAssertEqual(MetricRegistry.def(for: "era").format.apply(3.45), "3.45")
    XCTAssertEqual(MetricRegistry.def(for: "velocity").format.apply(82.3), "82.3")
    XCTAssertEqual(MetricRegistry.def(for: "sixty_time").format.apply(6.85), "6.85")
    XCTAssertEqual(MetricRegistry.def(for: "strikeouts").format.apply(12.0), "12")
  }
  func test_legacyLabelsAndLowerBetter() {
    XCTAssertEqual(MetricRegistry.def(for: "velocity").label, "Fastball Velocity")
    XCTAssertTrue(MetricRegistry.def(for: "era").lowerIsBetter)
    XCTAssertFalse(MetricRegistry.def(for: "velocity").lowerIsBetter)
  }
  func test_unknownKey_fallback() {
    let d = MetricRegistry.def(for: "wingspan_reach")
    XCTAssertEqual(d.label, "wingspan reach")
    XCTAssertEqual(d.format.apply(12.5), "12.50")
    XCTAssertNil(MetricRegistry.knownDef(for: "wingspan_reach"))
  }
  func test_types_forBaseball_endsWithOther() {
    let t = MetricRegistry.types(forSport: "Baseball")
    XCTAssertEqual(t.last, "other")
    XCTAssertTrue(t.contains("batting_avg"))
  }
  func test_types_forNilSport_returnsDefaultPlusOther() {
    XCTAssertEqual(MetricRegistry.types(forSport: nil).last, "other")
  }
}
```

- [ ] **Step 2: Run, verify fail** (`-only-testing:TheRecruitingCompassTests/MetricRegistryTests`). Expected: FAIL — no `MetricRegistry`.

- [ ] **Step 3: Implement `MetricRegistry.swift`** (labels reuse the exact `String(localized:)` strings from today's `MetricType.displayName`)

```swift
import Foundation

/// Canonical metric-type registry. Swift mirror of web `metricDefs` /
/// `sportMetrics`. Keys are stored verbatim in `performance_metrics.metric_type`.
/// Phase 1 seeds only the 8 legacy baseball/softball keys; later phases add the
/// remaining sports (byte-identical with web).
enum MetricRegistry {
  static let otherKey = "other"

  static let defs: [String: MetricDef] = Dictionary(
    uniqueKeysWithValues: allDefs.map { ($0.key, $0) }
  )

  /// Ordered per-sport keys (NOT including `other`, which `types(forSport:)`
  /// appends). Keys match the sport strings used across onboarding/preferences
  /// and `CanonicalPositions.bySport`.
  static let sportMetrics: [String: [String]] = [
    "Baseball": baseball,
    "Softball": baseball
  ]

  /// Fallback order for nil/unknown sports: all legacy baseball keys.
  private static let defaultOrder = baseball

  static func knownDef(for key: String) -> MetricDef? { defs[key] }

  static func def(for key: String) -> MetricDef {
    if let d = defs[key] { return d }
    let label = key.replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: .whitespaces)
    return MetricDef(key, label, "", .decimal(digits: 2, dropLeadingZero: false))
  }

  static func types(forSport sport: String?) -> [String] {
    let base = lookup(sport) ?? defaultOrder
    return base + [otherKey]
  }

  private static func lookup(_ sport: String?) -> [String]? {
    guard let sport else { return nil }
    return sportMetrics.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value
  }

  // MARK: - Definitions

  private static let baseball = [
    "velocity", "exit_velo", "sixty_time", "pop_time", "batting_avg", "era", "strikeouts"
  ]

  private static let allDefs: [MetricDef] = [
    MetricDef("velocity", String(localized: "Fastball Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("exit_velo", String(localized: "Exit Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("sixty_time", String(localized: "60-Yard Dash"), "sec", .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true),
    MetricDef("pop_time", String(localized: "Pop Time"), "sec", .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true),
    MetricDef("batting_avg", String(localized: "Batting Average"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef("era", String(localized: "ERA"), "", .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true),
    MetricDef("strikeouts", String(localized: "Strikeouts"), "count", .integer),
    MetricDef("other", String(localized: "Other Metric"), "", .decimal(digits: 2, dropLeadingZero: false))
  ]
}
```

- [ ] **Step 4: Run tests, verify pass.** Then run the full `MetricFormatTests` + `MetricRegistryTests` together. Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/MetricRegistry.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/MetricRegistryTests.swift
git commit -m "feat(performance): add MetricRegistry with legacy baseball keys"
```

---

### Task 4: Convert `MetricType` enum → struct wrapper (delegates to registry)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Models/MetricType.swift` (full rewrite)

**Interfaces:**
- Consumes: `MetricRegistry`, `MetricDef`, `Format`.
- Produces: `struct MetricType: RawRepresentable, Codable, Hashable, Identifiable, Sendable` with `init(rawValue: String)` (non-failable) and static constants `.velocity .exitVelo .sixtyTime .popTime .battingAvg .era .strikeouts .other`. Keeps the SAME public surface used elsewhere: `displayName`, `defaultUnit`, `isLowerBetter`, `unitIsFixed`, `format(_:)`, `static let unitVocabulary`, `id`. All delegate to `MetricRegistry.def(for: rawValue)`.

> **Why struct, not raw String:** the sweep found ~20 sites using `== .velocity`, `[MetricType: PerformanceMetric]` dictionaries, `Set<MetricType>`, `switch metric.metricType`, `MetricType.allCases`, and Codable. A struct with static-let constants keeps every one of those compiling except `allCases` (removed — 3 call sites migrate to `MetricRegistry.types` in Tasks 5–7) and the `MetricRow` switch (Task 4b).

- [ ] **Step 1: Rewrite `MetricType.swift`**

```swift
import Foundation

/// A metric type identified by its registry key (stored verbatim in
/// `performance_metrics.metric_type`). Was a closed enum; now an open struct so
/// non-baseball sports get their own keys. Display logic delegates to
/// `MetricRegistry`. The 8 legacy keys remain as static constants for existing
/// `== .velocity` / `[MetricType: …]` call sites.
struct MetricType: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
  let rawValue: String
  init(rawValue: String) { self.rawValue = rawValue }

  var id: String { rawValue }
  private var def: MetricDef { MetricRegistry.def(for: rawValue) }

  var displayName: String { def.label }
  var defaultUnit: String { def.unit }
  var isLowerBetter: Bool { def.lowerIsBetter }

  /// The unit is fixed for every type except `.other`, which lets the athlete
  /// pick from the shared vocabulary. Mirrors the web log-metric modal.
  var unitIsFixed: Bool { self != .other }

  /// Format a raw value to its display string (number only — callers append the
  /// unit). Parity with web `formatMetricValue`.
  func format(_ value: Double) -> String { def.format.apply(value) }

  static let velocity = MetricType(rawValue: "velocity")
  static let exitVelo = MetricType(rawValue: "exit_velo")
  static let sixtyTime = MetricType(rawValue: "sixty_time")
  static let popTime = MetricType(rawValue: "pop_time")
  static let battingAvg = MetricType(rawValue: "batting_avg")
  static let era = MetricType(rawValue: "era")
  static let strikeouts = MetricType(rawValue: "strikeouts")
  static let other = MetricType(rawValue: "other")

  /// Fixed unit vocabulary offered for `.other`. Mirrors the web modal dropdown.
  static let unitVocabulary: [String] = ["", "mph", "sec", "in", "ft", "lbs", "count", "%"]
}
```

- [ ] **Step 2: Build the whole app** — this surfaces every broken call site.

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL at exactly these sites — fix each in Steps 3a–3d:
- `MetricType.allCases` (CaseIterable gone): `MetricFormView.swift:24`, `EventMetricForm.swift:18`, `PerformanceDashboardViewModel.swift:78`.
- `switch metric.metricType { case .velocity … }`: `MetricRow.swift:11-17`.
- `Codable` synthesis: none — `RawRepresentable` where `RawValue: Codable` auto-conforms; `metricType = try container.decode(MetricType.self, …)` still works and decodes the raw string.

- [ ] **Step 3a: Fix `MetricRow.swift` icon switch** (`Features/Dashboard/Components/MetricRow.swift:11-18`) — a `switch` over static-let constants isn't allowed; convert to `if/else` on equality.

```swift
// Replace the `switch metric.metricType { … }` block with:
private var iconName: String {
  let t = metric.metricType
  if t == .velocity || t == .exitVelo { return "flame" }
  if t == .sixtyTime { return "timer" }
  if t == .popTime { return "stopwatch" }
  if t == .battingAvg { return "baseball" }
  if t == .era { return "chart.bar" }
  if t == .strikeouts { return "figure.strengthtraining.traditional" }
  return "chart.line.uptrend.xyaxis" // default for all other/new metrics
}
```
(Read the file first for the exact surrounding property name/return of the `default` case; preserve it.)

- [ ] **Step 3b–3d:** the three `allCases` sites are fixed in Tasks 5, 6, 7 (they need the sport). For THIS task, to keep the build green, temporarily replace each `MetricType.allCases` with `MetricRegistry.types(forSport: nil).map(MetricType.init(rawValue:))`. Tasks 5–7 then thread the real sport through.

- [ ] **Step 4: Build again, expect exit 0. Then run the Performance + Analytics + Templates test classes** to prove behavior is unchanged:

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PerformanceDashboardViewModelTests -only-testing:TheRecruitingCompassTests/MetricRegistryTests -only-testing:TheRecruitingCompassTests/MetricFormatTests`
Expected: PASS (trust xcodebuild exit code + counts, not a grep).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(performance): MetricType enum -> registry-backed struct"
```

---

## Phase 2 — Sport-filtered logger + `other` custom name

### Task 5: `MetricFormState` — def-driven populate + `otherName`

**Files:**
- Modify: `Features/Performance/Models/MetricFormState.swift`

**Interfaces:**
- Produces: `MetricFormState` gains `var otherName: String = ""`; `populate(from:)` formats via `metric.metricType.format`; `isValid` unchanged except when `metricType == .other` it also requires non-empty `otherName`.

- [ ] **Step 1: Update the struct**

```swift
struct MetricFormState: Equatable {
  var metricType: MetricType?
  var value: String = ""
  var recordedDate: Date = Date.now
  var unit: String = ""
  var notes: String = ""
  var verified: Bool = false
  /// Custom label when `metricType == .other` — stored as the row's metric_type
  /// so it stops rendering as literally "other".
  var otherName: String = ""

  var isValid: Bool {
    guard let metricType, !value.isEmpty, Double(value) != nil else { return false }
    if metricType == .other { return !otherName.trimmingCharacters(in: .whitespaces).isEmpty }
    return true
  }

  var parsedValue: Double? { Double(value) }

  /// The metric_type key to persist: the custom `otherName` (snake_cased) when
  /// `other`, else the type's rawValue.
  var resolvedMetricKey: String? {
    guard let metricType else { return nil }
    if metricType == .other {
      let trimmed = otherName.trimmingCharacters(in: .whitespaces)
      return trimmed.isEmpty ? nil
        : trimmed.lowercased().replacingOccurrences(of: " ", with: "_")
    }
    return metricType.rawValue
  }

  mutating func reset() {
    metricType = nil; value = ""; recordedDate = Date.now
    unit = ""; notes = ""; verified = false; otherName = ""
  }

  mutating func populate(from metric: PerformanceMetric) {
    metricType = metric.metricType
    let digits = (metric.metricType == .battingAvg || metric.metricType == .era) ? 3 : 2
    value = metric.value.formatted(.number.precision(.fractionLength(digits)))
    recordedDate = metric.recordedDate
    unit = metric.unit
    notes = metric.notes ?? ""
    verified = metric.verified
    otherName = ""
  }
}
```

> **Note for the executor:** the ViewModel add/edit path (`PerformanceDashboardViewModel.swift:188,226`) currently reads `addFormState.metricType`. After this task it must persist `resolvedMetricKey` instead of `metricType.rawValue` when building the create/update request. Fold that edit into this task and re-run `PerformanceDashboardViewModelTests`.

- [ ] **Step 2: Build + run `PerformanceDashboardViewModelTests`.** Fix compile at the two ViewModel call sites. Expected: PASS.
- [ ] **Step 3: Commit** `feat(performance): metric form other-name field + def-driven populate`

---

### Task 6: `MetricFormView` — sport-filtered picker + custom-name field

**Files:**
- Modify: `Features/Performance/Components/MetricFormView.swift`

**Interfaces:**
- Consumes: `MetricRegistry.types(forSport:)`, `MetricFormState.otherName`.
- Produces: `MetricFormView` gains `let sport: String?` (the athlete's `primary_sport`, injected by the parent view). Picker iterates `MetricRegistry.types(forSport: sport).map(MetricType.init(rawValue:))`. When `metricType == .other`, show a `TextField` bound to `$formState.otherName` ("Metric name").

- [ ] **Step 1:** Add `let sport: String?` property. Replace the `ForEach(MetricType.allCases)` (lines 24-26) with:

```swift
ForEach(MetricRegistry.types(forSport: sport), id: \.self) { key in
  let type = MetricType(rawValue: key)
  Text(type.displayName).tag(type as MetricType?)
}
```

- [ ] **Step 2:** After the Metric Type picker `VStack`, insert a custom-name field shown only for `.other`:

```swift
if formState.metricType == .other {
  VStack(alignment: .leading, spacing: 4) {
    Text("Metric Name").font(.subheadline).fontWeight(.medium)
    TextField("e.g. Vertical Jump", text: $formState.otherName)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel(String(localized: "Custom metric name"))
  }
}
```

- [ ] **Step 3:** Update every `MetricFormView(...)` construction site to pass `sport:` (the parent already has the athlete's `PlayerDetails.primarySport` in scope, or reads it from the ViewModel). Read `PerformanceDashboardView.swift` and the add/edit sheet presenters to find the call sites; thread the sport through. Build.
- [ ] **Step 4:** Manual sim check: build+run, open Log Metric as a baseball athlete → baseball list; as a basketball athlete (once Phase 4 lands) → basketball list; pick "Other" → name field appears, Save disabled until named.
- [ ] **Step 5: Commit** `feat(performance): sport-filtered metric picker + other custom name`

---

### Task 7: `EventMetricForm` + `PerformanceDashboardViewModel.availableMetricTypes`

**Files:**
- Modify: `Features/Events/Components/EventDetail/EventMetricForm.swift`, `Features/Events/Models/NewMetricData.swift`, `Features/Performance/ViewModels/PerformanceDashboardViewModel.swift`

- [ ] **Step 1:** `EventMetricForm.swift:18` — replace `ForEach(MetricType.allCases)` with the sport-filtered form (add a `let sport: String?` to `EventMetricForm`, thread it from `EventDetailViewModel`). `NewMetricData.metricType: MetricType = .velocity` stays valid (static let). Persist `metricType.rawValue` (or an `otherName` if you extend `NewMetricData` the same way — optional; Events "other" polish can be deferred, note it in the commit if so).
- [ ] **Step 2:** `PerformanceDashboardViewModel.swift:77-78` — currently:
```swift
let types = Set(metrics.map(\.metricType))
availableMetricTypes = MetricType.allCases.filter { types.contains($0) }
```
Replace `MetricType.allCases` with the registry-ordered sport list so the filter bar orders by sport relevance and still only shows types the athlete has logged:
```swift
let logged = Set(metrics.map(\.metricType))
let ordered = MetricRegistry.types(forSport: playerSport).map(MetricType.init(rawValue:))
availableMetricTypes = ordered.filter { logged.contains($0) }
  + logged.subtracting(ordered).sorted { $0.displayName < $1.displayName }
```
(`playerSport` — read from the ViewModel's loaded `PlayerDetails.primarySport`; if not already held, add it. The trailing `subtracting` keeps any logged legacy/unknown key visible.)
- [ ] **Step 3:** Remove the temporary `types(forSport: nil)` shims left in Task 4 Step 3b now that real sports are threaded. Build whole app, exit 0.
- [ ] **Step 4:** Run `PerformanceDashboardViewModelTests`, `EventDetailViewModelTests`. Expected PASS.
- [ ] **Step 5: Commit** `feat(performance,events): registry-ordered available types + event picker`

---

## Phase 3 — Resolver labels

### Task 8: `TemplateComputed` label + value via registry

**Files:**
- Modify: `Features/CommunicationTemplates/Models/TemplateComputed.swift`

**Interfaces:**
- Consumes: `MetricRegistry.knownDef(for:)`.

- [ ] **Step 1: Write failing tests** (add to the existing template resolver test class; if none targets `humanizeMetricLabel`, add `TemplateComputedMetricsTests`):

```swift
func test_metricsLabel_usesRegistryLabel_forKnownKey() {
  let rows = [TemplateMetricRow(metricType: "batting_avg", value: 0.410, /* … other fields nil */)]
  let out = TemplateComputed.renderMetrics(rows)
  XCTAssertTrue(out.contains("Batting Average: .410"))
}
func test_metricsLabel_humanizesUnknownKey() {
  let rows = [TemplateMetricRow(metricType: "vertical_jump", value: 32, /* … */)]
  let out = TemplateComputed.renderMetrics(rows)
  XCTAssertTrue(out.contains("vertical jump: 32"))
}
```
(Fill the `TemplateMetricRow` initializer with the real field list — read the struct first.)

- [ ] **Step 2: Run, verify the first fails** (`Batting Average` label not yet produced — today it humanizes to `batting avg`).

- [ ] **Step 3:** Update `humanizeMetricLabel` (line 99-101) to prefer the registry label:

```swift
private static func humanizeMetricLabel(_ metricType: String?) -> String {
  let key = metricType ?? ""
  if let def = MetricRegistry.knownDef(for: key) { return def.label }
  return key.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
}
```

Update `formatValue` (line 109-111) to consult the registry, preserving the `nf` fallback for keys the registry doesn't know:

```swift
private static func formatValue(_ v: Double, type: String?) -> String {
  if let def = MetricRegistry.knownDef(for: type ?? "") { return def.format.apply(v) }
  return nf(v)
}
```

- [ ] **Step 4: Run tests, verify pass.** Also run the existing communication-templates resolver tests to confirm `{{metrics}}` / `{{carryingTool}}` snapshots still pass (labels for baseball keys change from `batting avg` → `Batting Average` — update any snapshot expectations that asserted the old humanized form; that is the intended improvement).
- [ ] **Step 5: Commit** `feat(templates): metric labels + formatting from MetricRegistry`

---

## Phase 4 — Content (all 17 sports)

### Task 9: Populate `metricDefs` + `sportMetrics` for every sport

**Files:**
- Modify: `Core/Utilities/MetricRegistry.swift` (append defs + sport entries)
- Test: extend `MetricRegistryTests.swift`

**Locked content** (percent + text decisions applied; `↓` = `lowerIsBetter: true`; first key in each list is the recommended default `is_primary` / carrying-tool candidate; order = recruiting relevance). Format shorthand: `dec(d[,drop0])` → `.decimal(digits: d, dropLeadingZero: drop0)`; `int` → `.integer`; `pct(d)` → `.percent(digits: d)`; `dur` → `.duration`.

**Baseball / Softball** (`baseball`, shared):
`velocity` mph dec(1) · `exit_velo` mph dec(1) · `batting_avg` "" dec(3,drop0) · `sixty_time` sec dec(2)↓ · `pop_time` sec dec(2)↓ · `era` "" dec(2)↓ · `on_base_pct` "" dec(3,drop0) · `slugging_pct` "" dec(3,drop0) · `whip` "" dec(2)↓ · `strikeouts` count int · `fielding_pct` "" dec(3,drop0)
_default primary:_ `velocity`

**Basketball:**
`points_per_game` "" dec(1) · `rebounds_per_game` "" dec(1) · `assists_per_game` "" dec(1) · `field_goal_pct` % pct(1) · `three_point_pct` % pct(1) · `free_throw_pct` % pct(1) · `steals_per_game` "" dec(1) · `blocks_per_game` "" dec(1) · `vertical_jump` in dec(1)
_default primary:_ `points_per_game`

**Football:**
`forty_time` sec dec(2)↓ · `vertical_jump` in dec(1) · `bench_press` reps int · `broad_jump` in int · `shuttle` sec dec(2)↓ · `three_cone` sec dec(2)↓ · `squat` lbs int · `passing_yards` yds int · `rushing_yards` yds int · `receiving_yards` yds int · `tackles` count int
_default primary:_ `forty_time`

**Soccer:**
`goals` count int · `assists` count int · `saves` count int · `clean_sheets` count int · `minutes_played` count int
_default primary:_ `goals`

**Volleyball:**
`kills` count int · `assists` count int · `blocks` count int · `digs` count int · `aces` count int · `hitting_pct` "" dec(3,drop0)
_default primary:_ `kills`

**Track & Field:**
`sprint_time` sec dec(2)↓ · `distance_time` "" dur↓ · `relay_split` sec dec(2)↓ · `long_jump` m dec(2) · `high_jump` m dec(2) · `shot_put` m dec(2) · `discus` m dec(2)
_default primary:_ `sprint_time`

**Cross Country:**
`race_time` "" dur↓ · `pace_per_mile` "" dur↓
_default primary:_ `race_time`

**Swimming:**
`event_time` "" dur↓ · `free_50` sec dec(2)↓ · `free_100` "" dur↓
_default primary:_ `event_time`

**Golf:**
`scoring_average` strokes dec(1)↓ · `handicap` "" dec(1)↓
_default primary:_ `scoring_average`

**Tennis:** _(text `singles_record` excluded)_
`utr_rating` "" dec(2) · `ranking` "" int↓
_default primary:_ `utr_rating`

**Wrestling:** _(text `record` excluded)_
`pins` count int · `takedowns` count int · `weight_class` lbs int
_default primary:_ `pins`

**Lacrosse:**
`goals` count int · `assists` count int · `ground_balls` count int · `saves` count int
_default primary:_ `goals`

**Ice Hockey:**
`points` count int · `goals` count int · `assists` count int · `save_pct` "" dec(3,drop0) · `goals_against_avg` "" dec(2)↓
_default primary:_ `points`

**Field Hockey:**
`goals` count int · `assists` count int · `saves` count int
_default primary:_ `goals`

**Rowing:**
`erg_2k` "" dur↓ · `erg_split` "" dur↓
_default primary:_ `erg_2k`

**Water Polo:**
`goals` count int · `assists` count int · `saves` count int · `steals` count int
_default primary:_ `goals`

> **Shared keys across sports** (`goals`, `assists`, `saves`, `vertical_jump`) get ONE `MetricDef` in `defs` (deduped); each sport lists the key in its `sportMetrics` order. `vertical_jump` label = "Vertical Jump", unit `in`, dec(1) — shared by basketball + football.

- [ ] **Step 1: Write tests** asserting a representative def per new sport + the default-primary ordering (first key):

```swift
func test_basketball_order_and_percent() {
  XCTAssertEqual(MetricRegistry.sportMetrics["Basketball"]?.first, "points_per_game")
  XCTAssertEqual(MetricRegistry.def(for: "field_goal_pct").format.apply(45.0), "45.0")
  XCTAssertEqual(MetricRegistry.def(for: "field_goal_pct").unit, "%")
}
func test_hockey_savePct_isBaseballStyle() {
  XCTAssertEqual(MetricRegistry.def(for: "save_pct").format.apply(0.915), ".915")
}
func test_duration_sports() {
  XCTAssertEqual(MetricRegistry.def(for: "race_time").format.apply(581.0), "9:41.00")
  XCTAssertTrue(MetricRegistry.def(for: "erg_2k").lowerIsBetter)
}
func test_everySportHasDefs_andOtherAppended() {
  for sport in MetricRegistry.sportMetrics.keys {
    let types = MetricRegistry.types(forSport: sport)
    XCTAssertEqual(types.last, "other")
    for key in types where key != "other" {
      XCTAssertNotNil(MetricRegistry.knownDef(for: key), "missing def for \(key)")
    }
  }
}
func test_sharedKeys_singleDef() {
  XCTAssertEqual(MetricRegistry.def(for: "goals").label, "Goals")
}
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3:** Append all `MetricDef`s to `allDefs` (dedupe shared keys) and all sport entries to `sportMetrics`. Add `on_base_pct`, `slugging_pct`, `whip`, `fielding_pct` to the `baseball` order (baseball list grows from 7 → 11). Keep labels human-friendly title case ("Points Per Game", "Field Goal %", "40 Time" → use "40-Yard Dash" style; "2K Erg", etc.). Wrap labels in `String(localized:)`.
- [ ] **Step 4: Run all registry + format tests, verify pass. Build whole app. Run the full Performance + Templates + Analytics test classes.**
- [ ] **Step 5: Commit** `feat(performance): populate metric registry for all 17 sports`

---

## Phase 5 — Web parity (sibling plan, separate repo)

Out of scope for THIS iOS plan — track as a follow-on plan in `recruiting-compass-web`:
- Port `Format` / `metricDefs` / `sportMetrics` byte-identical (TS).
- `formatMetricValue` consults `metricDefs[key].format`.
- `LogMetricModal` renders `sportMetrics[primary_sport]` + `other` custom-name field.
- `templateResolver.humanizeMetricLabel` uses `def.label`.
- **Parity gate:** a cross-repo test (or manual diff) asserting the iOS `allDefs` and web `metricDefs` produce identical (key, label, unit, format, lowerIsBetter) tuples. Use the `platform-parity` skill.

---

## Self-Review

**Spec coverage:**
- Registry + `MetricDef` + `Format` (`.decimal/.integer/.percent/.duration`) → Tasks 1–3. ✅
- `MetricType` → string-key + lookup → Task 4 (struct wrapper — preserves call sites). ✅
- `formattedValue`/`MetricFormState`/`TrendCard`/`LatestMetricCard`/`TemplateComputed` route through def → Tasks 4 (via `MetricType.format` delegation — `TrendCard`/`LatestMetricCard`/`PerformanceMetric.formattedValue` unchanged because they call `MetricType.format`, which now delegates), 5, 8. ✅
- Logger filters by `primary_sport` + always `other` → Tasks 6, 7. ✅
- `other` custom name → Tasks 5, 6. ✅
- Resolver `humanizeMetricLabel` → def.label → Task 8. ✅
- No DB migration; back-compat unknown keys → Global Constraints + Task 3 fallback + Task 8 `nf` fallback. ✅
- All 17 sports content, percent split, text excluded, default primary + ordering → Task 9. ✅

**Placeholder scan:** all code steps carry real code; content table fully specified. Executor must READ before editing `MetricRow.swift`, the `MetricFormView` call sites, `PerformanceDashboardViewModel` sport source, and `TemplateMetricRow`'s initializer (flagged inline).

**Type consistency:** `MetricRegistry.types(forSport:)`, `knownDef(for:)`, `def(for:)`, `MetricDef(key,label,unit,format,lowerIsBetter:)`, `Format.apply(_:)`, `MetricFormState.resolvedMetricKey`, `MetricType(rawValue:)` used consistently across tasks.

**Open executor decisions (non-blocking):**
- Events-form "other" custom-name parity (Task 7) — deferrable; note if skipped.
- `is_primary` default is a UI suggestion only; no auto-write of primary on first log is in scope (existing `set_primary_metric` star toggle stays the mechanism). The "default primary" column guides ordering + future auto-select, not this build.
