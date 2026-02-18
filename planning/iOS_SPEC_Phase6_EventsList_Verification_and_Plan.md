# Phase 6 Events List Spec — Verification & Completion Plan

**Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_EventsList.md`  
**Verified:** February 18, 2026  
**Codebase:** recruiting-compass-ios

---

## 1. Verification Summary

The Events List spec has been **largely implemented**. The following are in place and match the spec.

### Implemented (Spec Compliant)

| Spec Section | Requirement | Implementation |
|-------------|-------------|----------------|
| §1 Key actions | View events in calendar + list | `EventsListView` with `EventsCalendarView` + list sections (Upcoming / Past) |
| §1 | Navigate calendar by month | `EventsCalendarView` prev/next; `navigateToPreviousMonth` / `navigateToNextMonth` |
| §1 | Filter by type, status, date range | `typeFilter`, `statusFilter`, `dateRangeFilter` + filter bar with Clear Filters |
| §1 | Search by name, location, description | `.searchable(text: $viewModel.searchText)` + `filteredEvents` search logic |
| §1 | Sort by date, name, type | `sortBy` + sort picker and `filteredEvents` sorting |
| §1 | Navigate to event detail | `NavigationLink(value: event.id)` → `EventDetailView(eventId:)` |
| §1 | Create new event | Toolbar "+" → `CreateEventView`; post-create navigates to detail |
| §1 | Delete with confirmation | Swipe-to-delete + `confirmationDialog` ("Delete {name}?", "This action cannot be undone.") |
| §1 | Tap calendar date to scroll to event | `ScrollViewReader` + `onChange(of: viewModel.selectedCalendarDate)` → `scrollTo(id)` |
| §3 Data | Event model | `FullEvent` (Codable) with type, location, dates, registered, attended, cost, performanceNotes, etc. |
| §3 | EventType, EventSource | `EventType.swift`, `EventSource.swift` with displayName / badge behavior |
| §4 API | Fetch all events | `EventsManaging.fetchEvents(userId:)`, `EventsServiceImpl` Supabase query |
| §4 | Fetch single, delete | `fetchEvent(id:)`, `deleteEvent(id:)` in protocol and service |
| §5 State | Filters, calendar, sort state | All in `EventsListViewModel` (@Observable); `filteredEvents`, `calendarDays`, `hasEvent(on:)`, etc. |
| §6 Layout | Calendar card | Month header, prev/next, 7-column grid, event dots, today highlight |
| §6 | Filters card, results count, sort bar | Filter section, "X results" + sort picker |
| §6 | Event cards | Type/status badges, name, date, time, location, cost, performance notes; delete via swipe |
| §6 | Empty state (no events) | `ContentUnavailableView` "No Events Yet" + "Add Event" CTA |
| §6 | Empty filtered state | "No Matching Events" + "Clear Filters" when filters active; search empty state otherwise |
| §6 | Error + retry | Alert with error message + Retry / OK; pull-to-refresh |
| §6 | Loading | ProgressView when loading and list empty |
| §6 Accessibility | Calendar VoiceOver | "Calendar showing {title}"; day cells "Has events" / "No events"; 44pt targets |
| §6 | Add event / filter labels | Toolbar "Add new event"; pickers with accessibilityLabel |
| §8 | Delete confirmation | Confirmation dialog before delete |
| Navigation | Events in app | `MainTabView` — Events tab shows `EventsListView()` |

### Gaps

| # | Gap | Spec Reference | Status |
|---|-----|----------------|--------|
| 1 | Sort order persisted in UserDefaults | §5 | ✅ Done — `_sortBy` + getter/setter |
| 2 | Calendar ±2-year navigation limit | §8 | ✅ Done — `referenceDate()` + bounds check |
| 3 | Event row VoiceOver includes status | §6 | ✅ Done — `rowAccessibilityLabel` |
| 4 | Haptic feedback on delete | §6 | ✅ Done — impact + notification |
| 5 | Events List accessibility tests | §9 | ✅ Done — `EventsListAccessibilityTests.swift` |
| 6 | **Timeline Status Snippet** | §6 Layout | Deferred* |

\* No Timeline/Phase indicator component exists elsewhere in the app; defer until the component and data source exist.

---

## 2. Completion Plan (Using Established Patterns)

The following tasks use the same architecture (MVVM, protocol-based services, existing test patterns) and can be implemented in order. Existing plans with step-by-step code already exist in:

- `planning/2026-02-18-events-list-completion.md` (initial list + calendar implementation)
- `docs/plans/2026-02-18-events-list-spec-completion.md` (persistence, calendar limit, a11y, haptics, tests)

Below is a single consolidated plan; each task can be executed independently.

---

### Task 1: Persist sort order in UserDefaults

**Spec:** §5 State Management — "Selected sort order persists in UserDefaults"

**Files:**  
- `TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift`  
- `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

**Steps:**

1. Add unit tests: (1) set `sortBy = .name`, recreate ViewModel, assert `sortBy == .name`; (2) clear UserDefaults key, create fresh ViewModel, assert `sortBy == .dateDesc`.
2. Persist sort: **Do NOT use `@AppStorage`** — it does not work in `@Observable` classes (requires SwiftUI View). Use a backing var + getter/setter that writes to `UserDefaults.standard` in the setter, and read the saved value in init.
3. In test teardown (or in the default test), clear `UserDefaults.standard.removeObject(forKey: "eventsSortBy")` so other tests are not affected.
4. Run `EventsListViewModelTests` and full test suite.

**Reference:** `docs/plans/2026-02-18-events-list-spec-completion.md` Task 1.

---

### Task 2: Limit calendar navigation to ±2 years

**Spec:** §8 Edge Cases — "Calendar navigation to far future/past: Limit to ±2 years from current month"

**Files:**  
- `TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift`  
- `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

**Steps:**

1. Add tests: (1) call `navigateToPreviousMonth()` 25 times, assert `currentMonth` equals start-of-month for (today - 2 years); (2) same for `navigateToNextMonth()` and (today + 2 years).
2. Add `referenceDate()` returning first day of current month (for limit comparison).
3. In `navigateToPreviousMonth()`: compute `limit = referenceDate() - 2 years`; only set `currentMonth = currentMonth - 1 month` if `currentMonth > limit`.
4. In `navigateToNextMonth()`: compute `limit = referenceDate() + 2 years`; only set `currentMonth = currentMonth + 1 month` if `currentMonth < limit`.
5. Run EventsListViewModelTests and full suite.

**Reference:** `docs/plans/2026-02-18-events-list-spec-completion.md` Task 2.

---

### Task 3: Include status in event row accessibility label

**Spec:** §6 Accessibility — Event card VoiceOver: "[Event name], [Type], [Date], [Status]."

**Files:**  
- `TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Steps:**

1. In `rowAccessibilityLabel(_ event:)`, add status: `attended ? "Attended" : registered ? "Registered" : "Not Registered"` and append to the returned string, e.g. `"\(type): \(event.name), \(event.startDate), \(status)"`.
2. Build and run; verify with VoiceOver (Cmd+F5 in Simulator) if desired.

**Reference:** `docs/plans/2026-02-18-events-list-spec-completion.md` Task 3.

---

### Task 4: Haptic feedback for delete

**Spec:** §6 Accessibility — "Light impact on button tap, notification on delete"

**Files:**  
- `TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Steps:**

1. When user triggers delete (swipe action that sets `eventToDelete`): call `UIImpactFeedbackGenerator(style: .light).impactOccurred()`.
2. When user confirms delete in the confirmation dialog (destructive button): call `UINotificationFeedbackGenerator().notificationOccurred(.warning)` before calling `viewModel.deleteEvent(id:)`.
3. Build; no new unit tests required (UI behavior).

**Reference:** `docs/plans/2026-02-18-events-list-spec-completion.md` Task 4.

---

### Task 5: Events List accessibility tests

**Spec:** §9 Testing Checklist — "VoiceOver announces all elements correctly"

**Files:**  
- **Create:** `TheRecruitingCompassTests/Features/Events/Accessibility/EventsListAccessibilityTests.swift`

**Steps:**

1. Follow the pattern in `EventDetailAccessibilityTests.swift`: test accessibility-related outputs (labels, display names) rather than raw view hierarchy, unless the project uses ViewInspector.
2. Add tests for: (1) `EventsListViewModel.currentMonthTitle` contains current year and is non-empty (calendar label); (2) `EventType` display names (Camp, Showcase, Official Visit, Unofficial Visit, Game); (3) `StatusFilter` and `SortOption` and `DateRangeFilter` raw values are non-empty and human-readable (used in picker labels). These document spec §6 and guard regressions.
3. Run the new test target/class and full suite.

**Reference:** `docs/plans/2026-02-18-events-list-spec-completion.md` Task 5 (and Step 5.0 to confirm pattern from `EventDetailAccessibilityTests.swift`).

---

### Task 6 (Deferred): Timeline Status Snippet

**Spec:** §6 Layout — "[Header] Timeline Status Snippet (Phase indicator)"

**Decision:** Deferred. No shared Timeline/Phase component or data contract exists in the codebase. When a dashboard or shared "phase indicator" component and API exist, add it as the first section in `eventsContent` (above the calendar section).

---

## 3. Optional / Future Considerations (Spec §8–§10)

- **Event name truncation:** Spec suggests truncate at 60 characters; currently `EventRowView` uses `.lineLimit(2)`. Acceptable; add explicit 60-character truncation only if product requests it.
- **Large lists (100+ events):** Spec suggests pagination or virtual scrolling. Current implementation does not paginate. Add when needed; consider `LazyVStack` or list pagination in ViewModel + service.
- **statsRecorded:** Spec Event model has `statsRecorded: [String: Any]?`; not Codable. `FullEvent` omits it; leave as-is unless backend exposes a codable shape.

---

## 4. Sign-Off

- **Spec fully implemented?** Yes — Tasks 1–5 implemented; Task 6 deferred.
- **Implementation plan:** Tasks 1–5 complete; Task 6 deferred until Timeline/Phase component exists.
- **Build/test:** Run `make build` and `make test-unit` from repo root per CLAUDE.md. For Events-only: `-only-testing:TheRecruitingCompassTests/EventsListViewModelTests -only-testing:TheRecruitingCompassTests/EventsListAccessibilityTests`.
