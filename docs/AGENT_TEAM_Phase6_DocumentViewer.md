# Agent Team: Phase 6 Document Viewer

This document defines a **five-role agent team** to implement the Document Viewer feature from the iOS spec. Feature implementation uses subagent-driven development; Unit Tests, E2E Tests, Refactor, and A11y run in parallel after implementation is complete.

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentViewer.md`  
**Implementation plan:** `docs/plans/2026-02-18-document-viewer-implementation.md`  
**Web reference:** `recruiting-compass-web/pages/documents/view.vue`, `composables/useDocumentsConsolidated.ts`

---

## Team Roles and Order of Operations

1. **Feature Implementer** – Implements the plan task-by-task using subagent-driven development. **MUST complete first.**
2. **Unit Test Teammate** – Adds unit tests for DocumentViewerViewModel, DocumentCollection.
3. **E2E Test Teammate** – Adds E2E tests for document viewer flows.
4. **Refactor Teammate** – Simplifies code, removes duplication.
5. **A11y Teammate** – VoiceOver labels, 44pt targets, accessibility tests.

**Order:** Feature Implementer first. Roles 2–5 run in parallel after implementation.

---

## 1. Feature Implementer (Subagent-Driven Development)

**Skill:** `superpowers:subagent-driven-development`

**Prompt for controller:**

Read `docs/plans/2026-02-18-document-viewer-implementation.md` once and extract every task (Tasks 1–6) with full text and file paths. Create a `TodoWrite` with all tasks. For each task: dispatch implementer subagent → spec compliance reviewer → code quality reviewer. Fix and re-review if needed. Mark complete and proceed. After all tasks: `make build`, then hand off to other teammates.

**Implementer subagent prompt:**

```
Implement the Document Viewer feature for Recruiting Compass iOS.

Context:
- Plan: docs/plans/2026-02-18-document-viewer-implementation.md
- Spec: recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentViewer.md
- Web: pages/documents/view.vue, composables/useDocumentsConsolidated.ts
- Existing: Features/Documents/Models/Document.swift, DocumentPreviewView.swift, DocumentsListView

Your task (from plan):
[TASK N: copy full task text]

1. Implement per the plan. Use exact file paths. Follow MVVM, @Observable, protocol-based DI.
2. Run `make build` from repo root.
3. Self-review: spec compliance and code quality.
4. Report: what you implemented, any assumptions.
```

---

## 2. Unit Test Teammate

**Trigger:** After Feature Implementer completes.

**Prompt:**

```
You are the Unit Test teammate for Phase 6 Document Viewer.

Inputs:
- Plan: docs/plans/2026-02-18-document-viewer-implementation.md
- Implemented code: TheRecruitingCompass/Features/Documents/ (DocumentViewerViewModel, DocumentViewerView, ShareSheet, DocumentCollection)

Your job:
1. Create TheRecruitingCompassTests/Features/Documents/ViewModels/DocumentViewerViewModelTests.swift.
2. Test: loadDocument (with document passed), shareDocument, downloadDocument, retryLoad, nextDocument/previousDocument (if collection), error states.
3. Use MockDocumentsManaging. Follow TheRecruitingCompassTests/Features/Documents/ViewModels/DocumentDetailViewModelTests.swift patterns.
4. Add DocumentCollectionTests if DocumentCollection is a separate struct.
5. Run: make test-unit. Fix failures.
6. Report: test files added and coverage summary.
```

---

## 3. E2E Test Teammate

**Trigger:** After Feature Implementer completes.

**Prompt:**

```
You are the E2E Test teammate for Phase 6 Document Viewer.

Inputs:
- Plan: docs/plans/2026-02-18-document-viewer-implementation.md
- Spec: Section 2 User Flows, Section 9 Testing Checklist

Your job:
1. Create or extend TheRecruitingCompassUITests/Features/Documents/DocumentViewerE2ETests.swift.
2. Test: tap document card → viewer opens, close button dismisses, swipe down dismisses, share button presents sheet, download button works.
3. Use accessibility identifiers (e.g. document-viewer-close, document-viewer-share).
4. Follow TheRecruitingCompassUITests/Features/Documents/DocumentDetailE2ETests.swift patterns.
5. Run: make test (or xcodebuild test). Fix failures.
6. Report: tests created and status.
```

---

## 4. Refactor Teammate

**Trigger:** After Feature Implementer completes.

**Prompt:**

```
You are the Refactor teammate for Phase 6 Document Viewer.

Inputs:
- Implemented code: TheRecruitingCompass/Features/Documents/ (DocumentViewerViewModel, DocumentViewerView, ShareSheet)

Your job:
1. Apply refactor-cleaner / refactor-specialist patterns: remove duplication, simplify logic, extract helpers if needed.
2. Ensure DocumentPreviewView reuse is clean; avoid copy-paste.
3. Run: make build, make test-unit. Verify no regressions.
4. Report: refactors applied.
```

---

## 5. A11y Teammate

**Trigger:** After Feature Implementer completes.

**Prompt:**

```
You are the A11y teammate for Phase 6 Document Viewer.

Inputs:
- Spec Section 6 Accessibility: VoiceOver labels, 44pt targets, Dynamic Type
- Implemented: DocumentViewerView, toolbar buttons

Your job:
1. Add accessibility labels per spec: "Close document viewer", "Share document", "Download document to device".
2. Ensure all buttons have 44pt minimum hit targets.
3. Add TheRecruitingCompassTests/Features/Documents/Accessibility/DocumentViewerAccessibilityTests.swift.
4. Verify VoiceOver flow: close, share, download, page indicator (if collection).
5. Run: make test-unit. Report: a11y fixes and tests added.
```

---

## Verification

After all teammates complete:
- `make build` passes
- `make test-unit` passes
- `make test` (including UI tests) passes
- Document Viewer opens from Documents List, shows preview, share/download work, swipe-down dismisses
