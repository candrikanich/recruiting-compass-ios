# Quick Communication Template Parity — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all 34 predefined coach-outreach templates appear in the iOS Quick Communication sheet by fixing the `TemplateType` decode failure and aligning the model + fetch with the shared DB schema.

**Architecture:** The templates already exist in the DB and RLS already grants read. The sheet is empty only because `TemplateType` (`email`/`text`/`twitter`) can't decode DB values (`email`/`message`/`social`), throwing the whole array decode. Phase 1: make `TemplateType` decode fail-soft + DB-aligned, add the new (optional) template columns, scope the fetch like web, and land the pure `TemplateResolver` foundation. No new UI in this phase — the existing two-bucket picker just fills.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Supabase Swift SDK, MVVM (`@Observable @MainActor` VMs; `Sendable` protocol services).

**Spec:** `planning/2026-08-13-ios-quick-comm-template-parity-spec.md`

## Global Constraints

- Build/test from `TheRecruitingCompass/` (Xcode wrapper): `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17'`. Trust xcodebuild exit code, not a grep.
- Source path is double-nested: `TheRecruitingCompass/TheRecruitingCompass/...`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/...`.
- New `.swift` files auto-included (`PBXFileSystemSynchronizedRootGroup`) — never edit `.xcodeproj` / run `add_files_to_xcode.rb`.
- Line length ≤ 120 (SwiftLint). Run `swiftlint --config .swiftlint.yml` (bare invocation gives false errors).
- Every `@MainActor` class needs `nonisolated deinit {}` (macOS 26 teardown). N/A to structs/enums.
- Fail **open**: a fetch/decode problem yields an empty or degraded list, never a crash or blocked outreach.
- NEVER commit `Core/Services/SupabaseConfig.generated.swift` (regenerates every build) or `Core/Localizable.xcstrings` unless it's this work's own change.

---

### Task 1: `TemplateType` — DB-aligned cases + fail-soft decode

Aligns the enum with DB values (`email`/`message`/`social`), maps legacy iOS rows (`text`/`twitter`), and adds `.unknown` so no single row can throw the array decode. Adds `selectable` (excludes `.unknown`) for UI.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateType.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateTypeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum TemplateType: String, Codable, CaseIterable, Sendable { case email, message, social, unknown }`
  - `init(from decoder:)` never throws — unknown strings → `.unknown`.
  - `static var selectable: [TemplateType]` → `[.email, .message, .social]`.
  - `var displayName: String`, `var color: Color` (defined for all four cases).

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateTypeTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateTypeTests: XCTestCase {
  private func decode(_ raw: String) throws -> TemplateType {
    try JSONDecoder().decode(TemplateType.self, from: Data("\"\(raw)\"".utf8))
  }

  func test_decodesDBValues() throws {
    XCTAssertEqual(try decode("email"), .email)
    XCTAssertEqual(try decode("message"), .message)
    XCTAssertEqual(try decode("social"), .social)
  }

  func test_mapsLegacyIOSValues() throws {
    XCTAssertEqual(try decode("text"), .message)
    XCTAssertEqual(try decode("twitter"), .social)
  }

  func test_unknownStringDecodesToUnknown_neverThrows() throws {
    XCTAssertEqual(try decode("phone_script"), .unknown)
    XCTAssertEqual(try decode("garbage"), .unknown)
  }

  func test_selectableExcludesUnknown() {
    XCTAssertEqual(TemplateType.selectable, [.email, .message, .social])
    XCTAssertFalse(TemplateType.selectable.contains(.unknown))
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/TemplateTypeTests`
Expected: FAIL — `.message`/`.social`/`.unknown`/`selectable` don't exist; `"text"` decodes to `.text`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/TemplateType.swift
import SwiftUI

enum TemplateType: String, Codable, CaseIterable, Sendable {
  case email
  case message
  case social
  case unknown

  /// Types offered in pickers/filters. Excludes `.unknown` (decode-only fallback).
  static var selectable: [TemplateType] { [.email, .message, .social] }

  /// Fail-soft decode: DB uses email/message/social; legacy iOS rows used text/twitter.
  /// Any unrecognized string becomes `.unknown` so one bad row can't throw the array decode.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "email": self = .email
    case "message", "text": self = .message
    case "social", "twitter": self = .social
    default: self = .unknown
    }
  }

  var displayName: String {
    switch self {
    case .email: return String(localized: "Email")
    case .message: return String(localized: "Text")
    case .social: return String(localized: "Social")
    case .unknown: return String(localized: "Other")
    }
  }

  var color: Color {
    switch self {
    case .email: return .accentBlue
    case .message: return .successGreen
    case .social: return .cyan
    case .unknown: return .gray
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateType.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateTypeTests.swift
git commit -m "fix(templates): align TemplateType with DB (email/message/social) + fail-soft decode"
```

---

### Task 2: Update `TemplateType` consumers (`.text`→`.message`, `allCases`→`selectable`)

The old cases are referenced in four places. Rename `.text`→`.message` and switch UI iteration from `allCases` (now includes `.unknown`) to `selectable`. `SendChannel`/`logSend` in the ViewModel are a SEPARATE enum mapping to `InteractionType` — leave them untouched.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift:78-80`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/ViewModels/CommunicationTemplatesViewModel.swift:59-64`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/CommunicationTemplatesView.swift:111`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/TemplateEditorView.swift:53`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplatesViewModelTypeCountsTests.swift`

**Interfaces:**
- Consumes: `TemplateType.selectable`, `.message` (Task 1).
- Produces: `QuickCommunicationViewModel.textTemplates` now filters `.message`; `typeCounts` keyed over `.selectable`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplatesViewModelTypeCountsTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CommunicationTemplatesViewModelTypeCountsTests: XCTestCase {
  private func template(id: String, type: TemplateType) -> CommunicationTemplate {
    CommunicationTemplate(id: id, userId: "u", name: "n", type: type, body: "b",
                          variables: nil, createdAt: "", updatedAt: "")
  }

  func test_typeCountsCoverSelectableOnly() {
    let vm = CommunicationTemplatesViewModel()
    vm.templates = [
      template(id: "1", type: .email),
      template(id: "2", type: .message),
      template(id: "3", type: .social),
      template(id: "4", type: .unknown)
    ]
    XCTAssertEqual(vm.typeCounts[.email], 1)
    XCTAssertEqual(vm.typeCounts[.message], 1)
    XCTAssertEqual(vm.typeCounts[.social], 1)
    XCTAssertNil(vm.typeCounts[.unknown], "unknown must not get a filter pill")
    XCTAssertEqual(vm.typeCounts[nil], 4, "All-count includes every template")
  }
}
```

> If `CommunicationTemplatesViewModel()` requires a service arg, pass the existing mock/default the codebase uses (check the file's `init`); the assertion set is what matters.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CommunicationTemplatesViewModelTypeCountsTests`
Expected: FAIL to COMPILE (`.message` unused yet in VM) or FAIL asserting `typeCounts[.unknown]` is non-nil (allCases includes `.unknown`).

- [ ] **Step 3: Write minimal implementation**

`QuickCommunicationViewModel.swift` (lines 78-80):

```swift
  var textTemplates: [CommunicationTemplate] {
    templates.filter { $0.type == .message }
  }
```

`CommunicationTemplatesViewModel.swift` (lines 59-64):

```swift
  var typeCounts: [TemplateType?: Int] {
    var counts: [TemplateType?: Int] = [nil: templates.count]
    for type in TemplateType.selectable {
      counts[type] = templates.count(where: { $0.type == type })
    }
    return counts
  }
```

`CommunicationTemplatesView.swift` (line 111):

```swift
        ForEach(TemplateType.selectable, id: \.self) { type in
```

`TemplateEditorView.swift` (line 53):

```swift
        ForEach(TemplateType.selectable, id: \.self) { type in
```

- [ ] **Step 4: Run tests + build to verify pass**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` then the test command from Step 2.
Expected: build succeeds (no remaining `.text`/`.twitter`/`allCases` template refs); test PASSES. Sanity: `grep -rn '\.type == \.text\|TemplateType\.allCases' TheRecruitingCompass/TheRecruitingCompass/Features` returns nothing.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/ViewModels/CommunicationTemplatesViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/CommunicationTemplatesView.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Views/TemplateEditorView.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplatesViewModelTypeCountsTests.swift
git commit -m "refactor(templates): migrate TemplateType consumers to message case + selectable list"
```

---

### Task 3: Extend `CommunicationTemplate` model with the new DB columns

Add the Phase-0 columns (all optional/defaulted) so web rows decode fully and are available to later phases. Back-compat: legacy rows without these keys still decode.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/CommunicationTemplate.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplateDecodeTests.swift`

**Interfaces:**
- Consumes: `TemplateType` (Task 1).
- Produces: `CommunicationTemplate` gains `subject: String?`, `slug: String?`, `stage: String?`, `contactWindow: String?`, `requiredVariables: [String]?`, `sortOrder: Int?`, `isPredefined: Bool?`. Memberwise `init` gains these with defaults `= nil`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplateDecodeTests.swift
import XCTest
@testable import TheRecruitingCompass

final class CommunicationTemplateDecodeTests: XCTestCase {
  func test_decodesFullWebRow() throws {
    let json = """
    {"id":"t1","user_id":null,"name":"First contact","type":"email",
     "subject":"{{gradYear}} {{position}}","body":"{{coachSalutation}},",
     "slug":"intro-standard","stage":"intro","contact_window":"any",
     "required_variables":["programNote"],"sort_order":10,"is_predefined":true,
     "created_at":"2026-08-16T00:00:00Z","updated_at":"2026-08-16T00:00:00Z"}
    """
    let t = try JSONDecoder().decode(CommunicationTemplate.self, from: Data(json.utf8))
    XCTAssertEqual(t.type, .email)
    XCTAssertEqual(t.subject, "{{gradYear}} {{position}}")
    XCTAssertEqual(t.slug, "intro-standard")
    XCTAssertEqual(t.stage, "intro")
    XCTAssertEqual(t.contactWindow, "any")
    XCTAssertEqual(t.requiredVariables, ["programNote"])
    XCTAssertEqual(t.sortOrder, 10)
    XCTAssertEqual(t.isPredefined, true)
    XCTAssertEqual(t.userId, "", "null user_id maps to empty string")
  }

  func test_decodesLegacyMinimalRow_noNewKeys() throws {
    let json = """
    {"id":"t2","user_id":"u9","name":"My template","type":"message","body":"hi",
     "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
    """
    let t = try JSONDecoder().decode(CommunicationTemplate.self, from: Data(json.utf8))
    XCTAssertEqual(t.type, .message)
    XCTAssertNil(t.subject)
    XCTAssertNil(t.slug)
    XCTAssertNil(t.requiredVariables)
    XCTAssertNil(t.isPredefined)
  }

  func test_arrayWithMixedTypesDoesNotThrow() throws {
    let json = """
    [{"id":"a","name":"e","type":"email","body":"b","created_at":"","updated_at":""},
     {"id":"b","name":"m","type":"social","body":"b","created_at":"","updated_at":""},
     {"id":"c","name":"x","type":"phone_script","body":"b","created_at":"","updated_at":""}]
    """
    let list = try JSONDecoder().decode([CommunicationTemplate].self, from: Data(json.utf8))
    XCTAssertEqual(list.count, 3)
    XCTAssertEqual(list.map(\.type), [.email, .social, .unknown])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CommunicationTemplateDecodeTests`
Expected: FAIL to COMPILE — `subject`/`slug`/`stage`/`contactWindow`/`requiredVariables`/`sortOrder`/`isPredefined` don't exist.

- [ ] **Step 3: Write minimal implementation**

In `CommunicationTemplate.swift` add the stored properties (after `variables`):

```swift
  let variables: [String]?
  let subject: String?
  let slug: String?
  let stage: String?
  let contactWindow: String?
  let requiredVariables: [String]?
  let sortOrder: Int?
  let isPredefined: Bool?
```

Extend the memberwise `init` (append params with defaults so existing call sites/tests keep compiling):

```swift
  init(id: String, userId: String, name: String, type: TemplateType, body: String,
       variables: [String]?, createdAt: String, updatedAt: String,
       subject: String? = nil, slug: String? = nil, stage: String? = nil,
       contactWindow: String? = nil, requiredVariables: [String]? = nil,
       sortOrder: Int? = nil, isPredefined: Bool? = nil) {
    self.id = id
    self.userId = userId
    self.name = name
    self.type = type
    self.body = body
    self.variables = variables
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.subject = subject
    self.slug = slug
    self.stage = stage
    self.contactWindow = contactWindow
    self.requiredVariables = requiredVariables
    self.sortOrder = sortOrder
    self.isPredefined = isPredefined
  }
```

Extend `init(from decoder:)` (after the `variables` line):

```swift
    variables = try c.decodeIfPresent([String].self, forKey: .variables)
    subject = try c.decodeIfPresent(String.self, forKey: .subject)
    slug = try c.decodeIfPresent(String.self, forKey: .slug)
    stage = try c.decodeIfPresent(String.self, forKey: .stage)
    contactWindow = try c.decodeIfPresent(String.self, forKey: .contactWindow)
    requiredVariables = try c.decodeIfPresent([String].self, forKey: .requiredVariables)
    sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
    isPredefined = try c.decodeIfPresent(Bool.self, forKey: .isPredefined)
```

Extend `encode(to:)` (after the `variables` line):

```swift
    try c.encodeIfPresent(variables, forKey: .variables)
    try c.encodeIfPresent(subject, forKey: .subject)
    try c.encodeIfPresent(slug, forKey: .slug)
    try c.encodeIfPresent(stage, forKey: .stage)
    try c.encodeIfPresent(contactWindow, forKey: .contactWindow)
    try c.encodeIfPresent(requiredVariables, forKey: .requiredVariables)
    try c.encodeIfPresent(sortOrder, forKey: .sortOrder)
    try c.encodeIfPresent(isPredefined, forKey: .isPredefined)
```

Extend `CodingKeys`:

```swift
  enum CodingKeys: String, CodingKey {
    case id, name, type, body, variables, subject, slug, stage
    case userId = "user_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case contactWindow = "contact_window"
    case requiredVariables = "required_variables"
    case sortOrder = "sort_order"
    case isPredefined = "is_predefined"
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2, then `xcodebuild build ... -quiet`.
Expected: 3 tests PASS; whole app still builds (memberwise `init` defaults keep existing call sites — e.g. the `#Preview` in `QuickCommunicationView.swift` and any mocks — compiling).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/CommunicationTemplate.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/CommunicationTemplateDecodeTests.swift
git commit -m "feat(templates): add Phase-0 columns (subject/slug/stage/contact_window/...) to CommunicationTemplate"
```

---

### Task 4: Scope `fetchTemplates` like web + fail-soft on missing table

Match the web query (`user_id.eq.<uid>` OR `is_predefined.eq.true`) and degrade to `[]` when the table is absent (`PGRST205`), instead of throwing. The error classifier is a pure, unit-tested free function; the live query is verified by build + manual check.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/CommunicationTemplatesService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/MissingTableErrorTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `func isMissingTableError(_ error: Error) -> Bool` (file-scope helper in the service file). `fetchTemplates()` returns `[]` when it's true.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/MissingTableErrorTests.swift
import XCTest
@testable import TheRecruitingCompass

final class MissingTableErrorTests: XCTestCase {
  private struct StubError: LocalizedError {
    let msg: String
    var errorDescription: String? { msg }
  }

  func test_pgrst205IsMissingTable() {
    XCTAssertTrue(isMissingTableError(StubError(msg: "PGRST205: Could not find the table")))
  }

  func test_tableDoesNotExistIsMissingTable() {
    XCTAssertTrue(isMissingTableError(
      StubError(msg: "relation \"public.communication_templates\" does not exist")))
  }

  func test_unrelatedErrorIsNotMissingTable() {
    XCTAssertFalse(isMissingTableError(StubError(msg: "network timeout")))
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/MissingTableErrorTests`
Expected: FAIL to COMPILE — `isMissingTableError` undefined.

- [ ] **Step 3: Write minimal implementation**

Add the file-scope helper near the top of `CommunicationTemplatesService.swift` (after the `logger`):

```swift
/// True when an error indicates the templates table is absent (feature-flag-off tolerance).
/// Web returns [] on PGRST205; mirror that so an un-migrated backend degrades, not crashes.
func isMissingTableError(_ error: Error) -> Bool {
  let text = error.localizedDescription.lowercased()
  return text.contains("pgrst205")
    || (text.contains("communication_templates") && text.contains("does not exist"))
}
```

Rewrite `fetchTemplates()` to scope by uid + fail soft:

```swift
  func fetchTemplates() async throws -> [CommunicationTemplate] {
    logger.debug("Fetching communication templates")
    do {
      let userId = (try? await supabaseManager.client.auth.session.user.id.uuidString) ?? ""
      let orFilter = userId.isEmpty
        ? "is_predefined.eq.true"
        : "user_id.eq.\(userId),is_predefined.eq.true"
      let templates: [CommunicationTemplate] = try await supabaseManager.client
        .from("communication_templates")
        .select()
        .or(orFilter)
        .order("updated_at", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(templates.count) templates")
      return templates
    } catch {
      if isMissingTableError(error) {
        logger.warning("communication_templates table absent; returning [] (fail-soft)")
        return []
      }
      logger.error("fetchTemplates failed: \(error.localizedDescription)")
      throw error
    }
  }
```

- [ ] **Step 4: Run test + build to verify pass**

Run: test command from Step 2, then `xcodebuild build ... -quiet`.
Expected: 3 tests PASS; app builds. (The `.or(_:)` and `.auth.session` APIs already exist in the SDK — `createTemplate` uses `auth.session`; other services use `.or`.)

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Services/CommunicationTemplatesService.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/MissingTableErrorTests.swift
git commit -m "feat(templates): scope fetch to own+predefined and fail-soft on missing table"
```

---

### Task 5: `TemplateResolver` pure struct (render + findUnresolved)

Land the web-faithful pure resolver as Phase 2's foundation: fill known `{{key}}` tokens, leave unknown tokens intact (so Phase 2 can gate on them). Independently unit-tested; not yet wired into the live sheet (the sheet keeps its current 4-var fill until Phase 2).

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `static func render(_ body: String, values: [String: String]) -> String`
  - `static func findUnresolved(_ text: String) -> [String]` (deduped, in first-seen order)

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateResolverTests: XCTestCase {
  func test_fillsKnownTokens() {
    let out = TemplateResolver.render("Hi {{coachName}} at {{schoolName}}",
                                      values: ["coachName": "Smith", "schoolName": "Wooster"])
    XCTAssertEqual(out, "Hi Smith at Wooster")
  }

  func test_leavesUnknownTokensIntact() {
    let out = TemplateResolver.render("Hi {{coachName}}, {{programNote}}",
                                      values: ["coachName": "Smith"])
    XCTAssertEqual(out, "Hi Smith, {{programNote}}")
  }

  func test_findUnresolvedReturnsRemainingKeysDeduped() {
    let text = "{{programNote}} and {{updateHook}} and {{programNote}}"
    XCTAssertEqual(TemplateResolver.findUnresolved(text), ["programNote", "updateHook"])
  }

  func test_findUnresolvedEmptyWhenAllResolved() {
    XCTAssertEqual(TemplateResolver.findUnresolved("no tokens here"), [])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/TemplateResolverTests`
Expected: FAIL to COMPILE — `TemplateResolver` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/TemplateResolver.swift
import Foundation

/// Pure `{{key}}` template renderer, ported from web `utils/templateResolver.ts`.
/// Known keys are substituted; unknown keys are left intact so callers can gate on them.
enum TemplateResolver {
  private static let tokenPattern = #"\{\{(\w+)\}\}"#

  static func render(_ body: String, values: [String: String]) -> String {
    guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return body }
    var result = body
    let full = NSRange(body.startIndex..., in: body)
    // Replace right-to-left so each replacement never shifts an as-yet-unprocessed range.
    for match in regex.matches(in: body, range: full).reversed() {
      guard let matchRange = Range(match.range, in: result),
            let keyRange = Range(match.range(at: 1), in: result) else { continue }
      let key = String(result[keyRange])
      if let value = values[key] {
        result.replaceSubrange(matchRange, with: value)
      }
    }
    return result
  }

  static func findUnresolved(_ text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return [] }
    var seen = Set<String>()
    var keys: [String] = []
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
      let key = String(text[keyRange])
      if seen.insert(key).inserted { keys.append(key) }
    }
    return keys
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateResolver.swift \
  TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateResolverTests.swift
git commit -m "feat(templates): add pure TemplateResolver (render + findUnresolved) foundation"
```

> Note the second path is repo-root-relative; use the full double-nested path when staging: `TheRecruitingCompass/TheRecruitingCompassTests/...`.

---

### Task 6: Manual verification — the sheet fills

No code. Confirm the bug is dead end-to-end.

- [ ] **Step 1: Build + launch on iPhone 17 sim**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`; launch the app (signed-in user with at least one coach that has an email).

- [ ] **Step 2: Open Quick Communication**

Tap a coach's email (from `CoachCardView`, `CoachDetailView`, or the coaches list).
Expected: the "Use a template" section lists the email templates (25) and, under "Text templates", the message templates (7). No error toast. Selecting one fills the preview (with the current 4-var substitution; unresolved `{{tokens}}` remain visible — resolution lands in Phase 2).

- [ ] **Step 3: Regression run**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CommunicationTemplatesViewModelTests -only-testing:TheRecruitingCompassTests/QuickCommunicationViewModelTests` (whichever exist).
Expected: existing template/quick-comm tests still PASS. Trust the exit code.

- [ ] **Step 4: Commit (only if any doc/notes changed)**

No commit expected unless notes were updated.

---

## Self-Review

**Spec coverage (Phase 1 rows):** `TemplateType` fix → Task 1+2. Model new columns → Task 3. `fetchTemplates` `.or` + fail-soft → Task 4. `TemplateResolver` render/findUnresolved → Task 5. Sheet fills (exit criterion) → Task 6. Phase-1 "keep 4-var fill working" → preserved (sheet untouched; resolver not yet wired). ✅

**Deferred to later phases (not gaps):** variable registry/context/computed formatters, variables panel, token gating in the live sheet, contact-window, guardrails — all Phase 2/3 per spec §6.

**Placeholder scan:** every code step has real code; no TBD/"handle errors" hand-waves. ✅

**Type consistency:** `TemplateType` cases `email/message/social/unknown` + `selectable` used identically across Tasks 1-3; `CommunicationTemplate` new property names match between Task 3 definition and the Task 3 decode test; `isMissingTableError` name matches between Task 4 impl and test; `TemplateResolver.render`/`findUnresolved` signatures match between Task 5 impl and test. ✅

**Known integration caveat:** Task 2's test constructs `CommunicationTemplatesViewModel()` and Task 3's memberwise `init` is used by mocks/previews — if either has a required arg in the current code, pass the existing default; behavior asserted is unchanged.
