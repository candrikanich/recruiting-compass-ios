# Quick Communication Template Parity — Phase 2a (Resolution Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill Quick Communication templates from the athlete's real profile using the web `template_variables` registry + a ported pure resolver, and block send while any `{{token}}` stays unresolved — no new panel UI yet (that is Phase 2b).

**Architecture:** Port the web *pure* resolver 1:1 (`utils/templateResolver.ts`): a registry-driven value builder (`column`/`pref`/`authored`/`computed`/`system` dispatch) + `COMPUTED` formatter map + metrics/event block formatters. A `TemplateVariablesService` loads the global registry (cached once/session, fail-open). A `TemplateContextService` gathers the athlete's rows (`users`, player prefs, `performance_metrics`, `events`, `player_profiles`, `documents`, selected `schools`+`coaches`) and computes `derived` values via a **pure** `TemplateContextBuilder.buildDerived`. `QuickCommunicationViewModel` resolves the selected template to `(subject, body, unresolved)` and disables send while `unresolved` is non-empty.

**Tech Stack:** Swift 6, SwiftUI, XCTest, supabase-swift 2.41.1 (`AnyJSON`/`JSONObject` available), MVVM (`@Observable @MainActor` VMs; `Sendable` protocol services).

**Spec:** `planning/2026-08-13-ios-quick-comm-template-parity-spec.md` (§4.2, §4.4, §5, §6 Phase 2)

**Web source-of-truth (verbatim reference):**
- `utils/templateResolver.ts` — pure resolver + `COMPUTED` + metrics/event formatters.
- `composables/useTemplateResolver.ts` — `buildAthleteContext` + grade-appropriate `pickHsCoach`.
- `docs/coach-outreach/template-library-seed.corrected.sql` — the 77 `template_variables` rows.

## Global Constraints

- Build/test from `TheRecruitingCompass/` (Xcode wrapper): `xcodebuild ... -destination 'id=<booted-iPhone-17-udid>'` (iPhone 17 / iOS 26.5 UDID `78D62A71-539B-4C5F-8F22-671FC51CD819`; boot it first, `simctl bootstatus`, then test — CoreSimulatorService flakes on cold boot). Trust xcodebuild exit code, not a grep.
- Source path double-nested: `TheRecruitingCompass/TheRecruitingCompass/...`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/...`.
- New `.swift` files auto-included (`PBXFileSystemSynchronizedRootGroup`) — never edit `.xcodeproj`.
- Line length ≤ 120 (SwiftLint `--config .swiftlint.yml`).
- Every `@MainActor` class needs `nonisolated deinit {}`. N/A to structs/enums/`Sendable` services.
- **Fail-open everywhere:** a registry/context/decode problem yields empty or degraded values, never a crash or a blocked-forever send. Registry missing table → `[]` (templates still render literally). Null/empty value → key OMITTED → `{{token}}` survives → naturally gates send.
- Registry keys are **camelCase** (`coachFirstName`), unlike the legacy 4 snake_case vars. The Phase-1 `TemplateResolver.render`/`findUnresolved` already exist and are reused unchanged.
- NEVER commit `Core/Services/SupabaseConfig.generated.swift` or `Core/Localizable.xcstrings`.

### iOS deviations from web (deliberate, faithful to iOS reality)

- **Metrics:** iOS `PerformanceMetric` lacks `is_primary`/`display_value`/`source`. Resolver uses a dedicated `MetricRow` decode (optional fields) instead — 1:1 web parity, shared model untouched.
- **`sport`/`position`:** iOS has no `sports` table. `derived.sport` = player prefs `primary_sport` (string); `derived.position` = prefs `primary_position` (string). (Web reads `sports.name` via FK; iOS carries free-text prefs — same displayed value.)
- **`videoLink`:** from the canonical `video_links` table (primary healthy link) via existing `VideoLinksService`, not `pref:player.video_links`.
- **Event columns** (`eventName`/`eventLocation`/`rosterLink`/`visitDate`): no event picker in the sheet → resolve null (token survives, gates only templates that use them). Athlete-own-events vars (`eventSchedule`/`nextEventName`/`nextEventDates`) still fill.
- **`positionSecondary`:** resolve null in 2a (iOS prefs expose no secondary-positions array). Token survives; used by few templates.
- **`contactWindowDate`/`daysSinceContact`/`eventDates`:** resolve null — they resolve null on web too (declared `computed` but never populated). Faithful.

---

### Task 1: `TemplateVariableDef` registry model

Decodes a `template_variables` row. `sourceType` is fail-soft (`.unknown` for any unrecognized string) so one odd row can't nuke the array decode.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariableDef.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableDefTests.swift`

**Interfaces:**
- Produces:
  - `struct TemplateVariableDef: Codable, Sendable, Identifiable { key,label,description?,category,sourceType,sourcePath?,isRequiredDefault,example?,sortOrder?; var id: String { key } }`
  - `enum VariableSourceType: String, Codable, Sendable { case column, computed, authored, system, unknown }` — fail-soft decode.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableDefTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableDefTests: XCTestCase {
  func test_decodesColumnRow() throws {
    let json = """
    {"key":"coachFirstName","label":"Coach First Name","category":"program",
     "source_type":"column","source_path":"column:coaches.first_name",
     "is_required_default":false,"sort_order":40}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.key, "coachFirstName")
    XCTAssertEqual(d.sourceType, .column)
    XCTAssertEqual(d.sourcePath, "column:coaches.first_name")
    XCTAssertFalse(d.isRequiredDefault)
  }

  func test_decodesRequiredAuthoredRow() throws {
    let json = """
    {"key":"programNote","label":"Program Note","category":"authored",
     "source_type":"authored","is_required_default":true}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.sourceType, .authored)
    XCTAssertTrue(d.isRequiredDefault)
    XCTAssertNil(d.sourcePath)
  }

  func test_unknownSourceTypeIsFailSoft() throws {
    let json = """
    {"key":"weird","label":"W","category":"system","source_type":"quantum"}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.sourceType, .unknown)
    XCTAssertFalse(d.isRequiredDefault, "missing is_required_default defaults to false")
  }

  func test_arrayWithBadRowDoesNotThrow() throws {
    let json = """
    [{"key":"a","label":"A","category":"system","source_type":"system"},
     {"key":"b","label":"B","category":"x","source_type":"???"}]
    """
    let list = try JSONDecoder().decode([TemplateVariableDef].self, from: Data(json.utf8))
    XCTAssertEqual(list.map(\.sourceType), [.system, .unknown])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'id=78D62A71-539B-4C5F-8F22-671FC51CD819' -only-testing:TheRecruitingCompassTests/TemplateVariableDefTests`
Expected: FAIL to COMPILE — `TemplateVariableDef` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/TemplateVariableDef.swift
import Foundation

enum VariableSourceType: String, Codable, Sendable {
  case column, computed, authored, system, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VariableSourceType(rawValue: raw) ?? .unknown
  }
}

/// One `template_variables` registry row (global; RLS `SELECT USING (true)`).
struct TemplateVariableDef: Codable, Sendable, Identifiable {
  let key: String
  let label: String
  let description: String?
  let category: String
  let sourceType: VariableSourceType
  let sourcePath: String?
  let isRequiredDefault: Bool
  let example: String?
  let sortOrder: Int?

  var id: String { key }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    label = try c.decode(String.self, forKey: .label)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    category = try c.decode(String.self, forKey: .category)
    sourceType = try c.decodeIfPresent(VariableSourceType.self, forKey: .sourceType) ?? .unknown
    sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
    isRequiredDefault = try c.decodeIfPresent(Bool.self, forKey: .isRequiredDefault) ?? false
    example = try c.decodeIfPresent(String.self, forKey: .example)
    sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
  }

  init(key: String, label: String, category: String, sourceType: VariableSourceType,
       sourcePath: String? = nil, isRequiredDefault: Bool = false,
       description: String? = nil, example: String? = nil, sortOrder: Int? = nil) {
    self.key = key; self.label = label; self.description = description; self.category = category
    self.sourceType = sourceType; self.sourcePath = sourcePath
    self.isRequiredDefault = isRequiredDefault; self.example = example; self.sortOrder = sortOrder
  }

  enum CodingKeys: String, CodingKey {
    case key, label, description, category, example
    case sourceType = "source_type"
    case sourcePath = "source_path"
    case isRequiredDefault = "is_required_default"
    case sortOrder = "sort_order"
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — same command as Step 2. Expected: 4 PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariableDef.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableDefTests.swift
git commit -m "feat(templates): add TemplateVariableDef registry model (fail-soft source_type)"
```

---

### Task 2: `TemplateVariablesService` (registry fetch, session cache, fail-open)

Loads the global `template_variables` registry once per session; returns `[]` on missing table (mirrors web `PGRST205` fail-open). Reuses the file-scope `isMissingTableError` from `CommunicationTemplatesService.swift` (Phase 1).

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/TemplateVariablesService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariablesServiceTests.swift`

**Interfaces:**
- Consumes: `TemplateVariableDef` (Task 1); `isMissingTableError` (Phase 1, same module).
- Produces:
  - `protocol TemplateVariablesServicing: Sendable { func fetchRegistry() async throws -> [TemplateVariableDef] }`
  - `actor TemplateVariablesServiceImpl: TemplateVariablesServicing` — caches the first successful fetch.

- [ ] **Step 1: Write the failing test** (cache behavior via an injected fetch closure)

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariablesServiceTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateVariablesServiceTests: XCTestCase {
  func test_cachesFirstSuccessfulFetch() async throws {
    let counter = FetchCounter()
    let sut = TemplateVariablesServiceImpl(fetch: {
      await counter.bump()
      return [TemplateVariableDef(key: "playerName", label: "Player Name",
                                  category: "player", sourceType: .column,
                                  sourcePath: "column:users.full_name")]
    })
    let first = try await sut.fetchRegistry()
    let second = try await sut.fetchRegistry()
    XCTAssertEqual(first.map(\.key), ["playerName"])
    XCTAssertEqual(second.map(\.key), ["playerName"])
    let calls = await counter.count
    XCTAssertEqual(calls, 1, "second call served from cache")
  }

  func test_missingTableFailsOpenToEmpty() async throws {
    struct StubErr: LocalizedError { var errorDescription: String? { "PGRST205 not found" } }
    let sut = TemplateVariablesServiceImpl(fetch: { throw StubErr() })
    let result = try await sut.fetchRegistry()
    XCTAssertEqual(result, [], "missing table degrades to empty, never throws")
  }
}

private actor FetchCounter { private(set) var count = 0; func bump() { count += 1 } }
```

> Add `Equatable` conformance to `TemplateVariableDef` if `XCTAssertEqual(result, [])` needs it, or assert `result.isEmpty` instead. Prefer `XCTAssertTrue(result.isEmpty)` to avoid widening the model's conformances.

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateVariablesServiceTests`. Expected: FAIL to COMPILE (`TemplateVariablesServiceImpl` undefined).

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Services/TemplateVariablesService.swift
import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "TemplateVariablesService"
)

protocol TemplateVariablesServicing: Sendable {
  func fetchRegistry() async throws -> [TemplateVariableDef]
}

actor TemplateVariablesServiceImpl: TemplateVariablesServicing {
  private let fetch: @Sendable () async throws -> [TemplateVariableDef]
  private var cached: [TemplateVariableDef]?

  /// Production init: query `template_variables` (global, ordered by sort_order).
  init(supabaseManager: SupabaseManager = .shared) {
    self.fetch = {
      try await supabaseManager.client
        .from("template_variables")
        .select()
        .order("sort_order", ascending: true)
        .execute()
        .value
    }
  }

  /// Test seam.
  init(fetch: @escaping @Sendable () async throws -> [TemplateVariableDef]) {
    self.fetch = fetch
  }

  func fetchRegistry() async throws -> [TemplateVariableDef] {
    if let cached { return cached }
    do {
      let rows = try await fetch()
      cached = rows
      logger.info("Loaded \(rows.count) template variable defs")
      return rows
    } catch {
      if isMissingTableError(error) {
        logger.warning("template_variables table absent; returning [] (fail-open)")
        cached = []
        return []
      }
      logger.error("fetchRegistry failed: \(error.localizedDescription)")
      throw error
    }
  }
}
```

- [ ] **Step 4: Run test + build** — test command from Step 2, then `xcodebuild build ... -quiet`. Expected: 2 PASS; app builds.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/TemplateVariablesService.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariablesServiceTests.swift
git commit -m "feat(templates): add TemplateVariablesService (registry fetch, session cache, fail-open)"
```

---

### Task 3: Resolver context types + registry-driven value builder

Add the context shapes and the dispatcher that turns `(registry, context)` into a `[key: value]` map (null/empty OMITTED), then reuses Phase-1 `render`/`findUnresolved`. `COMPUTED` is introduced empty here and filled in Tasks 4–6.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/ResolverContext.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverDispatchTests.swift`

**Interfaces:**
- Consumes: `TemplateVariableDef` (Task 1); Phase-1 `TemplateResolver.render`/`findUnresolved`.
- Produces:
  - `struct MetricRow: Decodable, Sendable { metricType?,value?(Double),unit?,displayValue?,isPrimary?(Bool),verified?(Bool),recordedDate?,source? }`
  - `struct EventLite: Sendable { name?,startDate?,endDate?,location?,city?,state?,url? }`
  - `struct ResolverContext: Sendable { tables:[String:[String:String]]; prefs:[String:String]; authored:[String:String]; derived:[String:String]; metrics:[MetricRow]; events:[EventLite]; now:Date }`
  - `TemplateResolver.buildValues(registry:[TemplateVariableDef], context:ResolverContext) -> [String:String]`
  - `TemplateResolver.resolveSourcePath(_ path:String?, _ ctx:ResolverContext) -> String?`
  - `TemplateResolver.computed: [String: @Sendable (ResolverContext) -> String?]` (empty for now).

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverDispatchTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateResolverDispatchTests: XCTestCase {
  private func ctx(
    tables: [String: [String: String]] = [:], prefs: [String: String] = [:],
    authored: [String: String] = [:], derived: [String: String] = [:]
  ) -> ResolverContext {
    ResolverContext(tables: tables, prefs: prefs, authored: authored, derived: derived,
                    metrics: [], events: [], now: Date(timeIntervalSince1970: 0))
  }

  func test_columnSourceResolvesFromKnownTable() {
    let c = ctx(tables: ["coaches": ["first_name": "Sam"]])
    XCTAssertEqual(TemplateResolver.resolveSourcePath("column:coaches.first_name", c), "Sam")
  }

  func test_columnSourceUnknownTableIsNil() {
    let c = ctx(tables: ["widgets": ["x": "y"]])
    XCTAssertNil(TemplateResolver.resolveSourcePath("column:widgets.x", c))
  }

  func test_prefSourceResolvesFromPrefs() {
    let c = ctx(prefs: ["ncaa_id": "1902"])
    XCTAssertEqual(TemplateResolver.resolveSourcePath("pref:player.ncaa_id", c), "1902")
  }

  func test_buildValuesOmitsEmptyAndDispatchesBySourceType() {
    let registry = [
      TemplateVariableDef(key: "coachFirstName", label: "", category: "program",
                          sourceType: .column, sourcePath: "column:coaches.first_name"),
      TemplateVariableDef(key: "playerPhone", label: "", category: "contacts",
                          sourceType: .column, sourcePath: "pref:player.phone"),
      TemplateVariableDef(key: "programNote", label: "", category: "authored",
                          sourceType: .authored),
      TemplateVariableDef(key: "sport", label: "", category: "player", sourceType: .computed),
      TemplateVariableDef(key: "missing", label: "", category: "contacts",
                          sourceType: .column, sourcePath: "pref:player.absent")
    ]
    let c = ctx(tables: ["coaches": ["first_name": "Sam"]],
                prefs: ["phone": "555-0100"],
                authored: ["programNote": "loved the camp"],
                derived: ["sport": "Baseball"])
    let values = TemplateResolver.buildValues(registry: registry, context: c)
    XCTAssertEqual(values["coachFirstName"], "Sam")
    XCTAssertEqual(values["playerPhone"], "555-0100")
    XCTAssertEqual(values["programNote"], "loved the camp")
    XCTAssertEqual(values["sport"], "Baseball")           // computed → derived fallback
    XCTAssertNil(values["missing"], "unresolved key omitted, not empty-string")
  }

  func test_endToEndRenderLeavesUnresolvedForGating() {
    let registry = [TemplateVariableDef(key: "coachSalutation", label: "", category: "program",
                                        sourceType: .computed)]
    let c = ctx(derived: ["coachSalutation": "Coach Smith"])
    let values = TemplateResolver.buildValues(registry: registry, context: c)
    let body = TemplateResolver.render("{{coachSalutation}}, {{programNote}}", values: values)
    XCTAssertEqual(body, "Coach Smith, {{programNote}}")
    XCTAssertEqual(TemplateResolver.findUnresolved(body), ["programNote"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateResolverDispatchTests`. Expected: FAIL to COMPILE (`ResolverContext`/`buildValues` undefined).

- [ ] **Step 3: Write minimal implementation**

Create `ResolverContext.swift`:

```swift
// Features/CommunicationTemplates/Models/ResolverContext.swift
import Foundation

/// One performance_metrics row for the resolver (optional cols the shared PerformanceMetric lacks).
struct MetricRow: Decodable, Sendable {
  let metricType: String?
  let value: Double?
  let unit: String?
  let displayValue: String?
  let isPrimary: Bool?
  let verified: Bool?
  let recordedDate: String?
  let source: String?

  enum CodingKeys: String, CodingKey {
    case value, unit, verified, source
    case metricType = "metric_type"
    case displayValue = "display_value"
    case isPrimary = "is_primary"
    case recordedDate = "recorded_date"
  }
}

/// Minimal event shape for schedule/next-event formatting.
struct EventLite: Sendable {
  let name: String?
  let startDate: String?
  let endDate: String?
  let location: String?
  let city: String?
  let state: String?
  let url: String?
}

/// Gathered athlete + selected-entity context. String values only; nil/empty omitted upstream.
struct ResolverContext: Sendable {
  var tables: [String: [String: String]]   // "users"/"schools"/"coaches"/"events"
  var prefs: [String: String]               // player prefs jsonb, flattened
  var authored: [String: String]            // per-message typed values (empty in 2a)
  var derived: [String: String]             // computed-in-context values (sport, hsCoachName, …)
  var metrics: [MetricRow]
  var events: [EventLite]
  var now: Date
}
```

Extend `TemplateResolver.swift` (add inside the `enum TemplateResolver`):

```swift
  private static let knownTables: Set<String> = ["users", "schools", "coaches", "events"]

  /// COMPUTED formatter map, keyed by variable key. Filled in Tasks 4–6.
  static let computed: [String: @Sendable (ResolverContext) -> String?] = [:]

  /// `column:<table>.<col>` (KNOWN_TABLES only) or `pref:player.<key>`; else nil.
  static func resolveSourcePath(_ path: String?, _ ctx: ResolverContext) -> String? {
    guard let path else { return nil }
    if let body = path.stripping(prefix: "column:") {
      let parts = body.split(separator: ".", maxSplits: 1).map(String.init)
      guard parts.count == 2, knownTables.contains(parts[0]) else { return nil }
      return ctx.tables[parts[0]]?[parts[1]]
    }
    if let key = path.stripping(prefix: "pref:player.") {
      return ctx.prefs[key]
    }
    return nil
  }

  /// Registry → resolved values map. Null/empty OMITTED (so `{{token}}` survives → gates send).
  static func buildValues(registry: [TemplateVariableDef], context ctx: ResolverContext) -> [String: String] {
    var values: [String: String] = [:]
    for def in registry {
      let resolved: String?
      switch def.sourceType {
      case .column:
        resolved = resolveSourcePath(def.sourcePath, ctx)
      case .authored:
        resolved = ctx.authored[def.key]
      case .computed, .system:
        resolved = computed[def.key]?(ctx) ?? ctx.derived[def.key]
      case .unknown:
        resolved = nil
      }
      if let resolved, !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        values[def.key] = resolved
      }
    }
    return values
  }
```

Add a small private helper at file scope in `TemplateResolver.swift`:

```swift
private extension String {
  func stripping(prefix: String) -> String? {
    hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: 5 PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/ResolverContext.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverDispatchTests.swift
git commit -m "feat(templates): registry-driven value builder + source_path parsing"
```

> Stage the test with the full double-nested path: `TheRecruitingCompass/TheRecruitingCompassTests/...`.

---

### Task 4: Scalar `COMPUTED` formatters (player/academics/program/system)

Port the scalar entries of the web `COMPUTED` map (everything except metrics/events, which are Tasks 5–6).

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift` (register these in `computed`)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateComputedScalarTests.swift`

**Interfaces:**
- Produces (all `@Sendable (ResolverContext) -> String?`, in `enum TemplateComputed`): `playerFirstName, height, weight, coachSalutation, schoolShortName, testLabel, testScore, seasonLabel, todayDate`. Registered into `TemplateResolver.computed`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateComputedScalarTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateComputedScalarTests: XCTestCase {
  private func ctx(users: [String: String] = [:], coaches: [String: String] = [:],
                   schools: [String: String] = [:], now: Date = Date(timeIntervalSince1970: 0)) -> ResolverContext {
    ResolverContext(tables: ["users": users, "coaches": coaches, "schools": schools],
                    prefs: [:], authored: [:], derived: [:], metrics: [], events: [], now: now)
  }

  func test_playerFirstName() {
    XCTAssertEqual(TemplateResolver.computed["playerFirstName"]?(ctx(users: ["full_name": "Jordan Lee"])), "Jordan")
  }

  func test_heightInchesToFeetInches() {
    XCTAssertEqual(TemplateResolver.computed["height"]?(ctx(users: ["height_inches": "74"])), "6'2\"")
    XCTAssertNil(TemplateResolver.computed["height"]?(ctx(users: [:])))
  }

  func test_weight() {
    XCTAssertEqual(TemplateResolver.computed["weight"]?(ctx(users: ["weight_lbs": "185"])), "185 lbs")
  }

  func test_coachSalutation() {
    XCTAssertEqual(TemplateResolver.computed["coachSalutation"]?(ctx(coaches: ["last_name": "Smith"])), "Coach Smith")
  }

  func test_schoolShortName_stripsUniversityCollege() {
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "Wooster College"])), "Wooster")
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "Duke University"])), "Duke")
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "MIT"])), "MIT")
  }

  func test_testLabelAndScorePreferACT() {
    let c = ctx(users: ["act_score": "31", "sat_score": "1350"])
    XCTAssertEqual(TemplateResolver.computed["testLabel"]?(c), "ACT")
    XCTAssertEqual(TemplateResolver.computed["testScore"]?(c), "31")
    let satOnly = ctx(users: ["sat_score": "1350"])
    XCTAssertEqual(TemplateResolver.computed["testLabel"]?(satOnly), "SAT")
    XCTAssertEqual(TemplateResolver.computed["testScore"]?(satOnly), "1350")
  }

  func test_seasonLabelByMonthUTC() {
    // 1970-01-01 UTC → month 0 → winter
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: Date(timeIntervalSince1970: 0))), "winter")
    // 2026-05-15 UTC → month 4 → spring
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-05-15T12:00:00Z"))), "spring")
    // 2026-08-15 UTC → month 7 → summer
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-08-15T12:00:00Z"))), "summer")
    // 2026-10-15 UTC → month 9 → fall
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-10-15T12:00:00Z"))), "fall")
  }

  func test_todayDateLongUTC() {
    XCTAssertEqual(TemplateResolver.computed["todayDate"]?(ctx(now: iso("2026-08-14T00:00:00Z"))), "August 14, 2026")
  }

  private func iso(_ s: String) -> Date {
    let f = ISO8601DateFormatter(); return f.date(from: s)!
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateComputedScalarTests`. Expected: FAIL (entries absent → `computed[...]` is nil → optional-chain returns nil ≠ expected).

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/TemplateComputed.swift
import Foundation

/// Scalar COMPUTED formatters — 1:1 port of the web `COMPUTED` map (utils/templateResolver.ts).
enum TemplateComputed {
  private static func s(_ v: String?) -> String? {
    guard let t = v?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
    return t
  }
  private static let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

  static let scalars: [String: @Sendable (ResolverContext) -> String?] = [
    "playerFirstName": { c in
      guard let full = s(c.tables["users"]?["full_name"]) else { return nil }
      return full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    },
    "height": { c in
      guard let raw = c.tables["users"]?["height_inches"], let d = Double(raw) else { return nil }
      let n = Int(d)
      return "\(n / 12)'\(n % 12)\""
    },
    "weight": { c in
      guard let w = s(c.tables["users"]?["weight_lbs"]) else { return nil }
      return "\(w) lbs"
    },
    "coachSalutation": { c in
      guard let last = s(c.tables["coaches"]?["last_name"]) else { return nil }
      return "Coach \(last)"
    },
    "schoolShortName": { c in
      guard let name = s(c.tables["schools"]?["name"]) else { return nil }
      let stripped = name.replacingOccurrences(
        of: #"\s+(University|College)$"#, with: "",
        options: [.regularExpression, .caseInsensitive]
      ).trimmingCharacters(in: .whitespaces)
      return stripped.isEmpty ? name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) : stripped
    },
    "testLabel": { c in
      if s(c.tables["users"]?["act_score"]) != nil { return "ACT" }
      if s(c.tables["users"]?["sat_score"]) != nil { return "SAT" }
      return nil
    },
    "testScore": { c in
      s(c.tables["users"]?["act_score"]) ?? s(c.tables["users"]?["sat_score"])
    },
    "seasonLabel": { c in
      var cal = Calendar(identifier: .gregorian)
      cal.timeZone = TimeZone(identifier: "UTC")!
      let m = cal.component(.month, from: c.now) - 1   // 0-indexed to match JS getUTCMonth()
      if m <= 1 || m == 11 { return "winter" }
      if m <= 4 { return "spring" }
      if m <= 7 { return "summer" }
      return "fall"
    },
    "todayDate": { c in
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US")
      f.timeZone = TimeZone(identifier: "UTC")
      f.dateFormat = "MMMM d, yyyy"
      return f.string(from: c.now)
    }
  ]
}
```

In `TemplateResolver.swift`, replace the empty `computed` with a merge:

```swift
  static let computed: [String: @Sendable (ResolverContext) -> String?] =
    TemplateComputed.scalars
      .merging(TemplateComputed.metrics) { a, _ in a }
      .merging(TemplateComputed.events) { a, _ in a }
```

> `TemplateComputed.metrics` and `.events` are added in Tasks 5–6. For THIS task, register only `.scalars` (define `computed = TemplateComputed.scalars`); widen the merge in Task 5/6. This keeps each task's build green.

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateComputedScalarTests.swift
git commit -m "feat(templates): port scalar COMPUTED formatters (name/height/weight/salutation/test/season/date)"
```

---

### Task 5: Metrics formatters (`metrics`, `carryingTool`, `metricsAsOf`)

Port `rankMetrics`/`renderMetrics`/`carryingTool` + `metricsAsOf` (utils/templateResolver.ts). Ranking: `is_primary` desc, then `verified` desc, then `recorded_date` desc. Block cap 4.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift` (widen `computed` merge to include `.metrics`)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateMetricsTests.swift`

**Interfaces:**
- Produces: `TemplateComputed.metrics: [String: @Sendable (ResolverContext) -> String?]` with keys `metrics`, `carryingTool`, `metricsAsOf`. Helpers `TemplateComputed.renderMetrics(_:cap:)`, `carryingTool(_:)` (internal for testing).

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateMetricsTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateMetricsTests: XCTestCase {
  private func m(_ type: String, _ value: Double? = nil, display: String? = nil,
                primary: Bool = false, verified: Bool = false,
                date: String? = nil, unit: String? = nil, source: String? = nil) -> MetricRow {
    MetricRow(metricType: type, value: value, unit: unit, displayValue: display,
              isPrimary: primary, verified: verified, recordedDate: date, source: source)
  }
  private func ctx(_ metrics: [MetricRow]) -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: [:], derived: [:],
                    metrics: metrics, events: [], now: Date(timeIntervalSince1970: 0))
  }

  func test_renderMetricsRanksPrimaryThenVerifiedThenRecentCap4() {
    let metrics = [
      m("sixty_time", display: "6.8s", date: "2026-01-01"),
      m("exit_velo", display: "95 mph", primary: true, date: "2025-06-01", source: "PBR"),
      m("pop_time", display: "1.9s", verified: true, date: "2025-01-01"),
      m("velocity", display: "88 mph", date: "2026-08-01"),
      m("batting_avg", display: ".410", date: "2024-01-01")
    ]
    let out = TemplateResolver.computed["metrics"]?(ctx(metrics)) ?? ""
    let lines = out.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines.count, 4, "capped at 4")
    XCTAssertEqual(lines[0], "- exit velo: 95 mph (PBR, Jun 2025)", "primary leads, provenance appended")
    XCTAssertEqual(lines[1], "- pop time: 1.9s", "verified next")
    XCTAssertTrue(lines[2].contains("velocity"), "then most recent recorded_date")
  }

  func test_carryingToolIsPrimaryValueAndLabel() {
    let out = TemplateResolver.computed["carryingTool"]?(ctx([
      m("exit_velo", display: "95 mph", primary: true),
      m("sixty_time", display: "6.8s")
    ]))
    XCTAssertEqual(out, "95 mph exit velo")
  }

  func test_carryingToolNilWhenNoPrimary() {
    XCTAssertNil(TemplateResolver.computed["carryingTool"]?(ctx([m("sixty_time", display: "6.8s")])))
  }

  func test_metricDisplayFallsBackToValueUnit() {
    let out = TemplateResolver.computed["metrics"]?(ctx([m("velocity", 88, primary: true, unit: "mph")]))
    XCTAssertEqual(out, "- velocity: 88 mph")
  }

  func test_metricsAsOfLatestMonthYear() {
    let out = TemplateResolver.computed["metricsAsOf"]?(ctx([
      m("a", display: "1", date: "2025-03-10"),
      m("b", display: "2", date: "2026-07-22")
    ]))
    XCTAssertEqual(out, "Jul 2026")
  }

  func test_emptyMetricsNil() {
    XCTAssertNil(TemplateResolver.computed["metrics"]?(ctx([])))
  }
}
```

> Web `metricDisplay` renders numbers verbatim (no int-collapsing): `${m.value}${unit}`. In Swift, `value` is `Double?`; format so `88.0 → "88"` and `6.8 → "6.8"` to match — use the `nf` helper below.

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateMetricsTests`. Expected: FAIL (`metrics`/`carryingTool` keys nil).

- [ ] **Step 3: Write minimal implementation**

Add to `TemplateComputed.swift`:

```swift
  // MARK: - Metrics

  private static func humanizeMetricLabel(_ metricType: String?) -> String {
    (metricType ?? "").replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
  }

  private static func nf(_ d: Double) -> String {
    d == d.rounded() ? String(Int(d)) : String(d)
  }

  private static func metricDisplay(_ m: MetricRow) -> String {
    if let dv = m.displayValue?.trimmingCharacters(in: .whitespaces), !dv.isEmpty { return dv }
    if let v = m.value { return "\(nf(v))\(m.unit.map { " \($0)" } ?? "")" }
    return ""
  }

  static func monthYear(_ iso: String?) -> String? {
    guard let iso, let d = parseDate(iso) else { return nil }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
    return "\(months[cal.component(.month, from: d) - 1]) \(cal.component(.year, from: d))"
  }

  /// Accepts ISO date-time or date-only ("2026-07-22").
  static func parseDate(_ iso: String) -> Date? {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
    if let d = f.date(from: iso) { return d }
    let dOnly = DateFormatter()
    dOnly.locale = Locale(identifier: "en_US_POSIX"); dOnly.timeZone = TimeZone(identifier: "UTC")
    dOnly.dateFormat = "yyyy-MM-dd"
    return dOnly.date(from: String(iso.prefix(10)))
  }

  private static func rankMetrics(_ metrics: [MetricRow]) -> [MetricRow] {
    metrics.sorted { a, b in
      if (a.isPrimary ?? false) != (b.isPrimary ?? false) { return a.isPrimary ?? false }
      if (a.verified ?? false) != (b.verified ?? false) { return a.verified ?? false }
      return (a.recordedDate ?? "") > (b.recordedDate ?? "")
    }
  }

  static func renderMetrics(_ metrics: [MetricRow], cap: Int = 4) -> String {
    rankMetrics(metrics).prefix(cap).map { m in
      let label = humanizeMetricLabel(m.metricType)
      let provenance = [m.source, monthYear(m.recordedDate)].compactMap { $0 }.joined(separator: ", ")
      let tail = provenance.isEmpty ? "" : " (\(provenance))"
      let head = label.isEmpty ? "" : "\(label): "
      return "- \(head)\(metricDisplay(m))\(tail)"
    }.joined(separator: "\n")
  }

  static func carryingTool(_ metrics: [MetricRow]) -> String? {
    guard let primary = metrics.first(where: { $0.isPrimary ?? false }) else { return nil }
    let label = humanizeMetricLabel(primary.metricType)
    let value = metricDisplay(primary)
    let joined = [value, label].filter { !$0.isEmpty }.joined(separator: " ")
    return joined.isEmpty ? nil : joined
  }

  static let metrics: [String: @Sendable (ResolverContext) -> String?] = [
    "metrics": { c in let b = renderMetrics(c.metrics); return b.isEmpty ? nil : b },
    "carryingTool": { c in carryingTool(c.metrics) },
    "metricsAsOf": { c in
      let dates = c.metrics.compactMap { $0.recordedDate }.filter { !$0.isEmpty }.sorted()
      guard let latest = dates.last else { return nil }
      return monthYear(latest)
    }
  ]
```

In `TemplateResolver.swift` widen the merge:

```swift
  static let computed: [String: @Sendable (ResolverContext) -> String?] =
    TemplateComputed.scalars.merging(TemplateComputed.metrics) { a, _ in a }
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateMetricsTests.swift
git commit -m "feat(templates): port metrics block formatters (rank/render cap-4, carryingTool, metricsAsOf)"
```

---

### Task 6: Event formatters (`selectUpcomingEvents`, `renderEventSchedule`, `nextEvent`)

Port the event helpers. These back the **athlete-own-events** derived vars (`eventSchedule`/`nextEventName`/`nextEventDates`), computed in Task 7 from `ctx.events`. This task lands the pure helpers + their `EventLite` tests.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateEventsTests.swift`

**Interfaces:**
- Produces (internal `static` on `TemplateComputed`): `selectUpcomingEvents(_:now:cap:) -> [EventLite]`, `renderEventSchedule(_:now:cap:) -> String?`, `nextEvent(_:now:) -> (name: String?, dates: String?)?`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateEventsTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateEventsTests: XCTestCase {
  private func e(_ name: String, start: String?, end: String? = nil,
                city: String? = nil, state: String? = nil, location: String? = nil) -> EventLite {
    EventLite(name: name, startDate: start, endDate: end, location: location,
              city: city, state: state, url: nil)
  }
  private let now = ISO8601DateFormatter().date(from: "2026-08-14T00:00:00Z")!

  func test_selectUpcomingFiltersPastSortsSoonestCaps() {
    let events = [
      e("Past", start: "2026-01-01", end: "2026-01-02"),
      e("Soon", start: "2026-09-01"),
      e("Later", start: "2026-12-01"),
      e("Today", start: "2026-08-14")
    ]
    let picked = TemplateComputed.selectUpcomingEvents(events, now: now, cap: 5).map { $0.name }
    XCTAssertEqual(picked, ["Today", "Soon", "Later"])
  }

  func test_renderScheduleFormatsRows() {
    let events = [e("Fall Showcase", start: "2026-09-05", city: "Columbus", state: "OH")]
    XCTAssertEqual(TemplateComputed.renderEventSchedule(events, now: now),
                   "- Sep 5 — Fall Showcase, Columbus, OH")
  }

  func test_renderScheduleLocationFallback() {
    let events = [e("Camp", start: "2026-09-05", location: "Ripken Complex")]
    XCTAssertEqual(TemplateComputed.renderEventSchedule(events, now: now),
                   "- Sep 5 — Camp, Ripken Complex")
  }

  func test_nextEventRangeAndSingle() {
    let range = TemplateComputed.nextEvent([e("Series", start: "2026-09-05", end: "2026-09-07")], now: now)
    XCTAssertEqual(range?.name, "Series")
    XCTAssertEqual(range?.dates, "Sep 5–Sep 7")
    let single = TemplateComputed.nextEvent([e("One Day", start: "2026-09-05", end: "2026-09-05")], now: now)
    XCTAssertEqual(single?.dates, "Sep 5")
  }

  func test_emptyScheduleNil() {
    XCTAssertNil(TemplateComputed.renderEventSchedule([], now: now))
    XCTAssertNil(TemplateComputed.nextEvent([], now: now))
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateEventsTests`. Expected: FAIL (helpers undefined).

- [ ] **Step 3: Write minimal implementation**

Add to `TemplateComputed.swift`:

```swift
  // MARK: - Events

  private static func monthDay(_ iso: String?) -> String? {
    guard let iso, let d = parseDate(iso) else { return nil }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
    return "\(months[cal.component(.month, from: d) - 1]) \(cal.component(.day, from: d))"
  }

  private static func eventLocation(_ e: EventLite) -> String? {
    let cityState = [e.city, e.state].compactMap { s($0) }.joined(separator: ", ")
    return cityState.isEmpty ? s(e.location) : cityState
  }

  /// Upcoming (end/start today or later), soonest first, capped.
  static func selectUpcomingEvents(_ events: [EventLite], now: Date, cap: Int = 5) -> [EventLite] {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    let today = f.string(from: now)
    return events
      .filter { e in
        let end = (e.endDate?.isEmpty == false ? e.endDate : e.startDate)
        guard let end else { return false }
        return String(end.prefix(10)) >= today
      }
      .sorted { ($0.startDate ?? "") < ($1.startDate ?? "") }
      .prefix(cap)
      .map { $0 }
  }

  static func renderEventSchedule(_ events: [EventLite], now: Date = Date(), cap: Int = 5) -> String? {
    let rows = selectUpcomingEvents(events, now: now, cap: cap).compactMap { e -> String? in
      let date = monthDay(e.startDate)
      let name = s(e.name)
      if date == nil && name == nil { return nil }
      let head = [date, name].compactMap { $0 }.joined(separator: " — ")
      let loc = eventLocation(e)
      return "- \(head)\(loc.map { ", \($0)" } ?? "")"
    }
    return rows.isEmpty ? nil : rows.joined(separator: "\n")
  }

  static func nextEvent(_ events: [EventLite], now: Date = Date()) -> (name: String?, dates: String?)? {
    guard let next = selectUpcomingEvents(events, now: now, cap: 1).first else { return nil }
    let start = monthDay(next.startDate)
    let end = monthDay(next.endDate)
    let dates: String?
    if let start, let end, end != start { dates = "\(start)–\(end)" } else { dates = start }
    return (name: s(next.name), dates: dates)
  }
```

> These are consumed by Task 7's `buildDerived` (not registered in `computed` — web computes them in the context layer, not the pure `COMPUTED` map). No `TemplateResolver.computed` change in this task.

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateComputed.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateEventsTests.swift
git commit -m "feat(templates): port event schedule + next-event formatters"
```

---

### Task 7: `TemplateContextService` — gather rows + pure `buildDerived`

Gathers the athlete's rows + the selected coach/school, flattens to `ResolverContext`. The derived-value computation is a **pure** `TemplateContextBuilder.buildDerived` (unit-tested); the live Supabase gather is a thin service verified by build.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/TemplateContextService.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateContextBuilder.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateContextBuilderTests.swift`

**Interfaces:**
- Consumes: `TemplateComputed` event helpers (Task 6); `Coach`, `School` models; `PreferenceManaging`/`PlayerDetails` raw prefs; `VideoLinksManaging`; `PlayerProfile`; `Document`.
- Produces:
  - `struct TemplateContextBuilder` with `static func buildDerived(prefs:[String:String], metrics:[MetricRow], events:[EventLite], profileSlug:String?, transcriptURL:String?, videoPrimaryURL:String?, gradYear:Int?, now:Date) -> [String:String]`.
  - `protocol TemplateContextProviding: Sendable { func buildContext(coach:Coach, school:School?, athleteUserId:String?, authored:[String:String], now:Date) async -> ResolverContext }`
  - `struct TemplateContextService: TemplateContextProviding, Sendable`.

- [ ] **Step 1: Write the failing test** (pure builder only)

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateContextBuilderTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateContextBuilderTests: XCTestCase {
  private let now = ISO8601DateFormatter().date(from: "2026-08-14T00:00:00Z")!

  func test_derivesSportPositionFromPrefs() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["primary_sport": "Baseball", "primary_position": "Shortstop"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: 2027, now: now)
    XCTAssertEqual(d["sport"], "Baseball")
    XCTAssertEqual(d["position"], "Shortstop")
  }

  func test_profileAndTranscriptAndVideoLinks() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: [], profileSlug: "jordan-lee",
      transcriptURL: "https://x/tr.pdf", videoPrimaryURL: "https://x/film",
      gradYear: nil, now: now)
    XCTAssertEqual(d["profileLink"], "/jordan-lee")
    XCTAssertEqual(d["transcriptLink"], "https://x/tr.pdf")
    XCTAssertEqual(d["videoLink"], "https://x/film")
  }

  func test_gradeAppropriateHsCoach() {
    // gradYear 2027, now Aug 2026 → schoolYearEnd 2027 → grade = 12-(2027-2027)=12 → twelfth first
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["twelfth_grade_coach": "Coach Twelve", "ninth_grade_coach": "Coach Nine"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: 2027, now: now)
    XCTAssertEqual(d["hsCoachName"], "Coach Twelve")
  }

  func test_hsCoachFallbackWhenGradeMissing() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["tenth_grade_coach": "Coach Ten"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertEqual(d["hsCoachName"], "Coach Ten", "falls back 12→9 when grade unknown")
  }

  func test_eventScheduleAndNextEvent() {
    let events = [EventLite(name: "Showcase", startDate: "2026-09-05", endDate: "2026-09-06",
                            location: nil, city: "Columbus", state: "OH", url: nil)]
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: events, profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertEqual(d["eventSchedule"], "- Sep 5 — Showcase, Columbus, OH")
    XCTAssertEqual(d["nextEventName"], "Showcase")
    XCTAssertEqual(d["nextEventDates"], "Sep 5–Sep 6")
  }

  func test_emptyInputsProduceNoKeys() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertNil(d["sport"]); XCTAssertNil(d["hsCoachName"]); XCTAssertNil(d["eventSchedule"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateContextBuilderTests`. Expected: FAIL (`TemplateContextBuilder` undefined).

- [ ] **Step 3: Write minimal implementation**

`TemplateContextBuilder.swift`:

```swift
// Features/CommunicationTemplates/Models/TemplateContextBuilder.swift
import Foundation

/// Pure derived-value computation (ported from composables/useTemplateResolver.ts).
struct TemplateContextBuilder {
  private static let gradeWords: [Int: String] = [12: "twelfth", 11: "eleventh", 10: "tenth", 9: "ninth"]

  private static func currentGrade(_ gradYear: Int?, now: Date) -> Int? {
    guard let gradYear else { return nil }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
    let month0 = cal.component(.month, from: now) - 1   // 0-indexed
    let year = cal.component(.year, from: now)
    let schoolYearEnd = month0 >= 7 ? year + 1 : year
    return 12 - (gradYear - schoolYearEnd)
  }

  private static func pickHsCoach(_ prefs: [String: String], gradYear: Int?, now: Date) -> String? {
    let grade = currentGrade(gradYear, now: now)
    let clamped = grade.map { min(12, max(9, $0)) }
    let fallback = [12, 11, 10, 9]
    let order = clamped.map { [$0] + fallback.filter { g in g != $0 } } ?? fallback
    for g in order {
      if let word = gradeWords[g],
         let v = prefs["\(word)_grade_coach"]?.trimmingCharacters(in: .whitespaces), !v.isEmpty {
        return v
      }
    }
    return nil
  }

  static func buildDerived(
    prefs: [String: String], metrics: [MetricRow], events: [EventLite],
    profileSlug: String?, transcriptURL: String?, videoPrimaryURL: String?,
    gradYear: Int?, now: Date
  ) -> [String: String] {
    var d: [String: String] = [:]
    func put(_ key: String, _ value: String?) {
      if let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { d[key] = v }
    }
    put("sport", prefs["primary_sport"])
    put("position", prefs["primary_position"])
    put("hsCoachName", pickHsCoach(prefs, gradYear: gradYear, now: now))
    put("profileLink", profileSlug.map { "/\($0)" })
    put("transcriptLink", transcriptURL)
    put("videoLink", videoPrimaryURL)
    put("eventSchedule", TemplateComputed.renderEventSchedule(events, now: now))
    let next = TemplateComputed.nextEvent(events, now: now)
    put("nextEventName", next?.name)
    put("nextEventDates", next?.dates)
    return d
  }
}
```

`TemplateContextService.swift` (live gather; uses the `PreferenceServiceImpl` `JSONValue`-flatten pattern for the raw `users`/`schools`/`coaches` rows). Read the existing `PreferenceServiceImpl.swift` for the `JSONValue` enum + re-encode helper, and reuse `SupabaseManager`:

```swift
// Features/CommunicationTemplates/Services/TemplateContextService.swift
import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "TemplateContextService"
)

protocol TemplateContextProviding: Sendable {
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext
}

struct TemplateContextService: TemplateContextProviding {
  private let supabaseManager: SupabaseManager
  private let prefsService: any PreferenceManaging
  private let videoLinksService: any VideoLinksManaging

  init(supabaseManager: SupabaseManager = .shared,
       prefsService: (any PreferenceManaging)? = nil,
       videoLinksService: (any VideoLinksManaging)? = nil) {
    self.supabaseManager = supabaseManager
    self.prefsService = prefsService ?? PreferenceServiceImpl()
    self.videoLinksService = videoLinksService ?? VideoLinksServiceImpl()
  }

  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    // Selected coach → coaches table dict (typed model → known cols).
    var coachTable: [String: String] = [:]
    coachTable["first_name"] = coach.firstName
    coachTable["last_name"] = coach.lastName
    if let role = coach.position { coachTable["role"] = role }

    var schoolTable: [String: String] = [:]
    if let school {
      schoolTable["name"] = school.name
      if let v = school.division { schoolTable["division"] = v }
      if let v = school.conference { schoolTable["conference"] = v }
      if let v = school.city { schoolTable["city"] = v }
      if let v = school.state { schoolTable["state"] = v }
      if let v = school.twitterHandle { schoolTable["twitter_handle"] = v }
    }

    // Athlete-owned data (all best-effort; any failure → empty).
    var usersTable: [String: String] = [:]
    var prefs: [String: String] = [:]
    var metrics: [MetricRow] = []
    var events: [EventLite] = []
    var gradYear: Int?
    var profileSlug: String?
    var transcriptURL: String?
    var videoPrimaryURL: String?

    if let uid = athleteUserId {
      usersTable = (try? await fetchRowDict(table: "users", idColumn: "id", id: uid)) ?? [:]
      gradYear = usersTable["graduation_year"].flatMap { Int($0) }
      prefs = (try? await fetchPlayerPrefs(userId: uid)) ?? [:]
      metrics = (try? await fetchRows(table: "performance_metrics", userId: uid)) ?? []
      events = (try? await fetchEvents(userId: uid)) ?? []
      profileSlug = try? await fetchProfileSlug(userId: uid)
      transcriptURL = try? await fetchTranscriptURL(userId: uid)
      if let links = try? await videoLinksService.fetchVideoLinks(userId: uid) {
        videoPrimaryURL = (links.first { $0.healthStatus == .healthy } ?? links.first)?.url
      }
    }

    let derived = TemplateContextBuilder.buildDerived(
      prefs: prefs, metrics: metrics, events: events, profileSlug: profileSlug,
      transcriptURL: transcriptURL, videoPrimaryURL: videoPrimaryURL, gradYear: gradYear, now: now)

    return ResolverContext(
      tables: ["users": usersTable, "coaches": coachTable, "schools": schoolTable, "events": [:]],
      prefs: prefs, authored: authored, derived: derived,
      metrics: metrics, events: events, now: now)
  }

  // MARK: - Raw fetch helpers (JSONValue-flatten per PreferenceServiceImpl pattern)

  /// Fetch one row as [col: scalarString], omitting null/empty/array/object values.
  private func fetchRowDict(table: String, idColumn: String, id: String) async throws -> [String: String] {
    let row: JSONObject = try await supabaseManager.client
      .from(table).select("*").eq(idColumn, value: id).single().execute().value
    return row.reduce(into: [:]) { acc, kv in
      if let s = Self.scalarString(kv.value) { acc[kv.key] = s }
    }
  }

  private func fetchPlayerPrefs(userId: String) async throws -> [String: String] {
    struct PrefRow: Decodable { let data: JSONObject }
    let rows: [PrefRow] = try await supabaseManager.client
      .from("user_preferences").select("data")
      .eq("user_id", value: userId).eq("category", value: "player")
      .execute().value
    guard let data = rows.first?.data else { return [:] }
    return data.reduce(into: [:]) { acc, kv in
      if let s = Self.scalarString(kv.value) { acc[kv.key] = s }
    }
  }

  private func fetchRows(table: String, userId: String) async throws -> [MetricRow] {
    try await supabaseManager.client
      .from(table).select("*").eq("user_id", value: userId).execute().value
  }

  private func fetchEvents(userId: String) async throws -> [EventLite] {
    struct Row: Decodable {
      let name: String?; let startDate: String?; let endDate: String?
      let location: String?; let city: String?; let state: String?; let url: String?
      enum CodingKeys: String, CodingKey {
        case name, location, city, state, url
        case startDate = "start_date"; case endDate = "end_date"
      }
    }
    let rows: [Row] = try await supabaseManager.client
      .from("events").select("name, start_date, end_date, location, city, state, url")
      .eq("user_id", value: userId).execute().value
    return rows.map { EventLite(name: $0.name, startDate: $0.startDate, endDate: $0.endDate,
                                location: $0.location, city: $0.city, state: $0.state, url: $0.url) }
  }

  private func fetchProfileSlug(userId: String) async throws -> String? {
    struct Row: Decodable {
      let vanitySlug: String?; let hashSlug: String?
      enum CodingKeys: String, CodingKey { case vanitySlug = "vanity_slug"; case hashSlug = "hash_slug" }
    }
    let rows: [Row] = try await supabaseManager.client
      .from("player_profiles").select("vanity_slug, hash_slug")
      .eq("user_id", value: userId).limit(1).execute().value
    guard let r = rows.first else { return nil }
    return r.vanitySlug ?? r.hashSlug
  }

  private func fetchTranscriptURL(userId: String) async throws -> String? {
    struct Row: Decodable { let fileUrl: String?; enum CodingKeys: String, CodingKey { case fileUrl = "file_url" } }
    let rows: [Row] = try await supabaseManager.client
      .from("documents").select("file_url")
      .eq("user_id", value: userId).eq("type", value: "transcript")
      .order("created_at", ascending: false).limit(1).execute().value
    return rows.first?.fileUrl
  }

  /// AnyJSON scalar → trimmed string, else nil (arrays/objects/null omitted).
  static func scalarString(_ json: AnyJSON) -> String? {
    switch json {
    case .string(let s):
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t
    case .integer(let i): return String(i)
    case .double(let d): return d == d.rounded() ? String(Int(d)) : String(d)
    case .bool(let b): return b ? "true" : "false"
    case .null, .array, .object: return nil
    }
  }
}
```

> **Verify at implementation time:** (a) `PreferenceManaging`/`PreferenceServiceImpl` init signature and whether it exposes a raw-prefs fetch you can reuse instead of the inline `user_preferences` query (prefer reuse); (b) the exact `AnyJSON` cases in supabase-swift 2.41.1 (`.integer` vs merged) — adjust `scalarString` to the real enum; (c) `VideoLinksManaging.fetchVideoLinks(userId:)` signature (matches current `QuickCommunicationViewModel.loadVideoLinks`). None of these change the tested `buildDerived`.

- [ ] **Step 4: Run test + build** — test command from Step 2, then `xcodebuild build ... -quiet`. Expected: 6 builder tests PASS; app builds (the live service is exercised by the build + Task 8/9).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateContextBuilder.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/TemplateContextService.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateContextBuilderTests.swift
git commit -m "feat(templates): add TemplateContextService + pure buildDerived (sport/hsCoach/profile/events)"
```

---

### Task 8: Wire resolver into `QuickCommunicationViewModel` + send-gating

Resolve the selected template via registry + context; expose `resolvedSubject`, `resolvedBody`, `unresolvedKeys`, `isSendBlocked`. Replace the mailto/sms body source with `resolvedBody`. Authored values are an (empty in 2a) dict — required tokens stay unresolved and block send, which is the gate working.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationResolveTests.swift`

**Interfaces:**
- Consumes: `TemplateVariablesServicing` (Task 2), `TemplateContextProviding` (Task 7), `TemplateResolver.buildValues`/`render`/`findUnresolved`.
- Produces on `QuickCommunicationViewModel`:
  - injected `templateVariablesService`, `contextService` (both defaulted, protocol-typed for tests).
  - `private(set) var registry: [TemplateVariableDef]`, `private(set) var resolvedContext: ResolverContext?`, `var authoredValues: [String: String]`.
  - `func loadResolverInputs() async` (loads registry + context once).
  - `var resolvedSubject: String`, `var resolvedBody: String`, `var unresolvedKeys: [String]`, `var isSendBlocked: Bool` (= `!unresolvedKeys.isEmpty`).

- [ ] **Step 1: Write the failing test** (inject fakes; no live Supabase)

```swift
// TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationResolveTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationResolveTests: XCTestCase {
  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com",
          phone: nil, position: "Head Coach", schoolId: "s1")
  }
  private func registry() -> [TemplateVariableDef] {
    [TemplateVariableDef(key: "coachSalutation", label: "", category: "program", sourceType: .computed),
     TemplateVariableDef(key: "programNote", label: "", category: "authored",
                         sourceType: .authored, isRequiredDefault: true)]
  }

  func test_resolvesKnownTokens_gatesOnUnresolved() async {
    let vm = QuickCommunicationViewModel(
      coach: coach(), schoolName: "Duke University",
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: StubContext(derived: ["coachSalutation": "Coach Smith"]))
    await vm.loadResolverInputs()
    vm.selectTemplate(CommunicationTemplate(
      id: "t1", userId: "", name: "Intro", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil,
      createdAt: "", updatedAt: "", subject: "Hi from {{coachSalutation}}"))

    XCTAssertEqual(vm.resolvedSubject, "Hi from Coach Smith")
    XCTAssertEqual(vm.resolvedBody, "Coach Smith, {{programNote}}")
    XCTAssertEqual(vm.unresolvedKeys, ["programNote"])
    XCTAssertTrue(vm.isSendBlocked)
  }

  func test_authoredValueUnblocksSend() async {
    let vm = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: StubContext(derived: ["coachSalutation": "Coach Smith"]))
    await vm.loadResolverInputs()
    vm.authoredValues["programNote"] = "loved the camp"
    vm.selectTemplate(CommunicationTemplate(
      id: "t1", userId: "", name: "Intro", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil, createdAt: "", updatedAt: ""))

    XCTAssertEqual(vm.resolvedBody, "Coach Smith, loved the camp")
    XCTAssertTrue(vm.unresolvedKeys.isEmpty)
    XCTAssertFalse(vm.isSendBlocked)
  }
}

// Minimal stubs
private struct StubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct StubRegistry: TemplateVariablesServicing {
  let defs: [TemplateVariableDef]
  func fetchRegistry() async throws -> [TemplateVariableDef] { defs }
}
private struct StubContext: TemplateContextProviding {
  let derived: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: authored, derived: derived,
                    metrics: [], events: [], now: now)
  }
}
```

> Confirm the `Coach` memberwise init used here matches the real model (Task-2 research: `Coach.swift:6-111`). If `Coach` has no such init, build one in the test via its decoder from a JSON literal instead.

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/QuickCommunicationResolveTests`. Expected: FAIL to COMPILE (new init params + members absent).

- [ ] **Step 3: Write minimal implementation** — in `QuickCommunicationViewModel.swift`:

Add stored deps + state (near existing service props):

```swift
  private let templateVariablesService: any TemplateVariablesServicing
  private let contextService: any TemplateContextProviding

  private(set) var registry: [TemplateVariableDef] = []
  private(set) var resolvedContext: ResolverContext?
  /// Per-message authored values (empty in 2a; the variables panel writes here in 2b).
  var authoredValues: [String: String] = [:]
```

Extend `init` with two defaulted params:

```swift
    templateVariablesService: (any TemplateVariablesServicing)? = nil,
    contextService: (any TemplateContextProviding)? = nil,
```

and assign:

```swift
    self.templateVariablesService = templateVariablesService ?? TemplateVariablesServiceImpl()
    self.contextService = contextService ?? TemplateContextService()
```

Add loader + computed resolution:

```swift
  /// Load the variable registry + gather the athlete/coach/school context once.
  func loadResolverInputs() async {
    if registry.isEmpty { registry = (try? await templateVariablesService.fetchRegistry()) ?? [] }
    resolvedContext = await contextService.buildContext(
      coach: coach, school: nil, athleteUserId: athleteUserId,
      authored: authoredValues, now: Date())
  }

  private func resolvedValues() -> [String: String] {
    guard var ctx = resolvedContext else { return [:] }
    ctx.authored = authoredValues
    return TemplateResolver.buildValues(registry: registry, context: ctx)
  }

  var resolvedSubject: String {
    guard let subject = selectedTemplate?.subject, !subject.isEmpty else { return "" }
    return TemplateResolver.render(subject, values: resolvedValues())
  }

  var resolvedBody: String {
    guard let body = selectedTemplate?.body else { return "" }
    return TemplateResolver.render(body, values: resolvedValues())
  }

  var unresolvedKeys: [String] {
    guard selectedTemplate != nil else { return [] }
    return TemplateResolver.findUnresolved(resolvedSubject + "\n" + resolvedBody)
  }

  var isSendBlocked: Bool { !unresolvedKeys.isEmpty }
```

Repoint the existing send body from the legacy 4-var fill to the resolver. Replace the body used by `mailtoURL()`/`smsURL()`/`logSend` — change `filledBody` to:

```swift
  var filledBody: String { resolvedBody }
```

> Keep the legacy `substitutionValues`/`bodyFilled` path only if other callers need it; otherwise leave `bodyFilled` on the model (used elsewhere) but stop calling it here. `resolvedBody` is empty string when nothing is selected — same contract as before.

**Selected-school wiring:** in `loadResolverInputs`, fetch the school by `coach.schoolId` and pass it into `buildContext` (replace the `school: nil`). Use the existing schools service:

```swift
    let school = try? await schoolsService.fetchSchool(id: coach.schoolId)
```

> Add a `schoolsService` dependency mirroring the other injected services (defaulted to the real impl; protocol-typed). Verify the schools service protocol + `fetchSchool(id:)` signature at implementation time; if it differs, adapt. In tests, `StubContext` ignores `school`, so no schools stub is needed.

- [ ] **Step 4: Run test + build** — test command from Step 2, then `xcodebuild build ... -quiet`. Expected: 2 resolve tests PASS; app builds; existing `QuickCommunicationViewModelTests` still green (run it too).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift \
  TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationResolveTests.swift
git commit -m "feat(coaches): resolve Quick Comm templates via registry + context, gate send on unresolved tokens"
```

---

### Task 9: Wire `loadResolverInputs` into the sheet + minimal preview

Call the loader when the sheet appears and preview the resolved subject/body. No panel yet — just prove the fill happens end-to-end and the send button reflects `isSendBlocked`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift`

**Interfaces:**
- Consumes: `viewModel.loadResolverInputs()`, `resolvedSubject`, `resolvedBody`, `isSendBlocked`, `unresolvedKeys`.

- [ ] **Step 1: Add the loader call** — in the view's existing `.task { await viewModel.loadTemplates() }` (or `.onAppear`), also `await viewModel.loadResolverInputs()`. If they're already in a `.task`, chain them (templates then resolver inputs). Re-resolve is automatic (computed properties).

- [ ] **Step 2: Preview resolved content** — where the preview currently shows `viewModel.filledBody`, show `viewModel.resolvedBody` (now identical) and, for email templates (`selectedTemplate?.type == .email`), show `viewModel.resolvedSubject` above it when non-empty.

- [ ] **Step 3: Reflect gating on send** — disable the send button when `viewModel.isSendBlocked`; when blocked, show helper text: `String(localized: "Fill these before sending: \(viewModel.unresolvedKeys.joined(separator: ", "))")`. Keep existing behavior when not blocked.

- [ ] **Step 4: Build + regression** — `xcodebuild build ... -quiet`, then run `QuickCommunicationViewModelTests`, `QuickCommunicationResolveTests`, `CommunicationTemplatesAccessibilityTests`. Expected: build clean; all PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift
git commit -m "feat(coaches): fill Quick Comm preview from resolver, disable send on unresolved tokens"
```

---

### Task 10: Manual verification

No code. Confirm the engine fills real data end-to-end.

- [ ] **Step 1:** Boot iPhone 17 sim (UDID above), build, launch signed in as an **athlete** with a filled player profile + a coach that has an email.
- [ ] **Step 2:** Tap the coach's email → Quick Communication → pick an intro **email** template. Expected: `{{coachSalutation}}`, `{{schoolShortName}}`, `{{playerFirstName}}`, metrics/height/etc. fill from the profile; subject fills; authored tokens (`{{programNote}}`, `{{updateHook}}`) remain literal; send is **disabled** with "Fill these before sending: programNote…".
- [ ] **Step 3:** Sign in as a **parent** viewing the athlete → same sheet fills identically (read-only context; inline editing is 2b). No crash, no error toast.
- [ ] **Step 4:** Full regression: run the whole `CommunicationTemplates` + `Coaches` test dirs. Trust the exit code.

---

## Self-Review

**Spec coverage (Phase 2 rows relevant to 2a):**
- `template_variables` registry service + model → Task 1 (model) + Task 2 (service). ✅
- `TemplateContextService` + gather → Task 7. ✅
- Computed formatters → Task 4 (scalars) + Task 5 (metrics) + Task 6 (events). ✅
- Adopt camelCase registry keys → registry-driven throughout (Task 3). ✅
- Send disabled while unresolved tokens remain → Task 8 (`isSendBlocked`) + Task 9 (UI). ✅
- Resolution from athlete profile → Tasks 7+8. ✅

**Deferred to Phase 2b (NOT gaps):** variables panel UI (inline-edit athlete-only / authored inputs / read-only + "Edit in profile" link), amber unresolved-token highlighting, editable subject/body fields, 160-char text counter. These are UI; 2a proves the engine + gate.

**Deferred to Phase 3 (per spec):** contact-window pre/open filter, guardrails (`/check` + log), IG entry button.

**Placeholder scan:** every code step has real Swift; the three "verify at implementation time" notes (Task 7 prefs reuse / `AnyJSON` cases / video signature; Task 8 schools-service signature) are integration-surface confirmations, not logic gaps — the unit-tested pure functions are fully specified.

**Type consistency:** `ResolverContext`/`MetricRow`/`EventLite` fields identical across Tasks 3/5/6/7/8. `TemplateResolver.buildValues`/`resolveSourcePath`/`computed` signatures match between Task 3 definition and Tasks 4/5/8 use. `TemplateComputed.scalars`/`.metrics` names match between definition (Tasks 4/5) and the `computed` merge. `buildDerived` signature identical between Task 7 impl + test. `TemplateVariableDef`/`VariableSourceType` identical across Tasks 1/2/3/8.

**Fail-open audit:** registry missing → `[]` (Task 2); context fetch failures → empty tables/prefs (Task 7 `try?`); null/empty value → key omitted → token survives → gates send, never crashes (Task 3).
