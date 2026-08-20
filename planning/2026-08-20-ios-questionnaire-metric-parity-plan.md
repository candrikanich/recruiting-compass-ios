# iOS Parity Plan — Item 1d (send-time questionnaire prompt) + Item 2 (metric unit map)

**Date:** 2026-08-20
**Spec:** `planning/iOS_SPEC_questionnaire-and-metric-parity-2026-08-19.md` (+ 2026-08-20 addendum)
**Audit:** 5/7 done. This plan closes the 2 real gaps. Item 4 (skip-logging toggle) deliberately out — spec recommends leaving iOS always-log behavior.
**Web truth verified against** `recruiting-compass-web/components/Performance/LogMetricModal.vue:76` and `.vue` template resolver parity.

---

## Item 2 — align `MetricType.defaultUnit` to web write path (SMALL)

### Problem
`defaultUnit` doubles as (a) the stored unit on a logged metric and (b) the locked display in `MetricFormView`. Three values diverge from web's `unitByMetricType`, and none are members of `unitVocabulary` — so iOS writes units web never writes for the same metric type. Cross-platform data-parity bug.

| metric_type | iOS now | web (canonical) |
|---|---|---|
| `batting_avg` | `"avg"` | `""` |
| `era` | `"era"` | `""` |
| `strikeouts` | `"K"` | `"count"` |

velocity/exit_velo `mph`, sixty_time/pop_time `sec`, other `""` already match.

### Change
`Features/Performance/Models/MetricType.swift:28-37` — edit `defaultUnit`:
```swift
var defaultUnit: String {
  switch self {
  case .velocity, .exitVelo: return "mph"
  case .sixtyTime, .popTime: return "sec"
  case .battingAvg, .era: return ""
  case .strikeouts: return "count"
  case .other: return ""
  }
}
```

### Data-migration check (DO before shipping)
Existing metric rows may carry legacy `"avg"`/`"era"`/`"K"` unit strings written by prior iOS builds.
- Query prod: `select unit, count(*) from performance_metrics where metric_type in ('batting_avg','era','strikeouts') group by unit;`
- If legacy rows exist, decide: leave as historical (display code already tolerates any unit string), or one-shot UPDATE to normalize (`avg`/`era`→`''`, `K`→`count`). Recommend normalize for clean parity; low risk, `unit` is display-only.

### Tests
- `MetricTypeTests` (or add): assert `MetricType.battingAvg.defaultUnit == ""`, `.era == ""`, `.strikeouts == "count"`.
- Assert every `defaultUnit` value ∈ `unitVocabulary` (guards future drift) — batting_avg/era `""` and strikeouts `"count"` are all members. ✅

---

## Item 1d — native send-time questionnaire prompt (MEDIUM)

### Goal
When the composed message references `{{questionnaireNote}}` and the school's flag is false, prompt once before send: "Did you complete <school>'s recruiting questionnaire?" Yes → persist flag (reuse 1c path) + re-resolve so the completion line fills; Skip → send without it. Native `.alert`/`.confirmationDialog` only — NO web amber banner.

### Precedent — mirror the intended-major prompt exactly
The VM+View already implement this pattern for `{{intendedMajor}}`. Copy it:
- VM: `shouldPromptIntendedMajor` / `showIntendedMajorPrompt` / `intendedMajorDraft` / `saveIntendedMajor()` / `skipIntendedMajorPrompt()` / `intendedMajorPromptHandled`.
- View: `promptIntendedMajor(then:)` / `resumePendingSend()` / `.alert(...)` + `handleSendEmail`/`handleSendText` early-return guard.

### VM changes — `Features/Coaches/ViewModels/QuickCommunicationViewModel.swift`
1. State:
   ```swift
   var showQuestionnairePrompt = false
   private var questionnairePromptHandled = false
   ```
2. Gate — questionnaireNote is a COMPUTED scalar (no registry def), so `referencedVariables` won't list it. Detect via the raw template body token instead:
   ```swift
   /// True when the selected template references {{questionnaireNote}}, the school's
   /// questionnaire is not marked complete, and we haven't prompted yet.
   var shouldPromptQuestionnaire: Bool {
     guard !questionnairePromptHandled,
           let body = selectedTemplate?.body,
           body.contains("{{questionnaireNote}}") else { return false }
     return resolvedContext?.tables["schools"]?["questionnaire_completed"] != "true"
   }
   ```
   (Confirm token spelling in seeded templates — grep DB/templates for `questionnaireNote`. If templates wrap it `[[questionnaireNote|...]]`, match that substring instead.)
3. Persist + re-resolve on Yes (reuse 1c service path — `SchoolsManaging.updateQuestionnaireCompleted`):
   ```swift
   func confirmQuestionnaireCompleted() async {
     questionnairePromptHandled = true
     do {
       try await schoolsService.updateQuestionnaireCompleted(id: coach.schoolId, completed: true)
       await loadResolverInputs()   // re-resolve so {{questionnaireNote}} fills
     } catch {
       logger.error("Failed to set questionnaire_completed: \(error.localizedDescription)")
     }
   }
   func skipQuestionnairePrompt() { questionnairePromptHandled = true }
   ```
   Verify `updateQuestionnaireCompleted(id:completed:)` exists on `SchoolsManaging` (audit says `SchoolsManaging.swift:40-42`). ✅
4. Reset in `selectTemplate`: add `questionnairePromptHandled = false` next to `intendedMajorPromptHandled = false`.

### View changes — `Features/Coaches/Views/QuickCommunicationView.swift`
1. `handleSendEmail` / `handleSendText`: add a guard BEFORE the intended-major guard (or after — order is a product call; recommend questionnaire first so both prompts can chain via `resumePendingSend`):
   ```swift
   if viewModel.shouldPromptQuestionnaire {
     promptQuestionnaire(then: .email)   // / .text
     return
   }
   ```
2. Helper + resume (mirror `promptIntendedMajor`):
   ```swift
   private func promptQuestionnaire(then channel: PendingSendChannel) {
     pendingSendChannel = channel
     viewModel.showQuestionnairePrompt = true
   }
   ```
   `resumePendingSend()` already re-dispatches to `handleSendEmail/Text`, which re-checks `shouldPromptQuestionnaire` (now handled=true) then falls through to the major prompt / send. No change needed there.
3. Alert on the root screen (next to the intended-major `.alert`):
   ```swift
   .alert("Did you complete \(viewModel.schoolDisplayName)'s recruiting questionnaire?",
          isPresented: $viewModel.showQuestionnairePrompt) {
     Button("Yes, I completed it") {
       Task { await viewModel.confirmQuestionnaireCompleted(); resumePendingSend() }
     }
     Button("Skip", role: .cancel) {
       viewModel.skipQuestionnairePrompt(); resumePendingSend()
     }
   } message: {
     Text("Marks it complete and adds \"I've completed your recruiting questionnaire\" to this message.")
   }
   ```

### Prompt-chaining note
Two pre-send prompts can now exist (questionnaire + intended-major). `resumePendingSend()` re-enters the send handler, which re-evaluates guards top-down; each `*Handled` flag flips true after its prompt, so they surface one at a time then the send proceeds. Verify manually: template with BOTH tokens → questionnaire alert → Yes → major alert → Save → composer opens.

### Tests
`QuickCommunicationViewModelTests`:
- `shouldPromptQuestionnaire` true when template body has token + school flag not "true"; false when flag "true"; false after `confirmQuestionnaireCompleted`/`skipQuestionnairePrompt`.
- `confirmQuestionnaireCompleted` calls `updateQuestionnaireCompleted(id:completed:true)` on a mock `SchoolsManaging` and re-resolves (mock returns school with flag → `cleanBody` then contains the completion sentence).
- `selectTemplate` resets `questionnairePromptHandled` (prompt fires again for a fresh template).

---

## Sequencing
1. Item 2 first (isolated, small, no UI). Build + unit test.
2. Item 1d second (VM then View). Build + unit test.
3. Manual sim: (a) log batting_avg → unit locked blank, stored `''`; (b) template w/ questionnaireNote + incomplete school → alert → Yes → line appears → send; Skip → line absent.
4. Run affected classes only (not full ~3700 suite): `MetricTypeTests`, `QuickCommunicationViewModelTests`, `TemplateComputedScalarTests`.

## Open questions
- **Item 2 data migration:** normalize legacy `avg`/`era`/`K` rows in prod, or leave as history? (Recommend normalize.)
- **1d token form:** raw `{{questionnaireNote}}` vs wrapped `[[questionnaireNote|...]]` in seeded templates — confirm before finalizing `shouldPromptQuestionnaire` substring.
- **Prompt order:** questionnaire-before-major vs major-before-questionnaire when a template has both. (Recommend questionnaire first.)
