# Agent Team: Phase 6 Documents List

This document defines a **five-role agent team** to implement the Documents List feature from the iOS spec. Use subagent-driven development with dedicated teammates for feature implementation, unit tests, E2E tests, refactor, and accessibility.

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentsList.md`  
**Implementation plan:** `docs/plans/2026-02-18-documents-list-implementation.md`  
**Web reference:** `recruiting-compass-web/pages/documents/index.vue`, `composables/useDocumentsConsolidated.ts`

---

## Team Roles and Order of Operations

1. **Feature Implementer** – Implements the plan task-by-task using subagent-driven development.
2. **Unit Test Teammate** – Adds unit tests for models, service, ViewModel.
3. **E2E Test Teammate** – Adds E2E tests for main flows.
4. **Refactor Teammate** – Simplifies code, removes duplication.
5. **A11y Teammate** – VoiceOver, 44pt targets, accessibility tests.

**Order:** Feature Implementer first. Roles 2–5 can run in parallel after implementation is complete.

---

## 1. Feature Implementer (Subagent-Driven Development)

**Skill:** `superpowers:subagent-driven-development`

**Prompt for controller:**

Read `docs/plans/2026-02-18-documents-list-implementation.md` once and extract every task (Tasks 1–9) with full text and file paths. Create a `TodoWrite` with all tasks. For each task: dispatch implementer subagent → spec compliance reviewer → code quality reviewer. Fix and re-review if needed. Mark complete and proceed. After all tasks: `make build`, then hand off to other teammates.

**Implementer subagent prompt:**

```
Implement the Documents List feature for Recruiting Compass iOS.

Context:
- Plan: docs/plans/2026-02-18-documents-list-implementation.md
- Spec: recruiting-compass-web/planning/iOS_SPEC_Phase6_DocumentsList.md
- Web: pages/documents/index.vue, composables/useDocumentsConsolidated.ts
- Patterns: Features/Events/, Features/Schools/, CLAUDE.md, docs/CODE_PATTERNS.md

Your task (from plan):
[TASK N: copy full task text]

1. Implement per the plan. Use exact file paths. Follow MVVM, @Observable, protocol-based DI.
2. Run `make build` from repo root.
3. Self-review: spec compliance and code quality.
4. Report: what you implemented, any assumptions.
```

---

## 2. Unit Test Teammate

**Trigger:** After Feature Implementer completes implementation.

**Prompt:**

```
You are the Unit Test teammate for Phase 6 Documents List.

Inputs:
- Plan: docs/plans/2026-02-18-documents-list-implementation.md
- Implemented code: TheRecruitingCompass/Features/Documents/

Your job:
1. Create TheRecruitingCompassTests/Features/Documents/ with:
   - Document model tests (Codable, computed properties: isShared, typeEmoji, displayDate)
   - DocumentType tests (allowedExtensions, label)
   - DocumentsListViewModelTests: loadDocuments, filteredDocuments, sortedDocuments, statistics, deleteDocument. Use MockDocumentsManaging and MockAuthManaging.
   - MockDocumentsManaging implementation for tests.
2. Follow TheRecruitingCompassTests/Features/Events/ patterns.
3. Run: make test-unit. Fix failures.
4. Report: test files added and coverage summary.
```

---

## 3. E2E Test Teammate

**Trigger:** After Feature Implementer completes implementation.

**Prompt:**

```
You are the E2E Test teammate for Phase 6 Documents List.

Inputs:
- Plan: docs/plans/2026-02-18-documents-list-implementation.md
- Spec section 6: UI layout and interactions

Your job:
1. Create TheRecruitingCompassUITests/Features/Documents/DocumentsListE2ETests.swift.
2. Test: page loads, empty state, grid/list toggle, filter button, sort dropdown, upload button presence, statistics cards.
3. Use accessibility identifiers (e.g. page-title, filter-button) per spec.
4. Follow TheRecruitingCompassUITests patterns (e.g. FamilyManagementPlayerFlowsE2ETests).
5. Run: make test (or xcodebuild test). Fix failures.
6. Report: tests created and status.
```

---

## 4. Refactor Teammate

**Trigger:** After Feature Implementer completes implementation (can run alongside Unit/E2E).

**Prompt:**

```
You are the Refactor teammate for Phase 6 Documents List.

Inputs:
- Plan: docs/plans/2026-02-18-documents-list-implementation.md
- Implemented code: TheRecruitingCompass/Features/Documents/

Your job:
1. Review for: DRY violations, unclear naming, inconsistency with Events/Schools.
2. Remove dead code, simplify complex logic.
3. Ensure patterns match CLAUDE.md and docs/CODE_PATTERNS.md.
4. Do not change behavior; only refactor.
5. Run make build and make test-unit after changes.
6. Report: refactors applied.
```

---

## 5. A11y Teammate

**Trigger:** After Feature Implementer completes implementation.

**Prompt:**

```
You are the A11y teammate for Phase 6 Documents List.

Inputs:
- Spec section 6 Accessibility: docs/plans/... and iOS_SPEC_Phase6_DocumentsList.md
- Implemented views: DocumentsListView, DocumentCardView, upload sheet, filter bar
- Reference: docs/ACCESSIBILITY_AUDIT.md, existing *AccessibilityTests.swift

Your job:
1. Audit: VoiceOver labels for cards ("Title. Type. Shared with N schools. Date"), upload button ("Upload new document"), filter button ("Filter documents. N filters active.").
2. Ensure 44pt minimum touch targets.
3. Add DocumentsListAccessibilityTests.swift in TheRecruitingCompassTests/Features/Documents/Accessibility/.
4. Verify Dynamic Type support in list view.
5. Run: make test-unit. Fix failures.
6. Report: audit findings and tests added.
```

---

## Quick Reference

| Role | Subagent Type | Runs After |
|------|---------------|------------|
| Feature Implementer | planner / architect / generalPurpose | — |
| Unit Tests | test-automation-engineer | Feature Implementer |
| E2E Tests | e2e-runner | Feature Implementer |
| Refactor | refactor-specialist | Feature Implementer |
| A11y | a11y-wcag-auditor | Feature Implementer |

**Build/Test commands:**
```bash
make build
make test-unit
make test
```
