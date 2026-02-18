# Event Detail - Phase 6 Implementation Plan

**Created:** 2026-02-17
**Branch:** `feature/event-detail-phase6`
**Spec:** `/planning/iOS_SPEC_Phase6_EventDetail.md` (in recruiting-compass-web)
**Status:** In progress

## ⚠️ Critical Project Note

**This project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16 feature).**
- New .swift files placed on disk are **automatically included** in the build target
- Do NOT run `add_files_to_xcode.rb` — it corrupts the project file
- SourceKit "Cannot find type in scope" errors during active builds are **false positives** (build DB lock)
- Verify real errors with `xcodebuild build` only

**Git worktrees:** Always work in `.worktrees/event-detail-phase6/`, never in the main checkout.

---

## Codebase Context

**Project root:** `TheRecruitingCompass/TheRecruitingCompass/`
**Events feature:** `Features/Events/`
**Tests:** `TheRecruitingCompassTests/Features/Events/`
**UI Tests:** `TheRecruitingCompassUITests/Features/Events/`

### What Already Exists

| File | Status |
|------|--------|
| `Features/Events/Models/FullEvent.swift` | Exists — missing `coachesPresent` |
| `Features/Events/Models/EventType.swift` | Exists — complete |
| `Features/Events/Models/EventSource.swift` | Exists — complete |
| `Features/Events/Models/CreateEventData.swift` | Exists — complete |
| `Features/Events/Services/EventsManaging.swift` | Exists — INCOMPLETE (only fetchEvents + deleteEvent) |
| `Features/Events/Services/EventsServiceImpl.swift` | Exists — INCOMPLETE (same) |
| `Features/Events/ViewModels/EventDetailViewModel.swift` | Exists — partial (load + directions only) |
| `Features/Events/Views/EventDetailView.swift` | Exists — partial (no CRUD, no coaches, no metrics) |
| `Features/Dashboard/Models/Coach.swift` | Exists — full Coach model (use this, don't duplicate) |
| `Features/Performance/Models/PerformanceMetric.swift` | Exists — full model with eventId |
| `TheRecruitingCompassTests/Mocks/MockEventsService.swift` | Exists — needs new method stubs |

### Protocol Inconsistency (Must Fix)
`EventsManaging.swift` only declares `fetchEvents(userId:)` and `deleteEvent(id:)` but `MockEventsService`
already implements `fetchEvent`, `createEvent`, `fetchSchools`, `createSchool`. The protocol needs
to be brought in sync before adding new methods.

---

## Tasks

### Task 1: Extend Models (Feature Dev)
**File changes:**
- `Features/Events/Models/FullEvent.swift` — add `coachesPresent: [String]?` with CodingKey `coaches_present`; update `.mock()` helper in test file
- NEW `Features/Events/Models/EventUpdateRequest.swift` — Encodable struct for Supabase update
- NEW `Features/Events/Models/EditEventData.swift` — UI form state (pre-filled from FullEvent)
- NEW `Features/Events/Models/InteractionData.swift` — form state + `InteractionType`, `InteractionDirection`, `InteractionSentiment` enums
- NEW `Features/Events/Models/NewMetricData.swift` — form state for metric logging
- NEW `Features/Events/Models/CreateMetricRequest.swift` — Encodable for Supabase insert
- NEW `Features/Events/Models/CreateInteractionRequest.swift` — Encodable for Supabase insert

**InteractionType cases:** `inPersonVisit`, `phoneCall`, `email`, `game`
**InteractionDirection cases:** `inbound`, `outbound`
**InteractionSentiment cases:** `veryPositive`, `positive`, `neutral`, `negative`

### Task 2: Extend Service Layer (Feature Dev)
**File changes:**
- `Features/Events/Services/EventsManaging.swift` — reconcile with Mock; add: `fetchEvent(id:)`, `updateEvent(id:request:)`, `fetchCoaches(schoolId:userId:)`, `fetchMetrics(eventId:userId:)`, `createMetric(request:)`, `createInteraction(request:)`
- `Features/Events/Services/EventsServiceImpl.swift` — implement all new protocol methods with Supabase
- `TheRecruitingCompassTests/Mocks/MockEventsService.swift` — add stubs for all new methods

**Supabase calls:**
```swift
// fetchEvent
.from("events").select().eq("id", eventId).eq("user_id", userId).single()

// updateEvent
.from("events").update(request).eq("id", id).select().single()

// fetchCoaches (returns [Coach] from Dashboard/Models/Coach)
.from("coaches").select("id,first_name,last_name,position,email,phone,school_id").eq("school_id", schoolId).eq("user_id", userId)

// fetchMetrics (returns [PerformanceMetric] from Performance/Models/PerformanceMetric)
.from("performance_metrics").select().eq("event_id", eventId).eq("user_id", userId)

// createMetric
.from("performance_metrics").insert([request]).select().single()

// createInteraction
.from("interactions").insert([request]).select().single()
```

### Task 3: Extend EventDetailViewModel (Feature Dev)
**File changes:**
- `Features/Events/ViewModels/EventDetailViewModel.swift` — major expansion

**New state to add:**
```swift
var schoolCoaches: [Coach] = []
var eventMetrics: [PerformanceMetric] = []
var showEditForm = false
var showMetricForm = false
var showQuickLogModal = false
var showAddCoach = false
var isUpdating = false
var metricLoading = false
var selectedCoachId: String?
var editFormData = EditEventData()
var newMetric = NewMetricData()
var quickLogData = InteractionData()
```

**New methods to add:**
```swift
func markAsAttended() async          // update attended=true, then showQuickLogModal=true
func updateEvent() async              // validate editFormData, call service, refresh
func deleteEvent() async              // call service, set isDeleted=true for navigation
func addCoachPresent() async          // add selectedCoachId to event.coachesPresent
func removeCoachPresent(coachId:) async
func fetchSchoolCoaches() async       // called when event.schoolId != nil
func loadMetrics() async
func logMetric() async
func logInteraction() async           // creates interaction, closes modal
func prepareEditForm()                // populates editFormData from current event
```

**New computed:**
```swift
var availableCoaches: [Coach]         // schoolCoaches minus already-present IDs
var coachesAtEvent: [Coach]           // schoolCoaches filtered by coachesPresent IDs
var isDeleted: Bool                   // signals view to pop navigation
```

### Task 4: Update EventDetailView + Create Components (Feature Dev)
**File changes:**
- `Features/Events/Views/EventDetailView.swift` — add all new sections + modal presentations
- NEW `Features/Events/Components/EventActionButtonsRow.swift`
- NEW `Features/Events/Components/EditEventSheet.swift`
- NEW `Features/Events/Components/QuickLogInteractionModal.swift`
- NEW `Features/Events/Components/CoachesPresentSection.swift`
- NEW `Features/Events/Components/AddCoachSheet.swift`
- NEW `Features/Events/Components/MetricsSection.swift`
- NEW `Features/Events/Components/LogMetricForm.swift`

**Key behaviors:**
- "Mark Attended" button: only visible if `!event.attended`; calls `markAsAttended()`
- "Edit" button: calls `prepareEditForm()` then sets `showEditForm = true`
- "Delete" button: shows confirmation alert; on confirm calls `deleteEvent()`
- Navigation pop on delete: use `@Environment(\.dismiss)` triggered by `viewModel.isDeleted`
- EditEventSheet: full-screen sheet; pre-fills from `viewModel.editFormData`
- QuickLogInteractionModal: overlay presentation; prompted after marking attended
- CoachesPresentSection: shows `viewModel.coachesAtEvent`; "+ Add Coach" only if schoolId exists
- MetricsSection: shows `viewModel.eventMetrics`; inline LogMetricForm expands on tap

---

## Unit Tests Scope

**File:** `TheRecruitingCompassTests/Features/Events/ViewModels/EventDetailViewModelTests.swift`
(extend existing file)

Tests to add:
- `testMarkAsAttended_success_setsAttendedAndShowsModal()`
- `testMarkAsAttended_failure_setsError()`
- `testUpdateEvent_success_refreshesEvent()`
- `testUpdateEvent_failure_setsError()`
- `testDeleteEvent_success_setsIsDeleted()`
- `testDeleteEvent_failure_setsError()`
- `testAddCoachPresent_addsCoachToEvent()`
- `testRemoveCoachPresent_removesCoachFromEvent()`
- `testFetchSchoolCoaches_populatesSchoolCoaches()`
- `testLoadMetrics_populatesEventMetrics()`
- `testLogMetric_success_addsToMetricsList()`
- `testLogInteraction_success_closesModal()`
- `testAvailableCoaches_excludesPresentCoaches()`
- `testCoachesAtEvent_returnsOnlyPresentCoaches()`

Also update `MockEventsService` in Tests/Mocks/ for new protocol methods.

---

## E2E Tests Scope

**File:** NEW `TheRecruitingCompassUITests/Features/Events/EventDetailE2ETests.swift`

Tests:
- Happy path: view loads event details
- Happy path: mark as attended → quick log modal appears → log interaction
- Happy path: edit event → save changes
- Happy path: add coach → appears in list
- Happy path: remove coach → removed from list
- Happy path: log metric → appears in metrics list
- Error: delete event → confirmation → navigates back

---

## Accessibility Scope

Per spec section 6 Accessibility requirements:
- Event header: announces "[Event name], [Type], [Date], [Status]"
- Action buttons: "Mark as attended", "Edit event", "Delete event"
- Metric card: "[Metric label], [Value] [Unit], [Verified/Not verified]"
- Coach card: "[Name], [Role], [Email], [Phone]"
- All interactive elements: 44pt minimum touch target
- WCAG AA contrast: 4.5:1 minimum

---

## Refactor Scope

After feature complete:
- Ensure EventDetailView is < 400 lines (extract into Components)
- DRY up any repeated Section/Label patterns
- Ensure consistent error handling style across new methods

---

## Dependencies Between Teammates

```
Feature Dev Task 1 (Models)
    → Unit Tests can start writing model tests
Feature Dev Task 2 (Services)
    → Unit Tests can write service/protocol tests
    → Update MockEventsService for unit tests
Feature Dev Task 3 (ViewModel)
    → Unit Tests write ViewModel tests
Feature Dev Task 4 (Views)
    → E2E Tests can begin
    → A11y can audit
    → Refactor can clean up
```
