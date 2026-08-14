# Quick Communication Template Parity — Phase 2b (Variables Panel + Compose UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the athlete a variables panel to fill the authored `{{tokens}}` a template needs, highlight unresolved tokens amber in the live preview, allow editing the subject/body, and enforce the 160-char limit on text messages — turning Phase 2a's silent gate into a guided compose flow.

**Architecture:** Phase 2a already resolves a selected template to `resolvedSubject`/`resolvedBody`/`unresolvedKeys` and gates send on `isSendBlocked`. Phase 2b adds a pure `TemplateVariableExtractor` (which registry vars a template references, split authored-vs-profile-backed), surfaces them as an editable panel bound to `authoredValues`, adds `AttributedString` amber highlighting, and lets the user override subject/body. No new services or DB access — all built on 2a's engine.

**Tech Stack:** Swift 6, SwiftUI, XCTest, MVVM (`@Observable @MainActor` VM; pure structs for logic).

**Spec:** `planning/2026-08-13-ios-quick-comm-template-parity-spec.md` (§4.4 send gating, §4.6 compose flows, §5 Views)

**Prereq:** Phase 2a landed (commits `83f207a3`, `30188c0f`, `766a96a5`): `TemplateVariableDef`, `TemplateResolver.buildValues`, `ResolverContext`, `QuickCommunicationViewModel.{registry, resolvedContext, authoredValues, resolvedSubject, resolvedBody, unresolvedKeys, isSendBlocked, messageBody}`.

## Global Constraints

- Build/test from `TheRecruitingCompass/`: `xcodebuild test -scheme TheRecruitingCompass -destination 'id=78D62A71-539B-4C5F-8F22-671FC51CD819'` (iPhone 17 / iOS 26.5). **Boot the sim to `Booted` first** (`xcrun simctl boot <udid>`; verify `simctl list devices | grep Booted`) — CoreSimulatorService wedges on cold boot; if `xcodebuild` loops `build number "" incompatible with DVTBuildVersion`, kill it, `simctl shutdown all`, `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, re-boot. Use plain `xcodebuild test` (not `test-without-building` — it targets a stale clone bundle). Trust exit code.
- Every `@MainActor XCTestCase` needs `nonisolated deinit {}` (macOS 26 teardown double-free, else the whole run aborts with cases "passed" but TEST FAILED).
- Line length ≤ 120 (SwiftLint `--config .swiftlint.yml`).
- NEVER commit `Core/Services/SupabaseConfig.generated.swift` or `Core/Localizable.xcstrings`.
- **Fail-open:** panel/highlight problems degrade to plain preview; never block a legit send beyond the token gate.

### Scope boundaries (per spec)

- **In 2b:** variables panel (authored inputs + read-only resolved rows + empty-profile hint), amber unresolved highlight, editable subject/body, 160-char text counter, parent read-only gating for authored inputs.
- **NOT in 2b:** contact-window filter, guardrails/`/check`, Instagram button (all Phase 3). Real cross-modal deep-link into Settings→PlayerDetails is out — 2b shows a static "Complete in your profile" hint, not a navigation (fragile from a sheet; a polish follow-up).

---

### Task 1: `TemplateVariableExtractor` — which vars a template references

Pure function: given a template's subject+body and the registry, return the referenced variables in first-seen order, each tagged authored (user-fillable) vs profile-backed (resolved or missing).

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariableExtractor.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableExtractorTests.swift`

**Interfaces:**
- Consumes: `TemplateVariableDef`, `VariableSourceType`, `TemplateResolver.findUnresolved` (all Phase 2a).
- Produces:
  - `struct ReferencedVariable: Equatable, Identifiable { key,label,sourceType,isAuthored,isResolved,resolvedValue?; var id: String { key } }`
  - `enum TemplateVariableExtractor { static func referenced(subject:String?, body:String, registry:[TemplateVariableDef], resolvedValues:[String:String]) -> [ReferencedVariable] }`
  - `isAuthored == (sourceType == .authored)`; `isResolved == resolvedValues[key] != nil`; `resolvedValue == resolvedValues[key]`. Order = token first-seen across `subject + "\n" + body`. Tokens with no registry row are still returned (label = key, sourceType = `.unknown`, authored = false).

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../TemplateVariableExtractorTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableExtractorTests: XCTestCase {
  private func def(_ key: String, _ type: VariableSourceType, label: String = "") -> TemplateVariableDef {
    TemplateVariableDef(key: key, label: label.isEmpty ? key : label, category: "", sourceType: type)
  }

  func test_returnsReferencedVarsInFirstSeenOrderWithTags() {
    let registry = [
      def("coachSalutation", .computed, label: "Coach Salutation"),
      def("programNote", .authored, label: "Program Note"),
      def("schoolShortName", .computed)
    ]
    let vars = TemplateVariableExtractor.referenced(
      subject: "Hi {{coachSalutation}}",
      body: "{{programNote}} — go {{schoolShortName}}. {{programNote}} again.",
      registry: registry,
      resolvedValues: ["coachSalutation": "Coach Smith", "schoolShortName": "Duke"])
    XCTAssertEqual(vars.map(\.key), ["coachSalutation", "programNote", "schoolShortName"])
    XCTAssertEqual(vars[0].isResolved, true)
    XCTAssertEqual(vars[0].resolvedValue, "Coach Smith")
    XCTAssertEqual(vars[1].isAuthored, true)
    XCTAssertEqual(vars[1].isResolved, false)
    XCTAssertEqual(vars[1].label, "Program Note")
  }

  func test_unknownTokenReturnedWithKeyLabel() {
    let vars = TemplateVariableExtractor.referenced(
      subject: nil, body: "{{mysteryVar}}", registry: [], resolvedValues: [:])
    XCTAssertEqual(vars.map(\.key), ["mysteryVar"])
    XCTAssertEqual(vars[0].sourceType, .unknown)
    XCTAssertFalse(vars[0].isAuthored)
  }

  func test_noTokensEmpty() {
    XCTAssertTrue(TemplateVariableExtractor.referenced(
      subject: "plain", body: "no tokens", registry: [], resolvedValues: [:]).isEmpty)
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/TemplateVariableExtractorTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/TemplateVariableExtractor.swift
import Foundation

struct ReferencedVariable: Equatable, Identifiable {
  let key: String
  let label: String
  let sourceType: VariableSourceType
  let isAuthored: Bool
  let isResolved: Bool
  let resolvedValue: String?
  var id: String { key }
}

enum TemplateVariableExtractor {
  static func referenced(subject: String?, body: String,
                         registry: [TemplateVariableDef],
                         resolvedValues: [String: String]) -> [ReferencedVariable] {
    let text = [subject, body].compactMap { $0 }.joined(separator: "\n")
    let byKey = Dictionary(registry.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    return TemplateResolver.findUnresolved(text).map { key in   // deduped, first-seen order
      let def = byKey[key]
      return ReferencedVariable(
        key: key,
        label: def?.label.isEmpty == false ? def!.label : key,
        sourceType: def?.sourceType ?? .unknown,
        isAuthored: def?.sourceType == .authored,
        isResolved: resolvedValues[key] != nil,
        resolvedValue: resolvedValues[key])
    }
  }
}
```

> `findUnresolved` matches ALL `{{\w+}}` tokens (it doesn't skip resolved ones), so it doubles as "all referenced tokens." Confirm against the Phase-2a impl (it returns every token deduped, not only unresolved — the name is historical).

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: 3 PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariableExtractor.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableExtractorTests.swift
git commit -m "feat(templates): add TemplateVariableExtractor (referenced vars, authored/resolved tags)"
```

> **Verify first:** open `TemplateResolver.findUnresolved` — if it returns only *unresolved* tokens (post-substitution) rather than *all* tokens, add a sibling `allTokens(_:)` that lists every `{{\w+}}` deduped, and call that here instead. The panel must show resolved vars too, so it needs all tokens.

---

### Task 2: VM exposes the variable list + authored bindings + editable text

Surface the referenced variables for the selected template and let the view bind authored inputs and edited subject/body. Unresolved recomputes off the *edited* text.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationPanelTests.swift`

**Interfaces:**
- Consumes: `TemplateVariableExtractor` (Task 1), Phase-2a `resolvedValues()`/`resolvedSubject`/`resolvedBody`.
- Produces on `QuickCommunicationViewModel`:
  - `var editedSubject: String?` / `var editedBody: String?` — nil until the user edits; when set, override the resolved output for preview/send.
  - `var effectiveSubject: String` (= `editedSubject ?? resolvedSubject`), `var effectiveBody: String` (= `editedBody ?? resolvedBody`).
  - `var referencedVariables: [ReferencedVariable]` (from the selected template + current resolved values).
  - `func authoredBinding(for key: String) -> Binding<String>` — reads/writes `authoredValues[key]`.
  - `unresolvedKeys`/`isSendBlocked`/`messageBody` retargeted to `effectiveBody`+`effectiveSubject`.
  - `func selectTemplate(_:)` clears `editedSubject`/`editedBody` (fresh template → fresh text).
  - `var textBodyOverLimit: Bool` (= selected `.message` && `effectiveBody.count > 160`), `static let textLimit = 160`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../QuickCommunicationPanelTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationPanelTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func vm() async -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil, templatesService: PanelStubTemplates(),
      templateVariablesService: PanelStubRegistry(defs: [
        .init(key: "coachSalutation", label: "Coach Salutation", category: "", sourceType: .computed),
        .init(key: "programNote", label: "Program Note", category: "", sourceType: .authored)]),
      contextService: PanelStubContext(derived: ["coachSalutation": "Coach Smith"]))
    await v.loadResolverInputs()
    return v
  }

  func test_referencedVariablesAndAuthoredBinding() async {
    let v = await vm()
    v.selectTemplate(CommunicationTemplate(id: "t", userId: "", name: "n", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertEqual(v.referencedVariables.map(\.key), ["coachSalutation", "programNote"])
    XCTAssertTrue(v.isSendBlocked)

    v.authoredBinding(for: "programNote").wrappedValue = "loved the camp"
    XCTAssertEqual(v.effectiveBody, "Coach Smith, loved the camp")
    XCTAssertFalse(v.isSendBlocked)
    XCTAssertTrue(v.referencedVariables.first { $0.key == "programNote" }!.isResolved)
  }

  func test_editedBodyOverridesAndDrivesGate() async {
    let v = await vm()
    v.selectTemplate(CommunicationTemplate(id: "t", userId: "", name: "n", type: .message,
      body: "{{coachSalutation}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertEqual(v.effectiveBody, "Coach Smith")
    v.editedBody = String(repeating: "x", count: 161)
    XCTAssertTrue(v.textBodyOverLimit)
    XCTAssertTrue(v.unresolvedKeys.isEmpty, "edited text has no tokens")
  }

  func test_selectingTemplateClearsEdits() async {
    let v = await vm()
    v.editedBody = "stale"
    v.selectTemplate(CommunicationTemplate(id: "t2", userId: "", name: "n", type: .email,
      body: "{{coachSalutation}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertNil(v.editedBody)
    XCTAssertEqual(v.effectiveBody, "Coach Smith")
  }
}

private struct PanelStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct PanelStubRegistry: TemplateVariablesServicing {
  let defs: [TemplateVariableDef]
  func fetchRegistry() async throws -> [TemplateVariableDef] { defs }
}
private struct PanelStubContext: TemplateContextProviding {
  let derived: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: authored, derived: derived,
                    metrics: [], events: [], now: now)
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/QuickCommunicationPanelTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation** — in `QuickCommunicationViewModel.swift`:

Add state near `authoredValues`:
```swift
  var editedSubject: String?
  var editedBody: String?
  static let textLimit = 160
```

Retarget the resolved accessors (replace the Phase-2a `unresolvedKeys`/`isSendBlocked`; keep `resolvedSubject`/`resolvedBody` as the pure resolver output):
```swift
  var effectiveSubject: String { editedSubject ?? resolvedSubject }
  var effectiveBody: String { editedBody ?? resolvedBody }

  var referencedVariables: [ReferencedVariable] {
    guard let template = selectedTemplate else { return [] }
    return TemplateVariableExtractor.referenced(
      subject: template.subject, body: template.body,
      registry: registry, resolvedValues: resolvedValues())
  }

  func authoredBinding(for key: String) -> Binding<String> {
    Binding(get: { [weak self] in self?.authoredValues[key] ?? "" },
            set: { [weak self] in self?.authoredValues[key] = $0 })
  }

  var textBodyOverLimit: Bool {
    selectedTemplate?.type == .message && effectiveBody.count > Self.textLimit
  }
```

Update `unresolvedKeys`/`isSendBlocked`/`messageBody` to use effective text:
```swift
  var unresolvedKeys: [String] {
    guard !registry.isEmpty, selectedTemplate != nil else { return [] }
    return TemplateResolver.findUnresolved(effectiveSubject + "\n" + effectiveBody)
  }
  var isSendBlocked: Bool { !unresolvedKeys.isEmpty || textBodyOverLimit }
  var messageBody: String { registry.isEmpty ? filledBody : effectiveBody }
```

And in `selectTemplate`, reset edits:
```swift
  func selectTemplate(_ template: CommunicationTemplate?) {
    selectedTemplate = template
    editedSubject = nil
    editedBody = nil
  }
```

> `authoredBinding` uses `Binding` from SwiftUI — add `import SwiftUI` if not already present (it is; the VM imports SwiftUI). `Binding` capture of `self` on a `@MainActor @Observable` VM is safe for view bindings.

- [ ] **Step 4: Run test + build** — Step 2 command, then `xcodebuild build ... -quiet`, then re-run `QuickCommunicationResolveTests` + `QuickCommunicationViewModelTests` (Phase-2a/legacy regression). Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/QuickCommunicationViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/QuickCommunicationPanelTests.swift
git commit -m "feat(coaches): expose referenced variables + authored bindings + editable subject/body"
```

---

### Task 3: Amber highlight for unresolved tokens (pure `AttributedString`)

Pure helper that renders text with `{{token}}` spans styled amber/bold so the preview shows what's still missing.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/UnresolvedTokenHighlighter.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/UnresolvedTokenHighlighterTests.swift`

**Interfaces:**
- Produces: `enum UnresolvedTokenHighlighter { static func attributed(_ text:String, tokenColor:Color) -> AttributedString }` — every `{{\w+}}` run gets `foregroundColor = tokenColor` + `.bold`; the rest is default. (Unit test asserts on the substring ranges via the plain `String(attributed.characters)` round-trip + a run scan, not on Color rendering.)

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompassTests/.../UnresolvedTokenHighlighterTests.swift
import SwiftUI
import XCTest
@testable import TheRecruitingCompass

final class UnresolvedTokenHighlighterTests: XCTestCase {
  func test_plainTextRoundTripsUnchanged() {
    let a = UnresolvedTokenHighlighter.attributed("Hi Coach Smith", tokenColor: .orange)
    XCTAssertEqual(String(a.characters), "Hi Coach Smith")
  }

  func test_tokenRunsAreColored() {
    let a = UnresolvedTokenHighlighter.attributed("Hi {{programNote}} bye", tokenColor: .orange)
    XCTAssertEqual(String(a.characters), "Hi {{programNote}} bye")
    // Exactly one colored run, and it is the token substring.
    let colored = a.runs.filter { $0.foregroundColor == .orange }
    XCTAssertEqual(colored.count, 1)
    let coloredText = colored.map { String(a[$0.range].characters) }.joined()
    XCTAssertEqual(coloredText, "{{programNote}}")
  }

  func test_multipleTokens() {
    let a = UnresolvedTokenHighlighter.attributed("{{a}} x {{b}}", tokenColor: .orange)
    let colored = a.runs.filter { $0.foregroundColor == .orange }
                        .map { String(a[$0.range].characters) }
    XCTAssertEqual(colored, ["{{a}}", "{{b}}"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails** — `-only-testing:TheRecruitingCompassTests/UnresolvedTokenHighlighterTests`. Expected: FAIL to COMPILE.

- [ ] **Step 3: Write minimal implementation**

```swift
// Features/CommunicationTemplates/Models/UnresolvedTokenHighlighter.swift
import SwiftUI

enum UnresolvedTokenHighlighter {
  private static let pattern = #"\{\{\w+\}\}"#

  static func attributed(_ text: String, tokenColor: Color) -> AttributedString {
    var result = AttributedString(text)
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
    let ns = text as NSString
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      guard let swiftRange = Range(match.range, in: text),
            let lo = AttributedString.Index(swiftRange.lowerBound, within: result),
            let hi = AttributedString.Index(swiftRange.upperBound, within: result) else { continue }
      result[lo..<hi].foregroundColor = tokenColor
      result[lo..<hi].font = .body.bold()
    }
    return result
  }
}
```

> `AttributedString.Index(_:within:)` maps a `String.Index` into the attributed string (same backing characters). If the initializer signature differs on this toolchain, build the range by counting UTF-8 offsets from `result.startIndex`. Verify at implementation time.

- [ ] **Step 4: Run test to verify it passes** — same as Step 2. Expected: 3 PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/UnresolvedTokenHighlighter.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/UnresolvedTokenHighlighterTests.swift
git commit -m "feat(templates): add amber unresolved-token highlighter (AttributedString)"
```

---

### Task 4: Variables panel view + amber preview + editable fields + char counter

Wire the panel and edits into the sheet. Mostly SwiftUI composition on Tasks 1–3; no new logic.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift`

**Interfaces:**
- Consumes: `viewModel.referencedVariables`, `authoredBinding(for:)`, `effectiveSubject`/`effectiveBody`, `editedSubject`/`editedBody`, `textBodyOverLimit`, `unresolvedKeys`, `isSendBlocked`; `UnresolvedTokenHighlighter`; `familyManager.currentMember?.isParent`.

- [ ] **Step 1: Add the variables panel section** — a new `private struct QuickCommVariablesPanel: View` listing `viewModel.referencedVariables`:
  - **authored** (`isAuthored`): a labeled `TextField` bound to `viewModel.authoredBinding(for: v.key)`, `.disabled(isParent)` with a caption "Ask the athlete to fill this" when `isParent`.
  - **resolved** profile-backed (`isResolved`, not authored): read-only row showing `v.label`: `v.resolvedValue`.
  - **missing** profile-backed (`!isResolved`, not authored): row showing `v.label` + caption "Complete in your profile" (static hint, no navigation — see scope note).
  Insert it between the template picker and the preview, shown only when `!viewModel.referencedVariables.isEmpty`. Pass `isParent = familyManager.currentMember?.isParent == true`.

- [ ] **Step 2: Amber preview** — replace `QuickCommBodyPreviewSection(filledBody:)` usage so it renders `Text(UnresolvedTokenHighlighter.attributed(viewModel.effectiveBody, tokenColor: .warningOrange))`. Change that component to take an `AttributedString` (or add a sibling `QuickCommBodyPreviewSection(attributed:)`). Keep its accessibility label as the plain string `viewModel.effectiveBody`.

- [ ] **Step 3: Editable subject/body** — add (behind the preview, or replacing it) a `TextField("Subject", text:)` for `.email` bound to a `Binding` that reads `viewModel.effectiveSubject` / writes `viewModel.editedSubject`, and a `TextEditor` for the body bound to read `viewModel.effectiveBody` / write `viewModel.editedBody`. (Editing switches the preview to the amber highlight of the edited text automatically via `effectiveBody`.)

```swift
  private var subjectBinding: Binding<String> {
    Binding(get: { viewModel.effectiveSubject },
            set: { viewModel.editedSubject = $0 })
  }
  private var bodyBinding: Binding<String> {
    Binding(get: { viewModel.effectiveBody },
            set: { viewModel.editedBody = $0 })
  }
```

- [ ] **Step 4: 160-char counter** — for `.message` templates, show `"\(viewModel.effectiveBody.count)/160"` under the body editor, colored `.errorRed` when `viewModel.textBodyOverLimit`. The Task-2 `isSendBlocked` already includes `textBodyOverLimit`, so the existing `.disabled(viewModel.isSendBlocked)` on the actions section covers gating.

- [ ] **Step 5: Build + regression** — boot sim, `xcodebuild build ... -quiet`, then run `QuickCommunicationPanelTests`, `QuickCommunicationResolveTests`, `QuickCommunicationViewModelTests`, `CommunicationTemplatesAccessibilityTests`, `TemplateVariableExtractorTests`, `UnresolvedTokenHighlighterTests`. Expected: build clean; all PASS.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/QuickCommunicationView.swift
git commit -m "feat(coaches): variables panel, amber preview, editable subject/body, 160-char text counter"
```

---

### Task 5: Manual verification

- [ ] **Step 1:** Boot iPhone 17 sim, launch as an **athlete** with a filled profile + a coach with email.
- [ ] **Step 2:** Open Quick Communication → intro **email** template. Expected: panel lists the template's variables — profile-backed ones show resolved values, authored ones (`programNote`/`updateHook`) show empty text fields; unresolved tokens render amber in the preview; send disabled.
- [ ] **Step 3:** Type the authored fields → their tokens fill, amber clears, send enables. Edit the body → preview reflects edits, still gated on any remaining tokens.
- [ ] **Step 4:** Pick a **text** template → no subject field; type past 160 chars → counter turns red, send disables.
- [ ] **Step 5:** Sign in as a **parent** viewing the athlete → authored fields are read-only with the "ask the athlete" caption; resolved profile values still show.
- [ ] **Step 6:** Full regression: run the `CommunicationTemplates` + `Coaches` test dirs. Trust exit code.

---

## Self-Review

**Spec coverage (Phase 2 UI rows):** variables panel → Tasks 1+2+4; authored inputs (athlete-only) → Task 2 binding + Task 4 parent gating; read-only + profile hint → Task 4; amber unresolved highlight → Task 3+4; send disabled while unresolved → Task 2 (`isSendBlocked`) already wired; editable subject/body + 160-char text → Tasks 2+4. ✅

**Deferred to Phase 3 (not gaps):** contact-window pre/open filter, guardrails `/check`+log, Instagram open-profile button. Real cross-modal "Edit in profile" navigation is a documented 2b cut (static hint only).

**Placeholder scan:** Tasks 1–3 carry full code + tests; Task 4 is SwiftUI composition with per-step behavior specified and binding snippets given; the two "verify at implementation time" notes (`findUnresolved` returns-all-tokens; `AttributedString.Index` initializer) are toolchain confirmations, not logic gaps.

**Type consistency:** `ReferencedVariable`/`referenced(...)` identical across Tasks 1/2/4; `editedSubject`/`editedBody`/`effectiveSubject`/`effectiveBody`/`textBodyOverLimit`/`referencedVariables`/`authoredBinding` identical between Task 2 impl+test and Task 4 use; `UnresolvedTokenHighlighter.attributed` identical between Task 3 and Task 4.

**Regression guard:** `unresolvedKeys`/`isSendBlocked`/`messageBody` are retargeted from Phase 2a's `resolvedBody` to `effectiveBody` — the Phase-2a `QuickCommunicationResolveTests` still hold because with no edits `effectiveBody == resolvedBody`. Legacy `QuickCommunicationViewModelTests` `filledBody` path is untouched (registry empty → `messageBody == filledBody`).
