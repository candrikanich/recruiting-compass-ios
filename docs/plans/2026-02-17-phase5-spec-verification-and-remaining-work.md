# Phase 5 Tasks/Timeline – Spec Verification & Remaining Work

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md`  
**Verified:** February 17, 2026  
**iOS repo:** recruiting-compass-ios

---

## 1. Verification Summary

The Phase 5 Tasks / Recruiting Timeline spec is **largely fully implemented**. The feature exists end-to-end: models, service, ViewModel, progress card, filters, task cards with expandable details, dependency locking, parent banner, success message, empty/loading/error states, and navigation. One spec-required item is missing: **athlete switcher on the Tasks screen when in parent mode**.

---

## 2. What Is Implemented (Spec Compliance)

| Spec section | Status | Notes |
|--------------|--------|--------|
| **Data models** | ✅ | `TaskStatus`, `TaskDeadlineUrgency`, `AthleteTaskStatus`, `TaskSummary`, `TaskWithStatus` with `isLocked`, `deadlineUrgency`, `statusColor`; Codable + snake_case keys |
| **Grade level** | ✅ | `GradeLevelHelper.calculateCurrentGrade(graduationYear:)` in Core/Utilities; tests for grade and month boundaries |
| **Service** | ✅ | `TasksManaging` with `fetchTasksWithStatus`, `updateTaskStatus`; `TasksServiceImpl` (Supabase tasks + athlete_tasks, prerequisites, `hasIncompletePrerequisites`) |
| **ViewModel** | ✅ | `TasksListViewModel`: tasks, filters, `filteredTasks` (required → urgency → alpha), progress (completed/total, %), `loadTasks`/`refresh`, `markComplete` (locked path no-op), `expandedTaskId`, `isViewingAsParent`, `currentAthleteId`; filter persistence via UserDefaults keyed by athleteId |
| **Progress card** | ✅ | "You've completed X of Y tasks (Z%)", blue bar 12pt height; a11y "Completed X of Y tasks, Z percent complete" |
| **Filter bar** | ✅ | Status + urgency pickers; persistence through ViewModel |
| **Task cards** | ✅ | Checkbox (locked → alert; unlocked → mark complete); locked/required/status badges; description preview; expand/collapse; 44pt targets; a11y labels |
| **Task detail section** | ✅ | "Why It Matters", "What Can Go Wrong"; when locked, prerequisites section with red-tint background and "Complete These First" |
| **Locked task tap** | ✅ | Checkbox on locked task shows alert "Complete Prerequisites First" with list of prerequisite task titles; no status change |
| **Parent banner** | ✅ | Tasks parent banner: "Viewing [Name]'s Tasks (Read-Only)" with eye icon and dismiss (exit preview) |
| **Parent read-only** | ✅ | Checkboxes disabled when `isViewingAsParent`; `markComplete` no-op in parent mode |
| **Success message** | ✅ | "Great job! 🎉" after mark complete; auto-dismiss ~3s |
| **Empty state** | ✅ | "No tasks available for this grade level" |
| **Loading state** | ✅ | 5 skeleton placeholders when loading and tasks empty |
| **Error + retry** | ✅ | Error banner with Retry button; pull-to-refresh |
| **Navigation** | ✅ | Tasks tab in `MainTabView`; `TasksListView` with `.task { loadTasks }` and `.refreshable` |
| **Unit tests** | ✅ | TaskStatus, TaskDeadlineUrgency, AthleteTaskStatus, TaskSummary, TaskWithStatus, GradeLevelHelper, TasksServiceImpl (conformance), TasksListViewModel (filters, sorting, progress, markComplete, locked, parent mode) |
| **E2E / a11y** | ✅ | TasksListE2ETests, TasksListScreenObject; TasksAccessibilityTests |

---

## 3. Gap: Athlete Switcher on Tasks (Parent Mode)

**Spec (Section 6 – Layout):**  
"Athlete Switcher (parent only) – Dropdown to switch between linked athletes"

**Plan (Task 8):**  
"When `isViewingAsParent`: show banner … and **athlete switcher**."

**Current behavior:**  
When a parent is viewing the Tasks screen in read-only mode, they see the parent banner and can exit preview (dismiss). They **cannot** switch to another linked athlete from the Tasks screen; they must leave Tasks (e.g. go to Dashboard) to change the selected athlete.

**Required behavior:**  
When `isViewingAsParent` is true on Tasks, show an athlete switcher (same pattern as Dashboard) so the parent can switch between linked athletes without leaving the Tasks screen. After switching, the Tasks list should refresh for the newly selected athlete.

---

## 4. Implementation Plan: Add Athlete Switcher to Tasks

Use existing patterns from `Features/Dashboard` and `FamilyManager`.

### 4.1 Reuse `AthleteSelector`

- **Component:** `TheRecruitingCompass/Features/Dashboard/Components/AthleteSelector.swift`
- **Inputs:** `athletes: [FamilyMember]`, `selectedAthleteId: String?`, `onSelect: (String) -> Void`
- **Source of truth:** `FamilyManager.shared`: `athletes` (linked athletes), `selectedAthleteId`, `selectAthlete(_:)`

No new component is required; use `AthleteSelector` on the Tasks screen when in parent mode.

### 4.2 Update `TasksListView`

**File:** `TheRecruitingCompass/Features/Tasks/Views/TasksListView.swift`

1. **Environment**  
   - Already uses `@Environment(FamilyManager.self) private var familyManager`.

2. **When to show athlete switcher**  
   - When `viewModel.isViewingAsParent` is true **and** `familyManager.athletes.count > 1` (optional: show when `athletes.count >= 1` for consistency with Dashboard).

3. **Placement (spec order)**  
   - Layout order: Parent banner → Header ("My Tasks" / "[Name]'s Tasks") → **Athlete switcher (parent only)** → Progress card → Filter bar → Success message → Task list.  
   - Insert the athlete switcher section between the header and the progress card (or directly under the banner, matching Dashboard’s structure).

4. **Implementation**  
   - Add a private `@ViewBuilder` (e.g. `athleteSwitcherSection`) that:
     - Is only present when `viewModel.isViewingAsParent` (and optionally `!familyManager.athletes.isEmpty`).
     - Renders `AthleteSelector(athletes: familyManager.athletes, selectedAthleteId: familyManager.selectedAthleteId, onSelect: { familyManager.selectAthlete($0) })`.
   - In `onSelect`, after `familyManager.selectAthlete(athleteId)`:
     - Call `viewModel.loadTasks()` (or `viewModel.refresh()`) so the list and header update for the new athlete.  
   - Add this section into the main content stack in the correct order.

5. **Accessibility**  
   - Rely on `AthleteSelector`’s existing labels/hints; ensure the section has a logical accessibility order (e.g. after header, before progress).

### 4.3 ViewModel / data refresh

- **Option A (recommended):** Keep `TasksListViewModel` using `familyManager.selectedAthlete` and `currentAthleteId` as it does today. When the parent changes selection via `AthleteSelector`, `FamilyManager.selectAthlete(_:)` updates `selectedAthleteId`. The view must trigger a reload when the selected athlete changes:
  - In SwiftUI, observe `familyManager.selectedAthleteId` (or `familyManager.selectedAthlete`) and call `await viewModel.loadTasks()` when it changes (e.g. via `.onChange(of: familyManager.selectedAthleteId)`), or
  - Have the `onSelect` closure in the view call `Task { await viewModel.loadTasks() }` after `familyManager.selectAthlete(athleteId)` so the list refreshes immediately.
- **Option B:** Expose a method on the ViewModel that the view calls after switching (e.g. `viewModel.switchAthlete()` that just calls `loadTasks()`). Either way, ensure `loadTasks()` runs after selection change so `currentAthleteId` and the displayed tasks update.

### 4.4 Testing

- **Unit:** No ViewModel signature change required if the view simply calls `viewModel.loadTasks()` (or `refresh()`) after `selectAthlete`. If you add a dedicated method, add a test that switching triggers a load (e.g. with a mock service).
- **E2E:** Add or extend a parent-mode scenario: parent on Tasks, multiple linked athletes, use athlete switcher to select another athlete; assert header (or list) updates to the new athlete’s name/tasks (e.g. via accessibility label or visible text).
- **Manual:** Parent account, two+ linked athletes, open Tasks in preview, switch athlete and confirm list and title update.

### 4.5 Files to touch

| File | Change |
|------|--------|
| `TheRecruitingCompass/Features/Tasks/Views/TasksListView.swift` | Add athlete switcher section when `isViewingAsParent`; call `familyManager.selectAthlete` and refresh (e.g. `viewModel.loadTasks()`) on select; place section per spec order. |
| `TheRecruitingCompassUITests/Features/Tasks/TasksListE2ETests.swift` (or equivalent) | Add/extend test: parent mode, switch athlete, verify list/header updates. |
| (Optional) `TasksListViewModel` | If you prefer a dedicated `refreshForCurrentAthlete()` or similar, add and call from view on athlete change. |

### 4.6 Optional spec polish (low priority)

- **Banner copy:** Spec shows a single-line banner "👁 Viewing [Athlete Name]'s Tasks (Read-Only)". Current banner has "Parent Preview Mode" plus "Viewing … (Read-Only)". For exact copy match, you could reduce to one line with 👁 and "Viewing [Name]'s Tasks (Read-Only)" in `TasksParentBanner`.
- **Prerequisites section:** Spec mentions "🔒 Complete These First". You could add the lock character to the prerequisites heading in `TaskDetailSection` when the task is locked.
- **Prerequisite list:** Spec says "Lists incomplete prerequisite tasks". Implementation shows `task.prerequisiteTasks` when locked; if the API or backend only returns incomplete prerequisites, no change. If it returns all and you need to show only incomplete, filter by current completion state (e.g. exclude tasks that are completed in `athleteTask` or equivalent) in the detail section.

---

## 5. Sign-Off

- **Spec compliance (excluding athlete switcher):** Verified; implementation matches the spec for models, API, filters, locking, progress, parent read-only, and UI states.
- **Remaining work:** Implement athlete switcher on Tasks when in parent mode per Section 4; optionally apply polish items in Section 4.6.
- **Patterns:** Reuse `AthleteSelector` and `FamilyManager`; keep ViewModel and service unchanged except optionally a small refresh hook; follow existing layout and a11y patterns from Dashboard and CLAUDE.md.
