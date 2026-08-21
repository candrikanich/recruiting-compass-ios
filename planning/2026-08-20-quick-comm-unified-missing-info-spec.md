# Spec: Unified "Complete your info" step for Quick Comm missing template data

**Date:** 2026-08-20
**Feature:** Coaches → Quick Communication send wizard
**Status:** Approved design, pending implementation

## Problem

A template can reference data the athlete hasn't supplied yet. Today that missing data is
collected through **four different UI idioms at three points in the flow**, which is
inconsistent and confusing:

| Data | Surface today | When |
|---|---|---|
| Authored vars (programNote, updateHook, …) | inline panel (`QuickCommVariablesPanel`) | details step |
| Metrics (`metrics`/`carryingTool`) | CTA → full `PerformanceDashboardView` **sheet** | details step (optional) |
| Specificity (`programNote` / `fitReason`) | **separate wizard step** (`specificityScreen`) | step 3b |
| Intended major | **alert + TextField** | pre-send gate |
| Questionnaire | **alert yes/no** | pre-send gate |

## Goal

Collect all template missing-data through **one consistent step** — "Complete your info" —
inserted before Preview. One mental model, one presentation idiom.

## Decisions (locked)

- **Flow shape:** one dedicated wizard step before Preview.
- **Field set:** show **missing/unanswered only**. If the template needs nothing, the step
  auto-skips straight to Preview.
- **Metrics:** a consistent row in the form that **links out** to the existing
  `PerformanceDashboardView` sheet (metric logging is genuinely heavier; no inline rebuild).
- **Enforcement:** keep current gating. **Continue is always enabled**; template-required
  unresolved tokens still block the actual Send at Preview via the existing `isSendBlocked`
  notice. Optional fields remain skippable.
- **Details step:** kept as **subject + body** editing only. Structured/guided fields move to
  the new step.

## Design

### VM model (`QuickCommunicationViewModel`)

```swift
struct MissingInfoField: Identifiable {
  enum Editor { case text(multiline: Bool), boolean, metricLink }
  let id: String            // token key
  let title: String
  let prompt: String
  let editor: Editor
  let editableByParent: Bool
}

/// Rows for every UNRESOLVED need the current template references, in stable order.
var missingInfoFields: [MissingInfoField]
var hasMissingInfo: Bool { !missingInfoFields.isEmpty }
```

**Row builder — stable order, missing-only:**

1. `questionnaireNote` → `.boolean` — shown when `shouldPromptQuestionnaire`. Persist to schools
   on "Completed" (`confirmQuestionnaireCompleted`); "Not yet" leaves it (token stripped).
2. `intendedMajor` → `.text(multiline: false)` — shown when `shouldPromptIntendedMajor`.
   Persist to player prefs (`saveIntendedMajor`).
3. `programNote` → `.text(multiline: true)` — shown when referenced & unresolved. Keeps the
   "Why this program?" copy. `editableByParent = false`.
4. `fitReason` → `.text(multiline: true)` — keeps "Why does it fit you?" copy.
   `editableByParent = false`.
5. Other unresolved authored vars (e.g. `updateHook`) → `.text(multiline: false)`, registry
   label as title. `editableByParent = true`.
6. `metrics`/`carryingTool` → `.metricLink` — shown when `suggestsAddingMetrics`. Opens the
   existing metrics sheet.

**Bindings/persistence:**
- Authored-var rows (programNote, fitReason, updateHook, …) bind to `authoredBinding(for:key)`
  — already in-memory in `authoredValues`, consumed directly by the resolver. No async persist.
- `intendedMajor` binds to `intendedMajorDraft`; persisted on Continue (call `saveIntendedMajor`
  if non-empty).
- Questionnaire boolean: on Continue, if marked completed call `confirmQuestionnaireCompleted`.
- After persists, `loadResolverInputs()` then push Preview.

### View (`QuickCommunicationView`)

- New `completeInfoScreen(channel:)` + `QuickCommStep.completeInfo(channel)`.
- Renders `viewModel.missingInfoFields` as a single scrollable form; one row component per
  `Editor` case (reuse `QuickCommSpecificityField` styling for `.text` multiline; a segmented
  "Completed / Not yet" for `.boolean`; a labeled link row for `.metricLink`).
- Parent-locked rows disabled with the existing "Ask the athlete to answer these." note.
- **Continue** (always enabled): persist prefs-backed + questionnaire, `loadResolverInputs()`,
  `path.append(.preview(channel))`.
- Metrics sheet (`showMetricsSheet` → `PerformanceDashboardView`) moves onto this step.
- Routing: details "Preview & Send" → `hasMissingInfo ? .completeInfo(channel) : .preview(channel)`.

### Deletions

- `specificityScreen` + `QuickCommStep.specificity`.
- Both pre-send `.alert`s; `promptQuestionnaire`, `promptIntendedMajor`, `resumePendingSend`,
  `pendingSendChannel`, `PendingSendChannel`.
- `shouldPrompt*` branches inside `handleSendEmail`/`handleSendText` → send does
  guardrails → composer only.
- `QuickCommVariablesPanel` + metrics CTA off the **details** screen. Details keeps subject +
  body editor.

### Kept (test-preserving)

`confirmQuestionnaireCompleted`, `skipQuestionnairePrompt`, `saveIntendedMajor`,
`skipIntendedMajorPrompt`, and the `shouldPromptQuestionnaire` / `shouldPromptIntendedMajor` /
`needsSpecificityPrompt` / `suggestsAddingMetrics` predicates — repurposed as the missing-field
feeders. Existing 8 `QuickCommunicationQuestionnaireTests` stay green.

## Testing

- **New VM unit tests** (pure, template + resolvedContext → rows):
  - order is stable (questionnaire → major → programNote → fitReason → other → metrics)
  - missing-only: resolved needs produce no row; `hasMissingInfo` false when nothing missing
  - editor mapping: questionnaire=`.boolean`, major/authored=`.text`, metrics=`.metricLink`
  - parent-lock: programNote/fitReason `editableByParent == false`
- Existing questionnaire tests unchanged.
- Step view, removed alerts, routing = view-layer → **device verify**.

## Out of scope

- Web parity (this is an iOS-only presentation refactor; underlying persistence paths unchanged).
- Inline metric entry (metrics still links to the dashboard).
- Any change to token parsing / resolver / registry.
