# Phase 5: Tasks / Recruiting Timeline Implementation Plan

> **For Claude:** Use **subagent-driven development** to implement this plan: one subagent per task, spec compliance review then code quality review after each task. See `docs/AGENT_TEAM_Phase5_TasksTimeline.md` for the full agent team (Feature, Unit Tests, E2E, Refactor, A11y).

**Goal:** Implement the Tasks / Recruiting Timeline page: phase-based task list with dependency locking, status/urgency filters, progress tracking, and parent read-only mode.

**Architecture:** MVVM with protocol-based DI. Data: Supabase `tasks` + `athlete_tasks`. Grade from graduation year; deadline urgency and locking logic match web (`useTasks`, `gradeHelpers`, `deadlineHelpers`). Filters persist via `UserDefaults` keyed by athlete ID.

**Tech Stack:** SwiftUI, Supabase iOS SDK, Swift Concurrency, XCTest. iOS 15+.

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase5_TasksTimeline.md`  
**Web reference:** `recruiting-compass-web/pages/tasks/index.vue`, `composables/useTasks.ts`, `utils/gradeHelpers.ts`, `utils/deadlineHelpers.ts`

---

## Layer 1: Models & Utilities

### Task 1: Task status and deadline models

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Models/TaskStatus.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Models/DeadlineUrgency.swift` (reuse or extend `Offers/Models/DeadlineUrgency.swift` if identical)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Tasks/Models/TaskStatusTests.swift`, `DeadlineUrgencyTasksTests.swift` (if new)

**Steps:**
1. Add `TaskStatus` enum: `notStarted`, `inProgress`, `completed` (raw values `not_started`, `in_progress`, `completed`), `Codable`.
2. Add `DeadlineUrgency` for tasks: `critical`, `urgent`, `upcoming`, `future`, `none`; computed from `deadlineDate` (overdue or &lt;0 days → critical; ≤7 → urgent; ≤14 → upcoming; else future; nil → none).
3. Write failing unit tests for decoding and urgency calculation; implement; commit.

---

### Task 2: TaskWithStatus, AthleteTaskStatus, TaskSummary models

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Models/AthleteTaskStatus.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Models/TaskSummary.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Models/TaskWithStatus.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Tasks/Models/TaskWithStatusTests.swift`

**Steps:**
1. `AthleteTaskStatus`: Codable, `taskId`, `userId`, `status: TaskStatus`, `completedAt: Date?`.
2. `TaskSummary`: `id`, `title`, `Identifiable`.
3. `TaskWithStatus`: `id`, `title`, `description?`, `gradeLevel`, `category`, `division?`, `required`, `deadlineDate?`, `whyItMatters?`, `failureRisk?`, `dependencyTaskIds`, `athleteTask?`, `prerequisiteTasks`, `hasIncompletePrerequisites`; computed `isLocked` (= `hasIncompletePrerequisites`), `deadlineUrgency`, `statusColor` (green/yellow/gray per spec). Use snake_case coding keys where API returns snake_case.
4. Write tests for decoding API response and computed properties; implement; commit.

---

### Task 3: Grade level utility

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/GradeLevelHelper.swift` (or under `Features/Tasks/Utilities/` if preferred)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/GradeLevelHelperTests.swift`

**Steps:**
1. Implement `calculateCurrentGrade(graduationYear: Int) -> Int` matching web: school year Sept–June; `12 - (graduationYear - schoolYearEndYear)` clamped 9...12.
2. Add unit tests for freshman/sophomore/junior/senior and month boundaries; implement; commit.

---

## Layer 2: Service

### Task 4: Tasks service protocol and implementation

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Services/TasksManaging.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Services/TasksServiceImpl.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Tasks/Services/TasksServiceImplTests.swift`

**Steps:**
1. Protocol: `fetchTasksWithStatus(gradeLevel: Int, athleteId: String) async throws -> [TaskWithStatus]`, `updateTaskStatus(taskId: String, status: TaskStatus, userId: String) async throws -> AthleteTaskStatus`.
2. Implementation: query Supabase `tasks` (by grade_level or equivalent), join/fetch `athlete_tasks` for athlete, build `TaskWithStatus` with prerequisites and `hasIncompletePrerequisites`. For update: upsert `athlete_tasks`. Match web API shape if backend is shared (else match Supabase schema).
3. Write failing tests with mock Supabase or stub; implement; commit.

---

## Layer 3: ViewModel & state

### Task 5: TasksListViewModel

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/ViewModels/TasksListViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Tasks/ViewModels/TasksListViewModelTests.swift`

**Steps:**
1. @MainActor, @ObservableObject (or @Observable). Inject `TasksManaging`, `AuthManaging`, and family/parent context (e.g. `FamilyManager` or equivalent for `isViewingAsParent`, `currentAthleteId`, linked athletes).
2. State: `tasks`, `isLoading`, `errorMessage`, `currentGradeLevel`, `statusFilter`, `urgencyFilter`, `expandedTaskId`, `showSuccessMessage`, `isViewingAsParent`, `currentAthleteId` (for parent). Persist filters: `UserDefaults` keys `taskStatusFilter_\(athleteId)`, `taskUrgencyFilter_\(athleteId)`.
3. Methods: `loadTasks()`, `refresh()`, `setStatusFilter(_:)`, `setUrgencyFilter(_:)`, `toggleExpanded(taskId:)`, `markComplete(taskId:)` (check locked; on success set `showSuccessMessage`, refresh). Compute `filteredTasks` (by grade, status, urgency), sort: required first, then urgency, then alphabetical. Compute progress: completed/total, percentage.
4. Grade: from user profile graduation year via `GradeLevelHelper.calculateCurrentGrade`.
5. Write unit tests (mocked service and auth); implement; commit.

---

## Layer 4: UI components

### Task 6: Progress card and filter controls

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Components/TasksProgressCard.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Components/TasksFilterBar.swift`

**Steps:**
1. Progress card: "You've completed X of Y tasks (Z%)", progress bar (blue fill, gray background, 12pt height, rounded). Accessibility: "Completed X of Y tasks, Z percent complete".
2. Filter bar: Status picker (All, Not Started, In Progress, Completed), Urgency picker (All, Overdue/Due Soon, Due This Week, Due In 2 Weeks). Persist via ViewModel.
3. Add to Tasks view; commit.

---

### Task 7: Task card and expandable details

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Components/TaskCard.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Components/TaskDetailSection.swift`

**Steps:**
1. Task card: Checkbox (20pt min, enabled only if unlocked and athlete; parent mode disabled). Title, locked badge, required badge, status badge. Description preview. Tappable to expand/collapse. Accessibility: "Mark [Task] complete" or "Complete [prerequisites] to unlock"; "[Task title], [Status], [Locked/Unlocked], [Required/Optional]".
2. Detail section: "Why It Matters", "What Can Go Wrong". If locked: prerequisites section with red background, "Complete These First", list incomplete prerequisites.
3. Smooth expand/collapse animation. Commit.

---

### Task 8: Parent banner and athlete switcher

**Files:**
- Reuse: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ParentPreviewBanner.swift` (or Tasks-specific variant)
- Create or reuse: Athlete switcher for Tasks (e.g. same as Dashboard if in FamilyManager)

**Steps:**
1. When `isViewingAsParent`: show banner "Viewing [Athlete Name]'s Tasks (Read-Only)" and athlete switcher. Task checkboxes disabled.
2. Wire ViewModel to FamilyManager/parent context; commit.

---

### Task 9: Success message and empty/loading states

**Files:**
- In: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Views/TasksListView.swift`

**Steps:**
1. Transient success message "Great job! 🎉" (fades after ~3s) when athlete marks task complete.
2. Loading: skeleton cards (5 placeholders). Empty: "No tasks available for this grade level".
3. Error: banner with retry; pull-to-refresh. Commit.

---

## Layer 5: View and navigation

### Task 10: TasksListView and navigation

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Tasks/Views/TasksListView.swift`
- Modify: App tab or sidebar and route for Tasks (e.g. `TheRecruitingCompassApp` or main navigation)

**Steps:**
1. Compose: Parent banner (if parent) → Header ("My Tasks" / "[Name]'s Tasks") → Athlete switcher (parent) → Progress card → Filter bar → Success message → Task list (sorted). Pull-to-refresh, `.task { await viewModel.loadTasks() }`.
2. Add Tasks to app navigation/tab; commit.

---

## Layer 6: Integration and edge cases

### Task 11: Locked task tap and completion validation

**Files:**
- Modify: `TaskCard`, `TasksListViewModel`

**Steps:**
1. Tapping checkbox on locked task: show alert with incomplete prerequisites list; do not change status.
2. Ensure dependency logic matches web (all prerequisite tasks completed before unlock). Commit.

---

## Handoff to agent team

After **Task 11** is done:
- **Unit Test teammate:** Add/expand unit tests for ViewModel, service, models, filters, sorting, and locking (see `AGENT_TEAM_Phase5_TasksTimeline.md`).
- **E2E teammate:** Add E2E tests for load, filters, mark complete, expand details, parent mode, error/empty (see agent team doc).
- **Refactor teammate:** Simplify and deduplicate; remove dead code; align naming and patterns with CLAUDE.md.
- **A11y teammate:** VoiceOver labels, traits, 44pt targets, contrast; run accessibility tests and audit (see agent team doc).

Reference: **Spec** `iOS_SPEC_Phase5_TasksTimeline.md`, **Web** `pages/tasks/index.vue`, `composables/useTasks.ts`, `utils/gradeHelpers.ts`, `utils/deadlineHelpers.ts`.
