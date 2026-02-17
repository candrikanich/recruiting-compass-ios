# Agent Team: Phase 5 Tasks / Recruiting Timeline

This document defines a **five-role agent team** to implement the Tasks / Recruiting Timeline feature from the iOS spec. Use it to run subagent-driven development with dedicated teammates for feature implementation, unit tests, E2E tests, refactor, and accessibility.

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md`  
**Implementation plan:** `docs/plans/2026-02-17-phase5-tasks-timeline.md`  
**Web reference:** `recruiting-compass-web/pages/tasks/index.vue`, `composables/useTasks.ts`, `utils/gradeHelpers.ts`, `utils/deadlineHelpers.ts`

---

## Team roles and order of operations

1. **Feature Implementer** – Implements the plan task-by-task using subagent-driven development (spec + code quality review after each task).
2. **Unit Test Teammate** – Adds and expands unit tests for models, service, ViewModel, filters, sorting, locking.
3. **E2E Test Teammate** – Adds E2E tests for main flows, filters, parent mode, errors.
4. **Refactor Teammate** – Simplifies code, removes duplication, aligns with CLAUDE.md and project patterns.
5. **A11y Teammate** – Ensures VoiceOver, 44pt targets, contrast, and accessibility tests/audit.

Roles 2–5 can be dispatched **after** the Feature Implementer completes the implementation plan (through Task 11). They can run in parallel or in sequence; Refactor and A11y are typically last so they work on stable code.

---

## 1. Feature Implementer (Subagent-Driven Development)

**Skill:** `superpowers:subagent-driven-development`

**Prompt for controller (you):**

- Read `docs/plans/2026-02-17-phase5-tasks-timeline.md` once and extract every task (Tasks 1–11) with full text and file paths.
- Create a `TodoWrite` with all 11 tasks.
- For each task:
  1. Dispatch a **fresh implementer subagent** with:
     - The exact task text (number, title, files, steps).
     - Context: "iOS app TheRecruitingCompass, MVVM, SwiftUI, Supabase. Spec: iOS_SPEC_Phase5_TasksTimeline. Web reference: pages/tasks/index.vue, useTasks.ts, gradeHelpers, deadlineHelpers. Follow CLAUDE.md and existing patterns in Features/Offers and Features/Dashboard."
  2. After the implementer finishes (and self-reviews): dispatch **spec compliance reviewer** – confirm behavior matches the spec (data model, API, filters, locking, parent mode, UI copy).
  3. If spec passes: dispatch **code quality reviewer** – approve or request fixes (naming, structure, tests, no dead code).
  4. If either review fails: have the **same implementer subagent** fix and re-run that reviewer.
  5. When both reviews pass, mark the task complete in TodoWrite and proceed to the next task.
- After all 11 tasks: run build and tests; then hand off to Unit Test, E2E, Refactor, and A11y teammates as needed.

**Implementer subagent prompt (give this to the subagent):**

```
You are implementing Task N of the Phase 5 Tasks/Timeline feature for the iOS app.

Context:
- Repo: TheRecruitingCompass iOS. MVVM, SwiftUI, Supabase. See CLAUDE.md.
- Spec: iOS_SPEC_Phase5_TasksTimeline.md (Tasks page: filters, progress, locking, parent mode).
- Web parity: pages/tasks/index.vue, useTasks.ts, gradeHelpers.ts, deadlineHelpers.ts.

Your task (copy from plan):
[TASK N full text: title, files, steps]

Do the following:
1. If anything is unclear (e.g. Supabase schema, filter keys), ask before coding.
2. Implement following TDD where the plan specifies tests first.
3. Use exact file paths from the plan. Follow existing patterns in Features/Offers and Features/Dashboard (Services, ViewModels, Views, Components).
4. Run the relevant tests and fix until they pass. Build the app for iPhone simulator.
5. Self-review: spec compliance and code quality. Then report done and list what you implemented and any assumptions.
```

---

## 2. Unit Test Teammate

**Trigger:** After Feature Implementer has completed all 11 tasks (or after Tasks 1–5 for early coverage).

**Prompt for this teammate:**

```
You are the Unit Test teammate for Phase 5 Tasks/Timeline.

Inputs:
- Spec: recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md
- Plan: docs/plans/2026-02-17-phase5-tasks-timeline.md
- Implemented code: TheRecruitingCompass/Features/Tasks/ (Models, Services, ViewModels, Components, Views)

Your job:
1. Add or expand unit tests so that:
   - All Task/Models (TaskStatus, DeadlineUrgency, AthleteTaskStatus, TaskSummary, TaskWithStatus) have tests for decoding and computed properties (e.g. isLocked, deadlineUrgency, statusColor).
   - GradeLevelHelper has tests for grade calculation (freshman–senior, month boundaries).
   - TasksServiceImpl (or equivalent) has tests with mocked Supabase/client for fetchTasksWithStatus and updateTaskStatus.
   - TasksListViewModel has tests for: load/refresh, status and urgency filters, filter persistence (UserDefaults), filteredTasks ordering (required first, then urgency, then alphabetical), progress (completed/total, %), markComplete (success and locked path), expandedTaskId, parent mode (read-only, athlete id).
   - Edge cases: empty list, all completed, no unlocked tasks, nil deadline.
2. Follow existing test style in TheRecruitingCompassTests (e.g. Features/Offers, Features/Notifications). Use mocks for TasksManaging and auth/family context.
3. Run: cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' (or iPhone 16 if that's what's available). Fix any failures.
4. Report: list of test files added/updated and a short summary of coverage (models, service, ViewModel, filters, locking).
```

---

## 3. E2E Test Teammate

**Trigger:** After Feature Implementer has completed the plan and Tasks list UI is navigable.

**Prompt for this teammate:**

```
You are the E2E Test teammate for Phase 5 Tasks/Timeline.

Inputs:
- Spec: iOS_SPEC_Phase5_TasksTimeline.md (user flows, success criteria)
- Plan: docs/plans/2026-02-17-phase5-tasks-timeline.md
- Implemented app: Tasks tab/screen and all UI from the plan

Your job:
1. Add E2E tests in TheRecruitingCompassUITests/Features/Tasks/ (or similar) for:
   - Happy path: Open Tasks, see progress and task list; change status filter and urgency filter; expand/collapse a task; mark an unlocked task complete and see success message (and optional refresh).
   - Locked task: Tap checkbox on locked task; see alert with prerequisites; no status change.
   - Parent mode: As parent, open Tasks; see read-only banner and athlete switcher; checkboxes disabled; no completion possible.
   - Empty state: When no tasks for grade, see "No tasks available for this grade level".
   - Error/recovery: Simulate or mock failure; see error UI; pull-to-refresh or retry recovers.
2. Use the same patterns as existing UITests (e.g. Features/Offers, Features/Interactions). Prefer accessibility identifiers for stability.
3. Run the UI test target and fix until they pass.
4. Report: list of E2E test files and scenarios covered.
```

---

## 4. Refactor Teammate

**Trigger:** After Feature Implementer is done and Unit + E2E teammates have run (so behavior is protected by tests).

**Skill:** `refactor-pass` (simplification, dead-code removal; keep tests green)

**Prompt for this teammate:**

```
You are the Refactor teammate for Phase 5 Tasks/Timeline.

Inputs:
- CLAUDE.md (project rules, MVVM, naming, file organization)
- docs/CODE_PATTERNS.md, docs/SWIFTUI_CODE_REVIEW.md
- Implemented code: TheRecruitingCompass/Features/Tasks/

Your job:
1. Refactor for simplicity and consistency:
   - Remove dead code and unused types/imports.
   - Align naming with project conventions (ViewModels, Views, Services, Protocols).
   - Extract repeated logic (e.g. sorting, filter application) into small, testable helpers if it improves clarity.
   - Keep ViewModels @MainActor; keep Services non-@MainActor and protocol-based.
2. Do not change behavior or spec compliance. All unit and E2E tests must still pass.
3. Run build and full test suite after refactor. Report what was simplified or moved.
```

---

## 5. A11y Teammate

**Trigger:** After UI and refactor are stable.

**Inputs:** `docs/ACCESSIBILITY_AUDIT.md`, spec Section 6 (Accessibility), WCAG AA.

**Prompt for this teammate:**

```
You are the A11y teammate for Phase 5 Tasks/Timeline.

Inputs:
- Spec Section 6 (Accessibility): VoiceOver announcements, contrast, 44pt targets
- docs/ACCESSIBILITY_AUDIT.md (color contrast, targets)
- Implemented UI: Tasks list, progress card, filters, task cards, checkboxes, parent banner, athlete switcher

Your job:
1. Ensure:
   - Checkbox: accessibilityLabel "Mark [Task title] complete" or "Complete [prerequisites] to unlock" as appropriate; accessibilityHint if needed.
   - Task card: combined label e.g. "[Task title], [Status], [Locked/Unlocked], [Required/Optional]".
   - Progress: "Completed X of Y tasks, Z percent complete".
   - Decorative icons (e.g. lock, badges) have accessibilityHidden(true) or are part of combined label.
   - All interactive elements have ≥44pt touch targets and semantic labels.
   - Color contrast meets WCAG AA (status green/yellow/gray, required badge, error/prerequisite red).
2. Add or update accessibility unit tests (e.g. in TheRecruitingCompassTests/Features/Tasks/Accessibility/) for labels and traits where applicable.
3. Optionally add E2E accessibility tests (e.g. InteractionAccessibilityE2ETests-style) for VoiceOver flow.
4. Run tests and build. Report: checklist of a11y items verified and any new a11y test files.
```

---

## Quick reference: where things live

| Asset              | Location |
|--------------------|----------|
| Spec               | `recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md` |
| Plan               | `docs/plans/2026-02-17-phase5-tasks-timeline.md` |
| Feature code       | `TheRecruitingCompass/Features/Tasks/` (Models, Services, ViewModels, Views, Components) |
| Unit tests         | `TheRecruitingCompassTests/Features/Tasks/` |
| E2E tests          | `TheRecruitingCompassUITests/Features/Tasks/` |
| Build/test         | `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'` and same with `test` |

---

## Running the full team

1. **Feature Implementer:** Use subagent-driven development on `docs/plans/2026-02-17-phase5-tasks-timeline.md` (Tasks 1–11). After each task: spec review → code quality review → mark complete.
2. **Unit Test:** Dispatch with the Unit Test Teammate prompt above; run test suite.
3. **E2E:** Dispatch with the E2E Teammate prompt; run UI tests.
4. **Refactor:** Dispatch with Refactor Teammate prompt; run build + tests.
5. **A11y:** Dispatch with A11y Teammate prompt; run tests and optionally manual VoiceOver.

You can run 2–4 in parallel after step 1; run 5 after 4 so a11y audits the final code.

---

## Master prompt: run the whole team in sequence

Copy the block below into a new chat to run all five teammates in order. The agent will execute Phase 1 (feature implementation with subagent-driven development), then Phase 2 (unit tests), Phase 3 (E2E tests), Phase 4 (refactor), and Phase 5 (a11y). After each phase, run the build/test commands listed and fix any failures before continuing.

```markdown
You are the controller for the Phase 5 Tasks/Timeline agent team. Run all five phases in strict sequence. Do not skip phases or move on while the current phase has failing build/tests or open review issues.

**Repo:** TheRecruitingCompass iOS (recruiting-compass-ios). Workspace root = project root.

**Authoritative docs (read when starting each phase):**
- Spec: `recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md` (or same path under the web repo if you have it)
- Plan: `docs/plans/2026-02-17-phase5-tasks-timeline.md`
- Agent team roles: `docs/AGENT_TEAM_Phase5_TasksTimeline.md`
- Project rules: `CLAUDE.md`, `docs/CODE_PATTERNS.md`

**Build/test commands (use iPhone 17 or iPhone 16 simulator as available):**
- Build: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
- Test: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`

---

**Phase 1 – Feature Implementer (subagent-driven development)**  
1. Read `docs/plans/2026-02-17-phase5-tasks-timeline.md` and extract all 11 tasks with full text and file paths.  
2. Create a TodoWrite with tasks 1–11.  
3. For each task (1 through 11):  
   - Implement the task: create/modify the files listed in the plan, follow the steps (TDD where specified). Use existing patterns from `Features/Offers` and `Features/Dashboard`. Context: MVVM, SwiftUI, Supabase; spec is iOS_SPEC_Phase5_TasksTimeline; web parity with pages/tasks/index.vue, useTasks.ts, gradeHelpers, deadlineHelpers.  
   - Self-review for spec compliance and code quality.  
   - Spec compliance review: confirm behavior matches the spec (models, filters, locking, parent mode, UI). Fix any gaps.  
   - Code quality review: naming, structure, no dead code. Fix any issues.  
   - Mark the task complete in TodoWrite.  
4. Run build and test. Fix failures. Then proceed to Phase 2.

**Phase 2 – Unit Test Teammate**  
1. Add or expand unit tests for: Task models (TaskStatus, DeadlineUrgency, AthleteTaskStatus, TaskSummary, TaskWithStatus), GradeLevelHelper, TasksServiceImpl (mocked), TasksListViewModel (filters, persistence, sorting, progress, markComplete, locked path, parent mode). Include edge cases (empty, all completed, nil deadline).  
2. Follow test style in TheRecruitingCompassTests (e.g. Features/Offers, Features/Notifications). Use mocks for TasksManaging and auth/family context.  
3. Run the test suite. Fix failures. Report test files added/updated and coverage summary. Then proceed to Phase 3.

**Phase 3 – E2E Test Teammate**  
1. Add E2E tests in TheRecruitingCompassUITests/Features/Tasks/ for: happy path (open Tasks, filters, expand/collapse, mark complete, success message); locked task (checkbox → alert, no change); parent mode (read-only banner, switcher, checkboxes disabled); empty state; error/recovery (retry or pull-to-refresh).  
2. Use patterns from Features/Offers and Features/Interactions UITests; prefer accessibility identifiers.  
3. Run the UI test target. Fix failures. Report E2E files and scenarios. Then proceed to Phase 4.

**Phase 4 – Refactor Teammate**  
1. Refactor `TheRecruitingCompass/Features/Tasks/`: remove dead code and unused imports; align naming with CLAUDE.md and CODE_PATTERNS; extract repeated logic into small helpers if it improves clarity. Keep ViewModels @MainActor and Services protocol-based. Do not change behavior.  
2. Run build and full test suite. Fix any regressions. Report what was simplified. Then proceed to Phase 5.

**Phase 5 – A11y Teammate**  
1. Ensure: checkbox labels ("Mark [Task] complete" / "Complete [prerequisites] to unlock"); task card combined label; progress announcement; decorative icons accessibilityHidden or in label; ≥44pt touch targets; WCAG AA contrast (status colors, badges, prerequisite red).  
2. Add or update accessibility unit tests in TheRecruitingCompassTests/Features/Tasks/Accessibility/. Optionally add E2E a11y tests.  
3. Run tests and build. Report a11y checklist and any new a11y test files.

**Done:** After Phase 5, run the full test suite one more time and report: "Phase 5 Tasks/Timeline agent team complete. All phases run in sequence; build and tests passing."
```
