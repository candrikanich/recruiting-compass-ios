# Quick Communication Template Parity — Phase 3 (Contact-Window + Guardrails + IG) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the athlete only the window-appropriate intro template (silent pre/open swap), enforce anti-spam guardrails on send (hard block on a reused program note, two-step confirm on recent/repeated contact, both fail-open), and add an Instagram open-profile button — completing web parity for coach outreach.

**Architecture:** Three ports from web, all fail-open. (1) A pure `ContactWindow` evaluator (1:1 from `utils/contactWindow.ts`) + a cached `ContactWindowService` reading the global `contact_window_rules` table; the VM filters its template lists through `filterTemplatesByWindow` before the picker sees them. (2) An `AthleteMessagesService` calling the already-prod web API `POST /api/athlete/messages/check` + `/api/athlete/messages` with Bearer + CSRF (mirroring `PublicProfileServiceImpl`); the VM orchestrates block/confirm exactly like web `passesSendGuardrails`. (3) An IG button opening `https://instagram.com/{handle}`. No DB migrations — every table/endpoint already exists in prod.

**Tech Stack:** Swift 6, SwiftUI, XCTest, MVVM (`@Observable @MainActor` VM; pure structs for logic; `Sendable` protocol services).

**Spec:** `planning/2026-08-13-ios-quick-comm-template-parity-spec.md` (§4.3 contact-window, §4.5 guardrails, §4.6 compose flows, §5 architecture, §6 Phase 3)

**Prereq (VERIFIED 2026-08-14):** `contact_window_rules` populated in prod (`D1/D2/D3/NAIA/JUCO`, sports lowercase + `*`); `schools.division` stores exactly `D1/D2/D3/NAIA/JUCO` (nulls fail open) — no normalization needed. `POST /api/athlete/messages/check` and `/api/athlete/messages` both return 403 JSON "Invalid CSRF token" in prod (deployed; need Bearer + `x-csrf-token`). CSRF plumbing already exists: `PublicProfileServiceImpl.fetchCSRFToken` (GET `/api/csrf-token` → read `csrf-token` cookie).

**Web source of truth (port 1:1):**
- `recruiting-compass-web/utils/contactWindow.ts` (Task 1)
- `recruiting-compass-web/composables/useContactWindow.ts` (Task 2 caching/fail-open contract)
- `recruiting-compass-web/composables/useAthleteMessages.ts` (Task 4 API shapes)
- `recruiting-compass-web/components/CommunicationPanel.vue:983-1034` (Task 5 `passesSendGuardrails` + `logSentMessage`)

## Global Constraints

- Build/test from `TheRecruitingCompass/`: `xcodebuild test -scheme TheRecruitingCompass -destination 'id=78D62A71-539B-4C5F-8F22-671FC51CD819'` (iPhone 17 / iOS 26.5). **Boot the sim to `Booted` first** (`xcrun simctl boot 78D62A71-539B-4C5F-8F22-671FC51CD819`; verify `simctl list devices | grep Booted`). If `xcodebuild` loops `build number "" incompatible with DVTBuildVersion`, kill it, `xcrun simctl shutdown all`, `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, re-boot. Use plain `xcodebuild test` (not `test-without-building`). Trust the exit code, not a "TEST SUCCEEDED" grep.
- Every `@MainActor XCTestCase` needs `nonisolated deinit {}` (macOS 26 teardown double-free).
- A test that touches `Binding.wrappedValue` needs `import SwiftUI`.
- Line length ≤ 120 (SwiftLint, run from repo root: `swiftlint lint --config .swiftlint.yml <files>`).
- NEVER commit `Core/Services/SupabaseConfig.generated.swift` or `Core/Localizable.xcstrings` (build regenerates both — always show modified).
- **Fail-open everywhere:** a missing rule, unparseable config, missing division/gradYear, or ANY guardrail-lookup failure must never hide the standard intro or block a legit send. Only two things block: unresolved `{{tokens}}` (Phase 2) and a `programNoteReused` hard block.

### Scope boundaries (per spec §6)

- **In P3:** contact-window pre/open eval + silent template swap; guardrails (`/check` hard-block + two-step confirm, `/messages` best-effort log); Instagram open-profile button.
- **NOT in P3:** any new DB migration (all applied); a social composer (parity = IG button only, no compose); changing the Phase-2 token gate.

---

### Task 1: `ContactWindow` — pure evaluator + template filter (port `utils/contactWindow.ts`)

Pure Swift port of the web module: rule model, per-athlete open-date computation, pre/open decision (fail-open), and the silent template swap.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/ContactWindow.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/ContactWindowTests.swift`

**Interfaces:**
- Consumes: `CommunicationTemplate` (has `type`, `stage`, `contactWindow` — all added in P1).
- Produces:
  - `enum ContactWindowState: String { case pre, open }`
  - `struct ContactWindowRule: Codable, Sendable, Equatable { sport, division: String; ruleKind: String; reference, windowDate, notes: String? }` — decodes snake_case `rule_kind`/`window_date` via CodingKeys.
  - `struct ContactWindowInput { sport: String?; division: String?; gradYear: Int?; today: Date }`
  - `struct ContactWindowResult: Equatable { state: ContactWindowState; opensOn: Date?; rule: ContactWindowRule? }`
  - `enum ContactWindow` with statics:
    - `computeWindowOpenDate(_ rule: ContactWindowRule, gradYear: Int) -> Date?`
    - `evaluate(rules: [ContactWindowRule], input: ContactWindowInput) -> ContactWindowResult`
    - `filterByWindow<T>(_ templates: [T], state: ContactWindowState, group: (T) -> String, window: (T) -> String?) -> [T]` — generic over the template type; `group` yields `"\(type):\(stage)"`, `window` yields `contact_window`. (Swift can't mirror the TS structural `WindowedTemplate` constraint, so pass accessors.)

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../ContactWindowTests.swift
import XCTest
@testable import TheRecruitingCompass

final class ContactWindowTests: XCTestCase {
  private func rule(_ sport: String, _ div: String, _ kind: String,
                    ref: String? = nil, date: String? = nil) -> ContactWindowRule {
    ContactWindowRule(sport: sport, division: div, ruleKind: kind,
                      reference: ref, windowDate: date, notes: nil)
  }
  private func cal(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
  }

  // date_after_grade: baseball-style "Sept 1" of the year the reference grade completes.
  func test_computeOpenDate_dateAfterGrade() {
    let r = rule("football", "D1", "date_after_grade", ref: "sophomore", date: "Sept 1")
    // sophomore=10; endYear = gradYear-(12-10)=2027-2=2025 → Sept 1, 2025
    XCTAssertEqual(ContactWindow.computeWindowOpenDate(r, gradYear: 2027), cal(2025, 9, 1))
  }

  // date_before_grade: "Aug 1" the summer before the reference grade → endYear-1.
  func test_computeOpenDate_dateBeforeGrade() {
    let r = rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")
    // junior=11; endYear=2027-1=2026; before → 2025 → Aug 1, 2025
    XCTAssertEqual(ContactWindow.computeWindowOpenDate(r, gradYear: 2027), cal(2025, 8, 1))
  }

  func test_computeOpenDate_unrestrictedOrUnparseable_nil() {
    XCTAssertNil(ContactWindow.computeWindowOpenDate(rule("*", "D3", "unrestricted"), gradYear: 2027))
    XCTAssertNil(ContactWindow.computeWindowOpenDate(
      rule("*", "D1", "date_after_grade", ref: "bogus", date: "Sept 1"), gradYear: 2027))
    XCTAssertNil(ContactWindow.computeWindowOpenDate(
      rule("*", "D1", "date_after_grade", ref: "junior", date: "notadate"), gradYear: 2027))
  }

  func test_evaluate_missingDivisionOrGradYear_failsOpen() {
    let rules = [rule("*", "D1", "date_after_grade", ref: "sophomore", date: "Jun 15")]
    XCTAssertEqual(ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: nil, gradYear: 2027, today: cal(2024, 1, 1))).state, .open)
    XCTAssertEqual(ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: "D1", gradYear: nil, today: cal(2024, 1, 1))).state, .open)
  }

  func test_evaluate_prefersExactSportOverWildcard() {
    let rules = [
      rule("*", "D1", "date_after_grade", ref: "sophomore", date: "Jun 15"),
      rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")
    ]
    let res = ContactWindow.evaluate(rules: rules,
      input: .init(sport: "Baseball", division: "D1", gradYear: 2027, today: cal(2024, 1, 1)))
    XCTAssertEqual(res.rule?.ruleKind, "date_before_grade")  // exact sport wins, case-insensitive
    XCTAssertEqual(res.state, .pre)                          // 2024 < Aug 1 2025
  }

  func test_evaluate_afterOpenDate_isOpen() {
    let rules = [rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")]
    let res = ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: "D1", gradYear: 2027, today: cal(2026, 1, 1)))
    XCTAssertEqual(res.state, .open)  // 2026 > Aug 1 2025
  }

  func test_evaluate_noMatchingRule_failsOpen() {
    let res = ContactWindow.evaluate(rules: [rule("*", "D2", "unrestricted")],
      input: .init(sport: "baseball", division: "D1", gradYear: 2027, today: cal(2024, 1, 1)))
    XCTAssertEqual(res.state, .open)
    XCTAssertNil(res.rule)
  }

  // --- filterByWindow ---
  private struct T { let type: String; let stage: String; let window: String? }
  private func filt(_ items: [T], _ state: ContactWindowState) -> [T] {
    ContactWindow.filterByWindow(items, state: state,
      group: { "\($0.type):\($0.stage)" }, window: { $0.window })
  }

  func test_filter_open_hidesPreTemplates() {
    let items = [T(type: "email", stage: "intro", window: "pre"),
                 T(type: "email", stage: "intro", window: "any")]
    XCTAssertEqual(filt(items, .open).map(\.window), ["any"])
  }

  func test_filter_pre_hidesAnyWhenPreSiblingExists() {
    let items = [T(type: "email", stage: "intro", window: "pre"),
                 T(type: "email", stage: "intro", window: "any"),
                 T(type: "email", stage: "followup", window: "any")]
    // intro group has a pre sibling → its "any" is hidden; followup "any" kept.
    let kept = filt(items, .pre)
    XCTAssertEqual(kept.map { "\($0.stage):\($0.window ?? "")" }, ["intro:pre", "followup:any"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/ContactWindowTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/ContactWindow.swift
import Foundation

enum ContactWindowState: String, Sendable { case pre, open }

/// One `contact_window_rules` row (global reference config).
struct ContactWindowRule: Codable, Sendable, Equatable {
  let sport: String       // lowercase sport, or "*" for the division default
  let division: String    // D1 | D2 | D3 | NAIA | JUCO
  let ruleKind: String    // date_before_grade | date_after_grade | unrestricted
  let reference: String?  // grade the window anchors to, e.g. "junior"
  let windowDate: String? // display date, e.g. "Aug 1"
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case sport, division, notes
    case ruleKind = "rule_kind"
    case reference
    case windowDate = "window_date"
  }
}

struct ContactWindowInput {
  var sport: String?
  var division: String?
  var gradYear: Int?
  var today: Date = Date()
}

struct ContactWindowResult: Equatable {
  let state: ContactWindowState
  let opensOn: Date?
  let rule: ContactWindowRule?
}

/// Per-sport / per-division NCAA contact-window logic (1:1 port of web `utils/contactWindow.ts`).
/// Fails OPEN everywhere — a config gap must never gate outreach.
enum ContactWindow {
  private static let gradeByReference: [String: Int] =
    ["freshman": 9, "sophomore": 10, "junior": 11, "senior": 12]
  private static let months: [String: Int] = [
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12]

  /// Parse "Aug 1" / "Sept 15" → (month 1-12, day). Nil if unparseable.
  private static func parseWindowDate(_ raw: String?) -> (month: Int, day: Int)? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
    guard let match = trimmed.range(of: #"^([a-z]+)\.?\s+(\d{1,2})$"#, options: .regularExpression)
    else { return nil }
    let parts = trimmed[match].replacingOccurrences(of: ".", with: "")
      .split(separator: " ", maxSplits: 1).map(String.init)
    guard parts.count == 2, let month = months[parts[0]], let day = Int(parts[1]), day > 0
    else { return nil }
    return (month, day)
  }

  static func computeWindowOpenDate(_ rule: ContactWindowRule, gradYear: Int) -> Date? {
    if rule.ruleKind == "unrestricted" { return nil }
    guard let grade = gradeByReference[(rule.reference ?? "").lowercased()],
          let parsed = parseWindowDate(rule.windowDate) else { return nil }
    let endYear = gradYear - (12 - grade)                       // spring the grade completes
    let year = rule.ruleKind == "date_before_grade" ? endYear - 1 : endYear
    return Calendar(identifier: .gregorian).date(
      from: DateComponents(year: year, month: parsed.month, day: parsed.day))
  }

  /// Most specific rule: exact (sport, division) → ("*", division) → nil.
  private static func selectRule(_ rules: [ContactWindowRule],
                                 sport: String?, division: String) -> ContactWindowRule? {
    let sportKey = (sport ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    let forDivision = rules.filter { $0.division == division }
    return forDivision.first { $0.sport.lowercased() == sportKey && !sportKey.isEmpty }
      ?? forDivision.first { $0.sport == "*" }
  }

  static func evaluate(rules: [ContactWindowRule], input: ContactWindowInput) -> ContactWindowResult {
    guard let division = input.division, let gradYear = input.gradYear else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: nil)
    }
    guard let rule = selectRule(rules, sport: input.sport, division: division) else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: nil)
    }
    guard let opensOn = computeWindowOpenDate(rule, gradYear: gradYear) else {
      return ContactWindowResult(state: .open, opensOn: nil, rule: rule)
    }
    return ContactWindowResult(state: input.today < opensOn ? .pre : .open, opensOn: opensOn, rule: rule)
  }

  /// Silent swap: in `open`, hide `pre` templates; in `pre`, hide an `any` template when a
  /// `pre` sibling exists in the same (type, stage) group. Athlete always sees one intro.
  static func filterByWindow<T>(_ templates: [T], state: ContactWindowState,
                                group: (T) -> String, window: (T) -> String?) -> [T] {
    if state == .open {
      return templates.filter { window($0) != "pre" }
    }
    let groupsWithPre = Set(templates.filter { window($0) == "pre" }.map(group))
    return templates.filter { window($0) != "any" || !groupsWithPre.contains(group($0)) }
  }
}
```

> **Verify at impl time:** the `parseWindowDate` split after stripping `.` — the regex captures `([a-z]+)\.?\s+(\d+)`; simplest robust parse is: lowercase+trim, regex-match, then re-split. If the `String.range(of:options:.regularExpression)` slice handling is awkward, use `NSRegularExpression` with capture groups (as `TemplateResolver` does) — same result, assert against the 3 unparseable cases in Step 1.

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: 10 PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/ContactWindow.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/ContactWindowTests.swift
git commit -m "feat(templates): add pure ContactWindow evaluator + silent template swap (port)"
```

---

### Task 2: `ContactWindowService` — load rules (cached, fail-open)

Protocol + impl that fetches `contact_window_rules` once per session and fails open (empty list) on any error, mirroring `TemplateVariablesService`.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/ContactWindowService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/ContactWindowServiceTests.swift`

**Interfaces:**
- Consumes: `ContactWindowRule` (Task 1), `SupabaseManager.shared` (existing), the same query pattern as `TemplateVariablesServiceImpl` (open `Features/CommunicationTemplates/Services/TemplateVariablesService.swift` and mirror it — same caching + PGRST205 fail-open shape).
- Produces:
  - `protocol ContactWindowServicing: Sendable { func fetchRules() async throws -> [ContactWindowRule] }`
  - `final class ContactWindowServiceImpl: ContactWindowServicing` — caches the first successful fetch in an actor-isolated cache (copy `TemplateVariablesServiceImpl`'s caching approach verbatim), returns `[]` on missing-table / decode / network error.
  - `struct MockContactWindowService: ContactWindowServicing` (test helper, in the test file) returning an injected array.

- [ ] **Step 1: Read the sibling to copy** — open `Features/CommunicationTemplates/Services/TemplateVariablesService.swift`. Note its exact caching mechanism (module/actor cache), how it selects columns, and how it swallows `PGRST205`/errors to `[]`. `ContactWindowServiceImpl` is the same shape with `.from("contact_window_rules").select("sport, division, rule_kind, reference, window_date, notes")` decoding into `[ContactWindowRule]`.

- [ ] **Step 2: Write the failing test** — the impl hits the network, so the meaningful unit test is the protocol contract + that `evaluate` composes with a stubbed service. Test the mock + a fail-open decode path:

```swift
// TheRecruitingCompassTests/.../ContactWindowServiceTests.swift
import XCTest
@testable import TheRecruitingCompass

struct MockContactWindowService: ContactWindowServicing {
  let rules: [ContactWindowRule]
  func fetchRules() async throws -> [ContactWindowRule] { rules }
}

final class ContactWindowServiceTests: XCTestCase {
  func test_mockReturnsInjectedRules() async throws {
    let svc = MockContactWindowService(rules: [
      ContactWindowRule(sport: "*", division: "D1", ruleKind: "unrestricted",
                        reference: nil, windowDate: nil, notes: nil)])
    let rules = try await svc.fetchRules()
    XCTAssertEqual(rules.count, 1)
    XCTAssertEqual(rules.first?.division, "D1")
  }

  func test_ruleDecodesSnakeCaseColumns() throws {
    let json = Data("""
    {"sport":"baseball","division":"D1","rule_kind":"date_before_grade",
     "reference":"junior","window_date":"Aug 1","notes":"n"}
    """.utf8)
    let rule = try JSONDecoder().decode(ContactWindowRule.self, from: json)
    XCTAssertEqual(rule.ruleKind, "date_before_grade")
    XCTAssertEqual(rule.windowDate, "Aug 1")
  }
}
```

- [ ] **Step 3: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/ContactWindowServiceTests`. Expected: FAIL to COMPILE (no `ContactWindowServicing`).

- [ ] **Step 4: Write minimal implementation** — create `ContactWindowService.swift` mirroring `TemplateVariablesServiceImpl`. Shape (fill the caching + fetch body from the sibling; do NOT invent a new cache pattern):

```swift
// Features/CommunicationTemplates/Services/ContactWindowService.swift
import Foundation

protocol ContactWindowServicing: Sendable {
  func fetchRules() async throws -> [ContactWindowRule]
}

/// Loads the global `contact_window_rules` config once per session; fails OPEN (returns [])
/// on missing table / decode / network error so a config gap never gates outreach.
final class ContactWindowServiceImpl: ContactWindowServicing {
  // MIRROR TemplateVariablesServiceImpl: same cache actor/box + same PGRST205 → [] handling.
  // .from("contact_window_rules")
  // .select("sport, division, rule_kind, reference, window_date, notes")
  // decode [ContactWindowRule]; on any error return [] (log + swallow).
}
```

- [ ] **Step 5: Run test to verify it passes** — same as Step 3. Expected: 2 PASS.

- [ ] **Step 6: Build** — `xcodebuild build ... -quiet`. Expected: clean (verifies the real impl compiles against `SupabaseManager`).

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/ContactWindowService.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/ContactWindowServiceTests.swift
git commit -m "feat(templates): add ContactWindowService (cached rules, fail-open)"
```

---

### Task 3: VM — window-filtered template lists

Load rules on the VM, evaluate pre/open from the resolved context (sport/division/gradYear), and route `emailTemplates`/`textTemplates` through the swap so the picker only ever shows the window-appropriate intro.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationWindowTests.swift`

**Interfaces:**
- Consumes: `ContactWindow` (Task 1), `ContactWindowServicing` (Task 2), Phase-2a `resolvedContext` (has `tables["schools"]["division"]`, `tables["users"]["graduation_year"]`, `derived["sport"]`).
- Produces on `QuickCommunicationViewModel`:
  - New injected dependency `contactWindowService: any ContactWindowServicing` (default `ContactWindowServiceImpl()`), added to `init` (optional param, same pattern as the other services).
  - `private(set) var contactWindowRules: [ContactWindowRule] = []` — loaded in `loadResolverInputs()` (best-effort, after context).
  - `var contactWindowState: ContactWindowState` — computes `ContactWindow.evaluate` from `resolvedContext` (fail-open `.open` when context nil).
  - `emailTemplates`/`textTemplates` retargeted: filter the existing `templates.filter { $0.type == ... }` result through `ContactWindow.filterByWindow(..., state: contactWindowState, group: { "\($0.type.rawValue):\($0.stage ?? "")" }, window: { $0.contactWindow })`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../QuickCommunicationWindowTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationWindowTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func tpl(_ id: String, window: String?, stage: String) -> CommunicationTemplate {
    CommunicationTemplate(id: id, userId: "", name: id, type: .email, body: "b",
      variables: nil, createdAt: "", updatedAt: "", slug: id, stage: stage, contactWindow: window)
  }

  private func makeVM(division: String?, gradYear: String?, rules: [ContactWindowRule]) async
    -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: WindowStubTemplates(),
      templateVariablesService: WindowStubRegistry(),
      contextService: WindowStubContext(division: division, gradYear: gradYear, sport: "baseball"),
      contactWindowService: MockContactWindowService(rules: rules))
    await v.loadResolverInputs()
    v.templates = [tpl("intro-pre", window: "pre", stage: "intro"),
                   tpl("intro-any", window: "any", stage: "intro"),
                   tpl("followup", window: "any", stage: "followup")]
    return v
  }

  func test_openState_hidesPreTemplates() async {
    // D3 unrestricted → open → pre hidden.
    let v = await makeVM(division: "D3", gradYear: "2027",
      rules: [ContactWindowRule(sport: "*", division: "D3", ruleKind: "unrestricted",
                                reference: nil, windowDate: nil, notes: nil)])
    XCTAssertEqual(v.contactWindowState, .open)
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-any", "followup"])
  }

  func test_preState_swapsAnyForPreSibling() async {
    // D1 baseball date_before_grade junior Aug 1, today far before → pre.
    let v = await makeVM(division: "D1", gradYear: "2030",
      rules: [ContactWindowRule(sport: "baseball", division: "D1", ruleKind: "date_before_grade",
                                reference: "junior", windowDate: "Aug 1", notes: nil)])
    XCTAssertEqual(v.contactWindowState, .pre)
    // intro group: pre sibling exists → "any" intro hidden; pre intro + followup kept.
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-pre", "followup"])
  }

  func test_missingContext_failsOpen() async {
    let v = await makeVM(division: nil, gradYear: nil, rules: [])
    XCTAssertEqual(v.contactWindowState, .open)
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-any", "followup"])
  }
}

private struct WindowStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct WindowStubRegistry: TemplateVariablesServicing {
  func fetchRegistry() async throws -> [TemplateVariableDef] { [] }
}
private struct WindowStubContext: TemplateContextProviding {
  let division: String?; let gradYear: String?; let sport: String
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    var tables: [String: [String: String]] = [:]
    if let division { tables["schools"] = ["division": division] }
    if let gradYear { tables["users"] = ["graduation_year": gradYear] }
    return ResolverContext(tables: tables, prefs: [:], authored: authored,
                           derived: ["sport": sport], metrics: [], events: [], now: now)
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/QuickCommunicationWindowTests`. Expected: FAIL to COMPILE (`init` has no `contactWindowService`).

- [ ] **Step 3: Write minimal implementation** — in `QuickCommunicationViewModel.swift`:

Add the dependency (store + init param, matching the other services):
```swift
  private let contactWindowService: any ContactWindowServicing
  // in init signature: contactWindowService: (any ContactWindowServicing)? = nil,
  // in init body:      self.contactWindowService = contactWindowService ?? ContactWindowServiceImpl()
```

Add state + load (append to the end of `loadResolverInputs()`):
```swift
  private(set) var contactWindowRules: [ContactWindowRule] = []
  // …in loadResolverInputs(), after resolvedContext is set:
  if contactWindowRules.isEmpty {
    contactWindowRules = (try? await contactWindowService.fetchRules()) ?? []
  }
```

Add the evaluation + retarget the two template lists:
```swift
  var contactWindowState: ContactWindowState {
    guard let ctx = resolvedContext else { return .open }
    return ContactWindow.evaluate(rules: contactWindowRules, input: ContactWindowInput(
      sport: ctx.derived["sport"],
      division: ctx.tables["schools"]?["division"],
      gradYear: ctx.tables["users"]?["graduation_year"].flatMap(Int.init),
      today: Date())).state
  }

  private func windowFiltered(_ list: [CommunicationTemplate]) -> [CommunicationTemplate] {
    ContactWindow.filterByWindow(list, state: contactWindowState,
      group: { "\($0.type.rawValue):\($0.stage ?? "")" }, window: { $0.contactWindow })
  }

  var emailTemplates: [CommunicationTemplate] { windowFiltered(templates.filter { $0.type == .email }) }
  var textTemplates: [CommunicationTemplate] { windowFiltered(templates.filter { $0.type == .message }) }
```
(Replace the existing `emailTemplates`/`textTemplates` computed properties.)

- [ ] **Step 4: Run test + regression** — Step 2 command, then re-run `QuickCommunicationViewModelTests` + `QuickCommunicationPanelTests` (the `emailTemplates`/`textTemplates` change must not break them — with no `contact_window` set the filter is a pass-through in `.open`). Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift \
  TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationWindowTests.swift
git commit -m "feat(coaches): silent contact-window template swap in Quick Communication"
```

---

### Task 4: `AthleteMessagesService` — `/check` + `/messages` (Bearer + CSRF)

Protocol + impl calling the prod web API, mirroring `PublicProfileServiceImpl` (Bearer + `x-csrf-token` from `GET /api/csrf-token`). Both calls fail-open at the call site (Task 5), but the service surfaces real errors so the VM can `try?`.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/AthleteMessagesService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/AthleteMessagesServiceTests.swift`

**Interfaces:**
- Consumes: `SupabaseConfig.apiBaseURL` (existing), the CSRF pattern in `Features/PublicProfile/Services/PublicProfileServiceImpl.swift` (`fetchCSRFToken`) — copy that helper's approach.
- Produces:
  - `struct SendCheckResult: Decodable, Equatable, Sendable { let programNoteReused: Bool; let daysSinceLastContact: Int?; let recentContact: Bool; let messageCountToSchool: Int }` (camelCase — the API already returns camelCase per `useAthleteMessages.ts`).
  - `struct SendCheckInput: Encodable { let athleteUserId: String; let schoolId: String?; let programNote: String? }`
  - `struct LogMessageInput: Encodable { let athleteUserId: String; let schoolId, coachId, templateSlug, channel, programNote, updateHook, subject, body: String? }`
  - `protocol AthleteMessagesServicing: Sendable {`
    `func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult`
    `func logSend(_ input: LogMessageInput, accessToken: String?) async throws }`
  - `struct AthleteMessagesServiceImpl: AthleteMessagesServicing` — POST JSON, `Bearer` + `x-csrf-token`; `checkSend` decodes `SendCheckResult`; `logSend` ignores the body (best-effort). Throws `AthleteMessagesError.notConfigured` when `apiBaseURL`/token missing.

- [ ] **Step 1: Write the failing test** — use a `URLProtocol` stub so no network is hit. (Copy the harness if one already exists — `grep -rl "URLProtocol" TheRecruitingCompassTests` first; if `DashboardServiceImpl` tests have one, reuse its pattern.)

```swift
// TheRecruitingCompassTests/.../AthleteMessagesServiceTests.swift
import XCTest
@testable import TheRecruitingCompass

final class AthleteMessagesServiceTests: XCTestCase {
  override func tearDown() { StubURLProtocol.handler = nil; super.tearDown() }

  private func session() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: cfg)
  }

  func test_checkSend_decodesResult() async throws {
    StubURLProtocol.handler = { req in
      if req.url!.path.hasSuffix("/api/csrf-token") {
        let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil,
          headerFields: ["Set-Cookie": "csrf-token=tok123; Path=/"])!
        return (resp, Data())
      }
      let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      let body = Data(#"{"programNoteReused":true,"daysSinceLastContact":3,"recentContact":true,"messageCountToSchool":2}"#.utf8)
      return (resp, body)
    }
    let svc = AthleteMessagesServiceImpl(
      session: session(), baseURLOverride: URL(string: "https://example.com")!)
    let res = try await svc.checkSend(
      .init(athleteUserId: "a1", schoolId: "s1", programNote: "note"), accessToken: "tok")
    XCTAssertTrue(res.programNoteReused)
    XCTAssertEqual(res.messageCountToSchool, 2)
    XCTAssertEqual(res.daysSinceLastContact, 3)
  }

  func test_missingToken_throwsNotConfigured() async {
    let svc = AthleteMessagesServiceImpl(
      session: session(), baseURLOverride: URL(string: "https://example.com")!)
    do {
      _ = try await svc.checkSend(.init(athleteUserId: "a1", schoolId: nil, programNote: nil),
                                  accessToken: nil)
      XCTFail("expected throw")
    } catch { /* ok */ }
  }
}
```

> If no `StubURLProtocol` exists in the test target, add it in this file:
> ```swift
> final class StubURLProtocol: URLProtocol {
>   nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
>   override class func canInit(with request: URLRequest) -> Bool { true }
>   override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
>   override func startLoading() {
>     guard let handler = Self.handler else { client?.urlProtocolDidFinishLoading(self); return }
>     let (resp, data) = handler(request)
>     client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
>     client?.urlProtocol(self, didLoad: data)
>     client?.urlProtocolDidFinishLoading(self)
>   }
>   override func stopLoading() {}
> }
> ```
> Note the CSRF cookie is read from `HTTPCookieStorage.shared` in the prod helper; with an ephemeral session the stub's `Set-Cookie` may not populate shared storage. If the ported `fetchCSRFToken` can't find the cookie under test, have `AthleteMessagesServiceImpl` read the token from the response's `Set-Cookie` header (via the returned `HTTPURLResponse`) as a fallback — assert the checkSend result either way. Keep the prod path (shared-cookie) identical to `PublicProfileServiceImpl`.

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/AthleteMessagesServiceTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation** — port from `PublicProfileServiceImpl` (Bearer + `fetchCSRFToken` + `x-csrf-token`):

```swift
// Features/CommunicationTemplates/Services/AthleteMessagesService.swift
import Foundation
import OSLog

struct SendCheckResult: Decodable, Equatable, Sendable {
  let programNoteReused: Bool
  let daysSinceLastContact: Int?
  let recentContact: Bool
  let messageCountToSchool: Int
}
struct SendCheckInput: Encodable {
  let athleteUserId: String
  let schoolId: String?
  let programNote: String?
}
struct LogMessageInput: Encodable {
  let athleteUserId: String
  let schoolId: String?
  let coachId: String?
  let templateSlug: String?
  let channel: String?
  let programNote: String?
  let updateHook: String?
  let subject: String?
  let body: String?
}
enum AthleteMessagesError: Error { case notConfigured, server(Int) }

protocol AthleteMessagesServicing: Sendable {
  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult
  func logSend(_ input: LogMessageInput, accessToken: String?) async throws
}

struct AthleteMessagesServiceImpl: AthleteMessagesServicing {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "AthleteMessages")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }
  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult {
    let data = try await post("api/athlete/messages/check", body: input, accessToken: accessToken)
    return try JSONDecoder().decode(SendCheckResult.self, from: data)
  }
  func logSend(_ input: LogMessageInput, accessToken: String?) async throws {
    _ = try await post("api/athlete/messages", body: input, accessToken: accessToken)
  }

  private func post<B: Encodable>(_ path: String, body: B, accessToken: String?) async throws -> Data {
    guard let baseURL, let token = accessToken, !token.isEmpty else {
      throw AthleteMessagesError.notConfigured
    }
    let csrf = try await fetchCSRFToken(baseURL: baseURL)
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
    request.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw AthleteMessagesError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    return data
  }

  // Port of PublicProfileServiceImpl.fetchCSRFToken (GET /api/csrf-token → csrf-token cookie).
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/csrf-token"))
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw AthleteMessagesError.server(-1)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrf = cookies.first(where: { $0.name == "csrf-token" }) else {
      throw AthleteMessagesError.server(-1)
    }
    return csrf.value
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: PASS (adjust the CSRF-cookie fallback per the Step 1 note if the ephemeral session doesn't populate shared cookie storage).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/AthleteMessagesService.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/AthleteMessagesServiceTests.swift
git commit -m "feat(templates): add AthleteMessagesService (/check + /messages, Bearer + CSRF)"
```

---

### Task 5: VM — guardrail orchestration (block / two-step confirm / fail-open + log)

Port `passesSendGuardrails` + `logSentMessage`: before a send opens the composer, run `checkSend`; hard-block on `programNoteReused`, arm a two-step confirm on `recentContact || messageCountToSchool >= 2`, fail-open on any error; on a confirmed send, `logSend` to the API (best-effort, in addition to the existing interaction logging).

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationGuardrailTests.swift`

**Interfaces:**
- Consumes: `AthleteMessagesServicing` (Task 4), Phase-2a `authoredValues`, `selectedTemplate?.slug`, `effectiveSubject`/`effectiveBody`.
- Produces on `QuickCommunicationViewModel`:
  - New injected dependency `athleteMessagesService: any AthleteMessagesServicing` (default `AthleteMessagesServiceImpl()`), added to `init`.
  - `configureContext` gains `accessToken: String?` (stored as `private var accessToken`), so the sheet passes `authManager.session?.accessToken`.
  - `enum GuardrailChannel { case email, text }` and `var sendWarning: String?` (single warning slot — the iOS sheet shows one active template; web split per-channel because it composes both at once). `private var sendArmed = false`.
  - `func evaluateGuardrails(_ channel: GuardrailChannel) async -> Bool` — returns `true` when the send may proceed. Logic (1:1 with web `passesSendGuardrails`):
    - `athleteUserId` nil → return `true` (can't check; don't block).
    - `try? checkSend(...)` with `programNote = authoredValues["programNote"]`; on nil result (thrown) → clear warning, return `true` (fail-open).
    - `programNoteReused` → set the block copy, return `false`.
    - `!sendArmed && (recentContact || messageCountToSchool >= 2)` → set the warn copy, `sendArmed = true`, return `false`.
    - else clear warning, return `true`.
  - `func logMessageSend(_ channel: GuardrailChannel) async` — best-effort `try? logSend(...)` with `templateSlug: selectedTemplate?.slug`, `channel: channel == .email ? "email" : "text"`, `programNote`/`updateHook` from `authoredValues`, `subject: channel == .email ? effectiveSubject : nil`, `body: effectiveBody`.
  - `selectTemplate` also resets `sendWarning = nil; sendArmed = false`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../QuickCommunicationGuardrailTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationGuardrailTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func vm(_ stub: GuardStubMessages) -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: GuardStubTemplates(),
      athleteMessagesService: stub)
    v.configureContext(loggedBy: "u1", familyUnitId: "f1", athleteUserId: "a1", accessToken: "tok")
    return v
  }

  func test_programNoteReused_hardBlocks() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: true, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 0)))
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertFalse(ok)
    XCTAssertNotNil(v.sendWarning)
  }

  func test_recentContact_armsThenProceeds() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: 2, recentContact: true, messageCountToSchool: 1)))
    let first = await v.evaluateGuardrails(.email)
    XCTAssertFalse(first, "first tap arms + warns")
    XCTAssertNotNil(v.sendWarning)
    let second = await v.evaluateGuardrails(.email)
    XCTAssertTrue(second, "second tap proceeds")
  }

  func test_checkThrows_failsOpen() async {
    let v = vm(GuardStubMessages(result: nil, error: AthleteMessagesError.server(500)))
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertTrue(ok)
  }

  func test_noAthlete_doesNotBlock() async {
    let v = QuickCommunicationViewModel(coach: coach(), templatesService: GuardStubTemplates(),
      athleteMessagesService: GuardStubMessages(result: .init(
        programNoteReused: true, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 9)))
    // no configureContext → athleteUserId nil
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertTrue(ok)
  }

  func test_selectTemplateResetsWarnAndArm() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: 2, recentContact: true, messageCountToSchool: 1)))
    _ = await v.evaluateGuardrails(.email)   // arms
    v.selectTemplate(nil)
    XCTAssertNil(v.sendWarning)
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertFalse(ok, "arm was reset → warns again, not proceed")
  }
}

private struct GuardStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct GuardStubMessages: AthleteMessagesServicing {
  var result: SendCheckResult?
  var error: Error?
  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult {
    if let error { throw error }
    return result!
  }
  func logSend(_ input: LogMessageInput, accessToken: String?) async throws {}
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/QuickCommunicationGuardrailTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation** — in `QuickCommunicationViewModel.swift`:

Dependency + token + state:
```swift
  private let athleteMessagesService: any AthleteMessagesServicing
  // init param: athleteMessagesService: (any AthleteMessagesServicing)? = nil,
  // init body:  self.athleteMessagesService = athleteMessagesService ?? AthleteMessagesServiceImpl()
  private var accessToken: String?
  enum GuardrailChannel { case email, text }
  var sendWarning: String?
  private var sendArmed = false
```

Extend `configureContext` with `accessToken`:
```swift
  func configureContext(loggedBy: String?, familyUnitId: String?,
                        athleteUserId: String? = nil, accessToken: String? = nil) {
    self.loggedBy = loggedBy
    self.familyUnitId = familyUnitId
    self.athleteUserId = athleteUserId
    self.accessToken = accessToken
  }
```

Guardrail eval + log (port of `passesSendGuardrails` / `logSentMessage`):
```swift
  func evaluateGuardrails(_ channel: GuardrailChannel) async -> Bool {
    guard let athleteUserId else { return true }        // can't check; don't block
    guard let check = try? await athleteMessagesService.checkSend(
      SendCheckInput(athleteUserId: athleteUserId, schoolId: coach.schoolId,
                     programNote: authoredValues["programNote"]),
      accessToken: accessToken) else {
      sendWarning = nil
      return true                                        // fail-open
    }
    if check.programNoteReused {
      sendWarning = String(localized: "Your reason for reaching out was already sent to another "
        + "program. Coaches notice reused messages — make it specific to this program before sending.")
      return false
    }
    if !sendArmed && (check.recentContact || check.messageCountToSchool >= 2) {
      sendWarning = check.recentContact
        ? String(localized: "You last messaged this program "
            + "\(check.daysSinceLastContact ?? 0) day(s) ago. Tap Send again to send anyway.")
        : String(localized: "You've already sent \(check.messageCountToSchool) messages here — "
            + "consider adding more programs. Tap Send again to send anyway.")
      sendArmed = true
      return false
    }
    sendWarning = nil
    return true
  }

  func logMessageSend(_ channel: GuardrailChannel) async {
    guard let athleteUserId else { return }
    try? await athleteMessagesService.logSend(LogMessageInput(
      athleteUserId: athleteUserId, schoolId: coach.schoolId, coachId: coach.id,
      templateSlug: selectedTemplate?.slug, channel: channel == .email ? "email" : "text",
      programNote: authoredValues["programNote"], updateHook: authoredValues["updateHook"],
      subject: channel == .email ? effectiveSubject : nil, body: effectiveBody),
      accessToken: accessToken)
  }
```

Reset on template change (extend `selectTemplate`, which already clears `editedSubject`/`editedBody`):
```swift
    sendWarning = nil
    sendArmed = false
```

- [ ] **Step 4: Run test + regression** — Step 2 command, then re-run `QuickCommunicationPanelTests`, `QuickCommunicationWindowTests`, `QuickCommunicationViewModelTests`. Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift \
  TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationGuardrailTests.swift
git commit -m "feat(coaches): guardrail block/two-step confirm + API send-logging (fail-open)"
```

---

### Task 6: View — guardrail gate on send, warning display, Instagram button

Wire the async guardrail check ahead of opening the composer, show `sendWarning`, and add an Instagram open-profile button. SwiftUI composition on Tasks 4–5; no new logic.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift`

**Interfaces:**
- Consumes: `viewModel.evaluateGuardrails(_:)`, `viewModel.logMessageSend(_:)`, `viewModel.sendWarning`, `viewModel.configureContext(...accessToken:)`, `coach.contactInstagram`; `authManager.session?.accessToken`.

- [ ] **Step 1: Pass the access token** — in the `.task` block, extend the existing `configureContext` call with `accessToken: authManager.session?.accessToken`.

- [ ] **Step 2: Gate email send on guardrails** — change `handleSendEmail` to run the check first (it becomes async work; wrap in a `Task`). The existing body opens the composer / `mailto:` fallback — keep that, but only after guardrails pass:

```swift
  private func handleSendEmail() {
    Task {
      guard await viewModel.evaluateGuardrails(.email) else { return }  // blocked or armed → stop
      if MFMailComposeViewController.canSendMail() {
        activeComposer = .mail
      } else if let url = viewModel.mailtoURL() {
        openURL(url)
        infoMessage = String(localized: "Log it from Interactions once sent.")
        showInfoToast = true
      }
    }
  }
```
Do the same for `handleSendText` with `.text` and the `sms:` branch.

- [ ] **Step 3: Log to the API on confirmed send** — in `handleMailResult` (which already fires only on `.sent`), add the API log next to the existing interaction log:
```swift
  private func handleMailResult(_ result: MFMailComposeResult) {
    guard result == .sent else { return }
    Task {
      await viewModel.logMessageSend(.email)   // best-effort API log (Phase 3)
      await viewModel.logSend(.email)          // existing interaction log
      if viewModel.didLogSend { showSuccessToast = true }
    }
  }
```
Mirror in `handleMessageResult` with `.text`.

- [ ] **Step 4: Show the warning** — under the unresolved-tokens notice (or replacing nothing), render `viewModel.sendWarning` when non-nil:
```swift
          if let warning = viewModel.sendWarning {
            Text(warning)
              .font(.caption)
              .foregroundStyle(Color.warningOrange)
              .accessibilityIdentifier("quickCommSendWarning")
          }
```

- [ ] **Step 5: Instagram button** — add to `QuickCommActionsSection` (pass `instagramHandle: context.coach.contactInstagram` in from the parent). When non-nil, a `.bordered` button that opens the profile; strip a leading `@`:
```swift
      if let handle = instagramHandle {
        Button {
          let clean = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
          if let url = URL(string: "https://instagram.com/\(clean)") { onOpenInstagram(url) }
        } label: {
          Label("Open Instagram", systemImage: "camera.fill")
            .font(.body.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Open Instagram profile @\(handle)"))
      }
```
Add `let instagramHandle: String?` and `let onOpenInstagram: (URL) -> Void` to `QuickCommActionsSection`; wire `onOpenInstagram: { openURL($0) }` at the call site. The IG button sits OUTSIDE the `.disabled(viewModel.isSendBlocked)` gate — opening a profile isn't a send, so it stays enabled regardless of token gating. (Restructure: move the IG button into its own row below the disabled email/text group, or apply `.disabled` only to the email/text buttons.)

- [ ] **Step 6: Build + regression** — boot sim, `xcodebuild build ... -quiet`, then run `QuickCommunicationPanelTests`, `QuickCommunicationWindowTests`, `QuickCommunicationGuardrailTests`, `QuickCommunicationViewModelTests`, `ContactWindowTests`, `ContactWindowServiceTests`, `AthleteMessagesServiceTests`. Expected: build clean; all PASS.

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift
git commit -m "feat(coaches): gate send on guardrails, show warning, add Instagram button"
```

---

### Task 7: Build + full regression + manual verification

- [ ] **Step 1: SwiftLint** — from repo root: `swiftlint lint --config .swiftlint.yml <all files created/modified in Tasks 1-6>`. Expected: 0 violations (fix any line_length ≤ 120).

- [ ] **Step 2: Full feature regression** — run every Coaches + CommunicationTemplates test class (boot sim first; use the array-args form — zsh does not word-split unquoted vars):
```bash
cd TheRecruitingCompass
CLASSES=(ContactWindowTests ContactWindowServiceTests AthleteMessagesServiceTests \
  QuickCommunicationWindowTests QuickCommunicationGuardrailTests QuickCommunicationPanelTests \
  QuickCommunicationResolveTests QuickCommunicationViewModelTests \
  TemplateVariableExtractorTests UnresolvedTokenHighlighterTests \
  CommunicationTemplatesViewModelTests CommunicationTemplatesAccessibilityTests \
  CommunicationTemplateDecodeTests TemplateResolverTests TemplateContextBuilderTests \
  TemplateMetricsTests TemplateEventsTests TemplateComputedScalarTests)
ARGS=(); for c in $CLASSES; do ARGS+=(-only-testing:TheRecruitingCompassTests/$c); done
xcodebuild test -scheme TheRecruitingCompass -destination 'id=78D62A71-539B-4C5F-8F22-671FC51CD819' "${ARGS[@]}"
```
Trust the exit code.

- [ ] **Step 3: Manual — contact-window swap.** Launch as an athlete whose school is **D1 baseball** with a `gradYear` far enough out to be `pre` (e.g. a freshman). Open Quick Communication → confirm the intro list shows the **pre-window** intro (not the standard "any" one). Repeat for a **D3** school (unrestricted → `open`) → standard intro shown, no pre variant.

- [ ] **Step 4: Manual — guardrails.** As an athlete, send an intro to a coach, then immediately start a second send to the same program: expect the two-step warn ("Tap Send again…"), then a second tap proceeds. Reuse the same `programNote` reason toward a different program → expect the hard block (send does not proceed, block copy shown). Kill `API_BASE_URL` (unset in scheme) → confirm sends still work (fail-open, no warning).

- [ ] **Step 5: Manual — Instagram.** A coach with an `instagram_handle` shows the "Open Instagram" button; tapping opens `instagram.com/{handle}`. A coach without one shows no button. The IG button is tappable even while send is token-gated.

- [ ] **Step 6: Done** — report results; hand off to `finishing-a-development-branch`.

---

## Self-Review

**Spec coverage (§6 Phase 3):**
- Contact-window pre/open eval + silent swap → Tasks 1 (`evaluate`/`filterByWindow`) + 2 (rules load) + 3 (VM `emailTemplates`/`textTemplates`). ✅
- `AthleteMessagesService` (`/check` + log) → Task 4. ✅
- Two-step confirm + hard block UX → Task 5 (VM `evaluateGuardrails`) + Task 6 (view gate + warning). ✅
- Fail-open everywhere → Task 1 (missing rule/config), Task 2 (fetch error → []), Task 5 (checkSend throw → proceed; no athlete → proceed). ✅
- Instagram open-profile button → Task 6 Step 5. ✅
- Tests: window eval (pre/open/fail-open) Task 1; swap grouping Task 1+3; guardrail confirm/block/fail-open Task 5. ✅

**Deferred / not-in-scope (per §6):** no social composer (IG button only); no DB migration (all prod-applied); Phase-2 token gate unchanged.

**Placeholder scan:** Tasks 1, 4, 5 carry full ported code + tests. Tasks 2, 3, 6 reference exact sibling files to mirror (`TemplateVariablesServiceImpl`, `PublicProfileServiceImpl`, existing `handleSend*`) with the specific query/columns/signatures named — the two "verify at impl time" notes (`parseWindowDate` slicing; ephemeral-session CSRF cookie) are toolchain confirmations, not logic gaps.

**Type consistency:** `ContactWindowRule`/`ContactWindowState`/`ContactWindowInput`/`ContactWindowResult` identical across Tasks 1/2/3; `ContactWindowServicing.fetchRules` identical Tasks 2/3; `SendCheckResult`/`SendCheckInput`/`LogMessageInput`/`AthleteMessagesServicing` identical Tasks 4/5; `evaluateGuardrails`/`logMessageSend`/`sendWarning`/`GuardrailChannel`/`configureContext(...accessToken:)` identical Tasks 5/6. `filterByWindow` group key `"\(type.rawValue):\(stage ?? "")"` matches the web `"${type}:${stage}"`.

**Regression guard:** `emailTemplates`/`textTemplates` gain a `.open`-state pass-through filter — templates with no `contact_window` (or `"any"` with no `pre` sibling) are unaffected, so `QuickCommunicationViewModelTests` (which sets no `contact_window`) stays green. `configureContext` gains a defaulted `accessToken` param — existing 3-arg callers/tests still compile. `selectTemplate` gains two resets alongside the Phase-2b `editedSubject`/`editedBody` clears — behavior-compatible.
