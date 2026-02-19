# Recruiting Timeline Implementation Plan — iOS

**Purpose:** Implement the web app's Recruiting Timeline (`/timeline`) in the iOS app to achieve feature parity and deliver the core value of the 4-year recruiting roadmap.

**Web Reference:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/pages/timeline/index.vue`

**Date:** February 2026

---

## Executive Summary

The Recruiting Timeline is a key differentiator: a phase-based (Freshman → Senior) view of recruiting tasks with status scoring and contextual guidance. The iOS app already has a **Tasks** feature (flat list, single grade) but lacks the phase-based structure, status score, and guidance sections that define the full Timeline experience. This plan outlines how to evolve the existing Tasks implementation into the full Recruiting Timeline.

---

## Current State Analysis

### Web Timeline (Source of Truth)

| Component | Description |
|-----------|-------------|
| **Phase cards** | Four collapsible cards: Freshman, Sophomore, Junior, Senior |
| **Current phase** | Derived from graduation year (user_preferences) |
| **Status score** | 0–100, label (on_track / slightly_behind / at_risk) |
| **Stat pills** | Status score, task completion, milestone completion |
| **Phase tasks** | Tasks grouped by `grade_level` (9–12) within each phase card |
| **Guidance sidebar** | What Matters Now, Upcoming Milestones, Common Worries, What Not To Stress |
| **Milestone progress** | Required tasks per phase; advancement when all complete |

### iOS Tasks (Current)

| Component | Status |
|-----------|--------|
| Tasks list | ✅ Flat list of tasks for one grade |
| Filters | ✅ Status, urgency |
| Task completion | ✅ Mark complete, locked-task handling |
| Parent preview | ✅ Read-only, athlete switcher |
| Phase cards | ❌ Missing |
| Status score | ❌ Missing |
| Guidance sections | ❌ Missing |
| All 4 grades visible | ❌ Single grade only |
| Graduation year | ⚠️ Optional `graduationYear` on ViewModel; needs user prefs |

### Data Layer Comparison

| Data | Web API | iOS (Supabase) |
|------|---------|----------------|
| Tasks | `GET /api/tasks` (optional gradeLevel) | `tasks` table, `.eq("grade_level", gradeLevel)` |
| Athlete tasks | `GET /api/athlete-tasks` | `athlete_tasks` (user_id) |
| Phase | `GET /api/athlete/phase` | ❌ Not implemented |
| Status score | `GET /api/athlete/status` | ❌ Not implemented |
| Graduation year | `user_preferences` (category: player) | ❌ Needs PlayerDetails/Preferences |

**Note:** Web uses `athlete_id`; iOS `athlete_tasks` may use `user_id`. Verify schema alignment.

---

## Implementation Phases

### Phase 1: Data Layer — Phase & Status APIs (2–3 days)

**Goal:** Fetch current phase and status score. iOS can call the web API (if available) or replicate logic via Supabase.

#### 1.1 Phase calculation

- **Source:** Web `GET /api/athlete/phase` or Supabase + local logic.
- **Inputs:** Graduation year from `user_preferences` (player category).
- **Outputs:** `phase` (freshman | sophomore | junior | senior | committed), `milestoneProgress` (required/completed/remaining task IDs), `canAdvance`.

**Tasks:**

- [ ] Add `TimelinePhaseManaging` protocol and `TimelinePhaseService`.
- [ ] Fetch `graduation_year` from `user_preferences` where `category = 'player'`.
- [ ] Implement phase-from-grade mapping (or call web API).
- [ ] Implement milestone progress using `PHASE_MILESTONES` (or server-side equivalent).
- [ ] Add `TimelinePhase` and `MilestoneProgress` models.

**Files to create/update:**

- `Features/Timeline/Models/TimelinePhase.swift`
- `Features/Timeline/Models/MilestoneProgress.swift`
- `Features/Timeline/Services/TimelinePhaseService.swift`
- `Features/Timeline/Protocols/TimelinePhaseManaging.swift`

#### 1.2 Status score

- **Source:** Web `GET /api/athlete/status` or Supabase + local calculation.
- **Outputs:** `score` (0–100), `label` (on_track | slightly_behind | at_risk), `breakdown`.

**Tasks:**

- [ ] Add `TimelineStatusManaging` protocol and `TimelineStatusService`.
- [ ] Call web API or replicate `POST /api/athlete/status/recalculate` logic.
- [ ] Add `StatusScore` model (`score`, `label`, `breakdown`).

**Files to create/update:**

- `Features/Timeline/Models/StatusScore.swift`
- `Features/Timeline/Services/TimelineStatusService.swift`
- `Features/Timeline/Protocols/TimelineStatusManaging.swift`

#### 1.3 Tasks for all grades

- **Current:** `TasksServiceImpl` fetches one `grade_level`.
- **Needed:** Fetch tasks for grades 9, 10, 11, 12.

**Tasks:**

- [ ] Extend `TasksManaging` with `fetchAllTasksWithStatus(athleteId:)` returning tasks for all grades (or call `fetchTasksWithStatus` 4 times and merge).
- [ ] Add grouping by `grade_level` for phase cards.

**Files to update:**

- `Features/Tasks/Services/TasksManaging.swift`
- `Features/Tasks/Services/TasksServiceImpl.swift`

---

### Phase 2: Timeline ViewModel (1–2 days)

**Goal:** Central ViewModel for the Recruiting Timeline that coordinates phase, status, and tasks.

#### 2.1 TimelineViewModel

- **Responsibilities:**
  - Load phase, status score, and tasks (all grades).
  - Compute `tasksByGrade: [Int: [TaskWithStatus]]` (9, 10, 11, 12).
  - Track expanded phase (Freshman, Sophomore, Junior, Senior).
  - Expose `currentPhase`, `statusScore`, `statusLabel`, `milestoneProgress`.
  - Call `updateTaskStatus` (reuse `TasksManaging`).

**Tasks:**

- [ ] Create `TimelineViewModel` (or extend `TasksListViewModel`).
- [ ] Inject `TimelinePhaseManaging`, `TimelineStatusManaging`, `TasksManaging`.
- [ ] Load phase, status, and tasks in parallel on init/refresh.
- [ ] Ensure graduation year is sourced from preferences (integrate with `PlayerDetailsView` or preferences).

**Files to create:**

- `Features/Timeline/ViewModels/TimelineViewModel.swift`

---

### Phase 3: Phase Cards & Stat Pills (2–3 days)

**Goal:** Replace flat task list with phase-based layout and stat pills.

#### 3.1 Stat pills (top of screen)

- Status score (e.g. 75/100, color by label).
- Task completion (X of Y).
- Milestone completion (X of Y for current phase).

**Reference:** `recruiting-compass-web/components/Timeline/TimelineStatPills.vue`

**Tasks:**

- [ ] Create `TimelineStatPills` component.
- [ ] Wire to `TimelineViewModel.statusScore`, `statusLabel`, `taskCompletedCount`, `taskTotalCount`, `milestonesCompletedCount`, `milestonesTotalCount`.

#### 3.2 Phase cards

- One card per phase: Freshman (9), Sophomore (10), Junior (11), Senior (12).
- Each card: phase title, theme, task count (X/Y), expand/collapse, task list when expanded.
- Current phase visually highlighted.

**Reference:** `recruiting-compass-web/components/Timeline/PhaseCardInline.vue`

**Tasks:**

- [ ] Create `PhaseCard` (SwiftUI) with header (title, theme, stats, chevron), expandable body, task list.
- [ ] Create `PhaseCardTaskRow` (reuse or adapt `TaskCard`).
- [ ] Handle task toggle (complete/incomplete) and locked-task alert.

**Files to create:**

- `Features/Timeline/Components/TimelineStatPills.swift`
- `Features/Timeline/Components/PhaseCard.swift`
- `Features/Timeline/Components/PhaseCardTaskRow.swift` (or extend `TaskCard`)

---

### Phase 4: Guidance Sidebar (1–2 days)

**Goal:** Add “What Matters Now” and optionally other guidance sections.

#### 4.1 What Matters Now

- List of priority tasks for current phase (incomplete, required, with `why_it_matters`).
- Tapping a priority scrolls to and highlights the task in the phase card.

**Reference:** `recruiting-compass-web/utils/whatMattersNow.ts`, `components/Timeline/WhatMattersNow.vue`

**Tasks:**

- [ ] Port `getWhatMattersNow` logic to Swift (or fetch from API if available).
- [ ] Create `WhatMattersNowSection` component.
- [ ] Implement scroll-to-task and highlight on tap (using `ScrollViewReader` + `data-task-id` or similar).

#### 4.2 Optional: Upcoming Milestones, Common Worries, What Not To Stress

- Can be added later for full parity.
- Reuse web logic in `getUpcomingMilestones`, `getCommonWorries`, `getReassuranceMessages`.

---

### Phase 5: Navigation & Rename (0.5 day)

**Goal:** Expose Timeline as the primary entry point and align naming.

**Tasks:**

- [ ] Add `RecruitingTimelineView` (or rename `TasksListView` to `TimelineView`).
- [ ] Update tab bar: label “Timeline” (or “Recruiting Timeline”), icon (e.g. `clock` to match web).
- [ ] Ensure navigation title is “Recruiting Timeline”.
- [ ] Update `MainTabView` and any deep links.

---

### Phase 6: Graduation Year & Preferences (0.5–1 day)

**Goal:** Use graduation year from user preferences so phase is correct.

**Tasks:**

- [ ] Ensure `user_preferences` (player) stores `graduation_year`.
- [ ] Fetch graduation year in `TimelineViewModel` (or `PlayerDetailsView`/preferences service).
- [ ] Pass `graduationYear` into phase calculation.
- [ ] Handle missing graduation year (default to freshman or prompt setup).

---

### Phase 7: Testing & Accessibility (1–2 days)

**Tasks:**

- [ ] Unit tests for `TimelinePhaseService`, `TimelineStatusService`, `TimelineViewModel`.
- [ ] Update E2E tests for Timeline flow (expand phase, complete task, guidance tap).
- [ ] Accessibility: VoiceOver labels, 44pt touch targets, semantic structure.
- [ ] Ensure guidance sections and phase cards have proper `accessibilityLabel` and `accessibilityHint`.

---

## File Structure (Proposed)

```
Features/
├── Timeline/                          # New feature module
│   ├── Models/
│   │   ├── TimelinePhase.swift
│   │   ├── MilestoneProgress.swift
│   │   └── StatusScore.swift
│   ├── Services/
│   │   ├── TimelinePhaseService.swift
│   │   └── TimelineStatusService.swift
│   ├── Protocols/
│   │   ├── TimelinePhaseManaging.swift
│   │   └── TimelineStatusManaging.swift
│   ├── ViewModels/
│   │   └── TimelineViewModel.swift
│   ├── Views/
│   │   └── RecruitingTimelineView.swift
│   └── Components/
│       ├── TimelineStatPills.swift
│       ├── PhaseCard.swift
│       ├── WhatMattersNowSection.swift
│       └── ...
├── Tasks/                             # Existing; extend as needed
│   ├── Services/
│   │   └── TasksServiceImpl.swift     # Add fetchAllTasksWithStatus or multi-grade fetch
│   └── ...
```

---

## API / Supabase Alignment

### Option A: Use web API (if available to iOS)

- `GET /api/athlete/phase`
- `GET /api/athlete/status`
- `GET /api/tasks` (no grade filter → all tasks)
- `GET /api/athlete-tasks`
- `PATCH /api/athlete-tasks/[taskId]`

Requires: base URL, auth token forwarding.

### Option B: Direct Supabase (current pattern)

- `user_preferences` → graduation_year
- `tasks` → fetch for grade_level in (9,10,11,12) or 4 separate queries
- `athlete_tasks` (or `athlete_task`) → filter by user_id/athlete_id
- Phase calculation and status score done client-side (port web logic) or via Edge Function.

**Recommendation:** Use Supabase directly to match current iOS pattern unless a shared API is already in place.

---

## Milestones & Timeline

| Phase | Scope | Estimate |
|-------|-------|----------|
| 1 | Data: Phase + Status + All grades | 2–3 days |
| 2 | Timeline ViewModel | 1–2 days |
| 3 | Phase cards + Stat pills | 2–3 days |
| 4 | Guidance (What Matters Now) | 1–2 days |
| 5 | Navigation & naming | 0.5 day |
| 6 | Graduation year integration | 0.5–1 day |
| 7 | Testing & accessibility | 1–2 days |

**Total:** ~8–14 days (1.5–3 weeks)

---

## Success Criteria

- [ ] User sees four phase cards (Freshman, Sophomore, Junior, Senior).
- [ ] Current phase is derived from graduation year.
- [ ] Status score (0–100) and label are displayed.
- [ ] Tasks are grouped by phase; user can expand/collapse.
- [ ] Task completion updates UI and milestone progress.
- [ ] “What Matters Now” shows priority tasks and scroll-to-task works.
- [ ] Parent preview works (read-only, athlete switcher).
- [ ] Tab bar shows “Timeline” with appropriate icon.
- [ ] Accessibility and E2E tests pass.

---

## Dependencies & Risks

- **Graduation year:** Must be stored in preferences. If missing, phase defaults to freshman; consider onboarding flow.
- **Schema:** Confirm `athlete_tasks` vs `athlete_task` and `user_id` vs `athlete_id` between web and Supabase.
- **Web logic:** Phase milestones (`PHASE_MILESTONES`) and status weights need to be ported or kept in sync with web.

---

## References

- Web Timeline page: `recruiting-compass-web/pages/timeline/index.vue`
- Web types: `recruiting-compass-web/types/timeline.ts`
- Web composables: `useTasks.ts`, `usePhaseCalculation.ts`, `useStatusScore.ts`
- Web phase calculation: `recruiting-compass-web/utils/phaseCalculation.ts`
- Web What Matters Now: `recruiting-compass-web/utils/whatMattersNow.ts`
- iOS Tasks: `Features/Tasks/`
- iOS spec: `planning/iOS_SPEC_Phase5_TasksTimeline.md` (if present)
