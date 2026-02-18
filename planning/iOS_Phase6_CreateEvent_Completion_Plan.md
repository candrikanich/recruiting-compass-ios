# Implementation Plan: Create Event — Spec Completion (Phase 6)

**Date:** 2026-02-17
**Spec:** `iOS_SPEC_Phase6_CreateEvent.md`
**Status:** Core feature implemented; navigation integration + detail view missing

---

## Gap Analysis Summary

### ✅ Already Complete
- All data models (`CreateEventData`, `CreateEventRequest`, `EventType`, `EventSource`, `FullEvent`, `SchoolSummary`)
- Full service layer (`EventsManaging` protocol, `EventsServiceImpl` with Supabase)
- `CreateEventViewModel` — validation, auto-populate, school modals, directions
- `CreateEventView` — all 5 form sections, bottom bar, discard alert
- `OtherSchoolSheet` + `AddSchoolSheet` components
- 30+ unit tests, model tests, E2E tests, mock service, screen object

### ❌ Missing (Critical)
1. No `EventsListView` — `CreateEventView` has no navigation entry point
2. No Events tab in `MainTabView`
3. No `EventDetailView` — no navigation target after successful creation
4. Missing `accessibilityIdentifier`s in `CreateEventView` — breaks all E2E tests

### ❌ Missing (Minor)
5. No URL format validation in `validateForm()`
6. Text fields instead of native date/time pickers (spec requires native pickers)

---

## Implementation Plan

### Phase 1: `accessibilityIdentifier`s in `CreateEventView` (30 min)
**Why first:** Unblocks all E2E tests. Low-risk targeted edits to existing file.

Add `.accessibilityIdentifier(...)` to match what `CreateEventScreenObject` expects:

| View Element | Expected Identifier |
|---|---|
| Event Type Picker | `"event-type-picker"` |
| Event Name TextField | `"event-name-field"` |
| School Picker | `"school-picker"` |
| Start Date picker | `"start-date-picker"` |
| End Date picker | `"end-date-picker"` |
| Start Time picker | `"start-time-picker"` |
| End Time picker | `"end-time-picker"` |
| Get Directions Button | `"get-directions-button"` |
| Create Event Button | `"create-event-button"` |
| Cancel Button | `"cancel-button"` |
| OtherSchoolSheet container | `"other-school-modal"` |
| AddSchoolSheet container | `"add-school-modal"` |
| Save School Button | `"save-school-button"` |

**Files:** `CreateEventView.swift`, `OtherSchoolSheet.swift`, `AddSchoolSheet.swift`

---

### Phase 2: URL Validation in ViewModel (20 min)
**Why second:** Isolated change to `validateForm()`, no UI changes required.

```swift
// In validateForm(), after endDate check:
if !formData.url.isEmpty {
    let trimmed = formData.url.trimmingCharacters(in: .whitespaces)
    if URL(string: trimmed) == nil || !trimmed.hasPrefix("http") {
        validationErrors["url"] = "Please enter a valid URL (e.g., https://...)"
    }
}
```

Add corresponding unit test to `CreateEventViewModelTests`.

**Files:** `CreateEventViewModel.swift`, `CreateEventViewModelTests.swift`

---

### Phase 3: `EventDetailView` + `EventDetailViewModel` (2-3 hrs)
**Why third:** Required as navigation target; `CreateEventView.onEventCreated` needs a destination.

**Architecture — follows established MVVM pattern:**

```
Features/Events/
├── Models/           (existing)
├── Services/
│   └── EventsManaging.swift   ← add fetchEvent(id:)
├── ViewModels/
│   └── EventDetailViewModel.swift   ← NEW
├── Views/
│   └── EventDetailView.swift        ← NEW
└── Components/
    └── EventInfoCard.swift           ← NEW (optional)
```

**`EventsManaging` protocol additions:**
```swift
func fetchEvent(id: String) async throws -> FullEvent
```

**`EventDetailViewModel` state:**
```swift
@Observable @MainActor
final class EventDetailViewModel {
    var event: FullEvent?
    var isLoading = false
    var error: String?

    func loadEvent(id: String) async
}
```

**`EventDetailView` sections:**
- Navigation title: event name
- Event Info card: type badge, date range, school
- Location card: address, city, state + Get Directions button
- Details card: description, registered/attended toggles (read-only display)
- Performance card: performance notes

**Tests:**
- `EventDetailViewModelTests.swift` — loadEvent success/failure, initial state
- `EventDetailView` row in `CreateEventE2ETests` — verify navigation after creation

---

### Phase 4: `EventsListView` + `EventsListViewModel` (2-3 hrs)
**Architecture — follows established MVVM + service pattern:**

```
Features/Events/
├── Services/
│   └── EventsManaging.swift   ← add fetchEvents(userId:)
├── ViewModels/
│   └── EventsListViewModel.swift    ← NEW
└── Views/
    └── EventsListView.swift         ← NEW
```

**`EventsManaging` protocol additions:**
```swift
func fetchEvents(userId: String) async throws -> [FullEvent]
```

**`EventsListViewModel` state:**
```swift
@Observable @MainActor
final class EventsListViewModel {
    var events: [FullEvent] = []
    var isLoading = false
    var error: String?
    var showCreateEvent = false

    func loadEvents() async
}
```

**`EventsListView` layout:**
- NavigationStack title: "Events"
- Toolbar: `+` button → sets `showCreateEvent = true` → `.navigationDestination`
- Content:
  - Empty state when no events (with "+ Add Event" prompt)
  - List of event cards sorted by `start_date` descending
  - Each row: event type badge, event name, date, school name
- Loading state: ProgressView
- Error state: error banner + retry button

**`EventsServiceImpl` additions:**
```swift
func fetchEvents(userId: String) async throws -> [FullEvent] {
    // .from("events").select().eq("user_id", userId).order("start_date", ascending: false)
}
```

**Navigation flow in EventsListView:**
```swift
.navigationDestination(isPresented: $viewModel.showCreateEvent) {
    CreateEventView(
        eventsService: EventsServiceImpl(),
        userId: userId,
        onEventCreated: { id in
            viewModel.showCreateEvent = false
            // Navigate to detail
        }
    )
}
```

**Tests:**
- `EventsListViewModelTests.swift` — loadEvents success/failure, empty state
- `MockEventsService` — add `fetchEvents` + `fetchEvent` methods

---

### Phase 5: Add Events Tab to `MainTabView` (15 min)
Add Events tab after Schools, before Interactions (logical ordering):

```swift
NavigationStack {
    EventsListView()
}
.tabItem {
    Label("Events", systemImage: "calendar")
}
.accessibilityLabel("Events")
```

**File:** `MainTabView.swift`

---

### Phase 6: Native Date/Time Pickers (1-2 hrs, UX polish)
Replace text field date/time inputs with native iOS `DatePicker`:

**Start Date (required):**
```swift
DatePicker("Start Date *", selection: $startDate, displayedComponents: .date)
    .accessibilityIdentifier("start-date-picker")
    .accessibilityLabel("Start date, required field")
```

**Time fields (optional — use `.sheet` picker pattern):**
Show a "None" state by default; tapping opens a sheet with `DatePicker(.hourAndMinute)`.

**ViewModel changes:**
- `formData.startDate: String` → `formData.startDate: Date?`
- Update `CreateEventRequest.from()` to format as ISO string
- Update `validateForm()` to use `Date` comparisons

**Note:** This is the most disruptive change. All unit tests that set string dates will need updating. Tackle last.

---

## Dependency Order

```
Phase 1 (identifiers)  →  No dependencies
Phase 2 (URL validation)  →  No dependencies
Phase 3 (EventDetailView)  →  Needs EventsManaging.fetchEvent (add to service)
Phase 4 (EventsListView)  →  Needs EventsManaging.fetchEvents + Phase 3 done
Phase 5 (MainTabView)  →  Needs Phase 4 done
Phase 6 (date pickers)  →  Independent but disruptive, do last
```

Phases 1 and 2 can be done in any order or in parallel.

---

## Files to Create (New)

| File | Type |
|---|---|
| `Features/Events/ViewModels/EventDetailViewModel.swift` | New |
| `Features/Events/Views/EventDetailView.swift` | New |
| `Features/Events/ViewModels/EventsListViewModel.swift` | New |
| `Features/Events/Views/EventsListView.swift` | New |
| `Tests/Features/Events/ViewModels/EventDetailViewModelTests.swift` | New |
| `Tests/Features/Events/ViewModels/EventsListViewModelTests.swift` | New |

---

## Files to Modify (Existing)

| File | Change |
|---|---|
| `Features/Events/Views/CreateEventView.swift` | Add `accessibilityIdentifier`s (Phase 1) |
| `Features/Events/Components/OtherSchoolSheet.swift` | Add `"other-school-modal"` identifier |
| `Features/Events/Components/AddSchoolSheet.swift` | Add `"add-school-modal"`, `"save-school-button"` identifiers |
| `Features/Events/Services/EventsManaging.swift` | Add `fetchEvents` + `fetchEvent` methods |
| `Features/Events/Services/EventsServiceImpl.swift` | Implement new protocol methods |
| `Features/Dashboard/Views/MainTabView.swift` | Add Events tab |
| `Tests/Mocks/MockEventsService.swift` | Add new method stubs |
| `Features/Events/ViewModels/CreateEventViewModel.swift` | Add URL validation (Phase 2) |
| `Tests/Features/Events/ViewModels/CreateEventViewModelTests.swift` | Add URL validation tests |

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `MainTabView` already has 12 tabs — Apple limits to 5 visible | Medium | Use `TabView` overflow scrolling (iOS 18) or merge Events into Dashboard |
| `CreateEventView` E2E tests use a screen object that navigates via tab — this path must work | High | Ensure tab + list view match the screen object's navigation expectations exactly |
| `EventsServiceImpl.fetchEvent` — RLS policies must allow single event read | Medium | Verify against existing `events` table RLS policy |
| Native date picker (Phase 6) breaks all date-related unit tests | High | Update tests as part of that phase; do not mix with other phases |

---

## Unresolved Questions

1. **Tab count:** `MainTabView` has 12 tabs. iOS 18 supports more tabs via "More" list, but earlier iOS shows a truncated "More" tab. Should Events replace an existing less-used tab or be added as the 13th?
2. **Event detail navigation from list:** Should the events list use `NavigationLink` (push) or sheet (modal) for event detail? The spec says navigate, implying push.
3. **EventsListView sorting/filtering:** The spec doesn't detail the list page. Sort by `start_date` descending? Add future/past grouping?
4. **Phase 6 date picker:** Are text fields acceptable as a short-term workaround, or should native pickers be implemented now?
