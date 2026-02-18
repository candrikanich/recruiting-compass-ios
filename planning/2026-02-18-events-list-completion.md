# Events List Completion Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the Events List feature to fully satisfy iOS_SPEC_Phase6_EventsList.md, adding delete, date-range filter, sort, a calendar grid component, and enriched event cards.

**Architecture:** Follows existing MVVM strict separation — `EventsManaging` protocol for service layer, `@Observable @MainActor EventsListViewModel` for all state/logic, `EventsListView` delegates to sub-components. New calendar component is a pure SwiftUI view that receives data from the ViewModel; no direct service calls from views. All new ViewModel logic is covered by unit tests before the UI is wired.

**Tech Stack:** SwiftUI (iOS 17+ `@Observable`), Supabase iOS SDK, XCTest for unit tests, existing `MockEventsService` + `MockAuthManager` pattern.

---

## Reference Files

- Spec: `recruiting-compass-web/planning/iOS_SPEC_Phase6_EventsList.md`
- Current view: `TheRecruitingCompass/Features/Events/Views/EventsListView.swift`
- Current VM: `TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift`
- Protocol: `TheRecruitingCompass/Features/Events/Services/EventsManaging.swift`
- Service impl: `TheRecruitingCompass/Features/Events/Services/EventsServiceImpl.swift`
- Mock: `TheRecruitingCompassTests/Mocks/MockEventsService.swift`
- VM tests: `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

**All paths below are relative to `TheRecruitingCompass/TheRecruitingCompass/` (sources) or `TheRecruitingCompass/TheRecruitingCompassTests/` (tests).**

**Build command (run from `TheRecruitingCompass/` project dir):**
```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded|FAILED"
xcodebuild test  -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|passed|failed|FAILED"
```

---

## Task 1: Add `deleteEvent` to Service Layer

**Files:**
- Modify: `Features/Events/Services/EventsManaging.swift`
- Modify: `Features/Events/Services/EventsServiceImpl.swift`
- Modify: `TheRecruitingCompassTests/Mocks/MockEventsService.swift`

### Step 1: Add `deleteEvent` to the `EventsManaging` protocol

In `EventsManaging.swift`, append after `fetchSchools`:

```swift
func deleteEvent(id: String) async throws
```

Full file after change:
```swift
import Foundation

struct SchoolSummary: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let location: String?
}

protocol EventsManaging: Sendable {
  func createEvent(_ request: CreateEventRequest) async throws -> FullEvent
  func fetchEvent(id: String) async throws -> FullEvent
  func fetchEvents(userId: String) async throws -> [FullEvent]
  func fetchSchools(userId: String) async throws -> [SchoolSummary]
  func createSchool(name: String, location: String?, userId: String) async throws -> SchoolSummary
  func deleteEvent(id: String) async throws
}
```

### Step 2: Implement `deleteEvent` in `EventsServiceImpl`

Find the existing `EventsServiceImpl` class and append this method:

```swift
func deleteEvent(id: String) async throws {
  let client = SupabaseManager.shared.client
  try await client.from("events").delete().eq("id", value: id).execute()
}
```

### Step 3: Add `deleteEvent` stub to `MockEventsService`

Append to `MockEventsService`:

```swift
var deleteEventCallCount = 0
var lastDeleteEventId: String?
var shouldThrowDeleteEvent = false

func deleteEvent(id: String) async throws {
  deleteEventCallCount += 1
  lastDeleteEventId = id
  if shouldThrowDeleteEvent { throw URLError(.badServerResponse) }
}
```

### Step 4: Build to confirm no compile errors

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

### Step 5: Commit

```bash
git add TheRecruitingCompass/Features/Events/Services/EventsManaging.swift \
        TheRecruitingCompass/Features/Events/Services/EventsServiceImpl.swift \
        TheRecruitingCompassTests/Mocks/MockEventsService.swift
git commit -m "feat(events): add deleteEvent to EventsManaging protocol and service"
```

---

## Task 2: Add Delete, Date Range Filter, and Sort to `EventsListViewModel`

**Files:**
- Modify: `Features/Events/ViewModels/EventsListViewModel.swift`
- Modify: `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

### Step 2a: Write failing tests first

Add the following test methods to `EventsListViewModelTests`. Append each block inside the class, below the existing `testHasActiveFilters_withStatusFilter_returnsTrue` test:

```swift
// MARK: - Date Range Filter

func testFilteredEvents_byUpcoming_returnsOnlyFutureEvents() async {
  mockAuth.user = userMock(id: "user-1")
  let future = fullEventMock(id: "e1", name: "Future", startDate: "2099-01-01")
  let past = fullEventMock(id: "e2", name: "Past", startDate: "2020-01-01")
  mockService.stubbedEvents = [future, past]
  await sut.loadEvents()

  sut.dateRangeFilter = .upcoming

  XCTAssertEqual(sut.filteredEvents.count, 1)
  XCTAssertEqual(sut.filteredEvents.first?.name, "Future")
}

func testFilteredEvents_byPast_returnsOnlyPastEvents() async {
  mockAuth.user = userMock(id: "user-1")
  let future = fullEventMock(id: "e1", name: "Future", startDate: "2099-01-01")
  let past = fullEventMock(id: "e2", name: "Past", startDate: "2020-01-01")
  mockService.stubbedEvents = [future, past]
  await sut.loadEvents()

  sut.dateRangeFilter = .past

  XCTAssertEqual(sut.filteredEvents.count, 1)
  XCTAssertEqual(sut.filteredEvents.first?.name, "Past")
}

func testFilteredEvents_allDateRange_returnsAll() async {
  mockAuth.user = userMock(id: "user-1")
  let future = fullEventMock(id: "e1", startDate: "2099-01-01")
  let past = fullEventMock(id: "e2", startDate: "2020-01-01")
  mockService.stubbedEvents = [future, past]
  await sut.loadEvents()

  sut.dateRangeFilter = .all

  XCTAssertEqual(sut.filteredEvents.count, 2)
}

func testHasActiveFilters_withDateRangeFilter_returnsTrue() {
  sut.dateRangeFilter = .upcoming
  XCTAssertTrue(sut.hasActiveFilters)
}

func testClearFilters_resetsDateRangeFilter() {
  sut.dateRangeFilter = .upcoming
  sut.clearFilters()
  XCTAssertEqual(sut.dateRangeFilter, .all)
}

// MARK: - Sort

func testFilteredEvents_sortByDateAsc_sortsOldestFirst() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [
    fullEventMock(id: "e1", name: "Later", startDate: "2026-06-01"),
    fullEventMock(id: "e2", name: "Earlier", startDate: "2026-03-01")
  ]
  await sut.loadEvents()

  sut.sortBy = .dateAsc

  XCTAssertEqual(sut.filteredEvents.first?.name, "Earlier")
  XCTAssertEqual(sut.filteredEvents.last?.name, "Later")
}

func testFilteredEvents_sortByName_sortsAlphabetically() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [
    fullEventMock(id: "e1", name: "Zebra Camp"),
    fullEventMock(id: "e2", name: "Alpha Showcase")
  ]
  await sut.loadEvents()

  sut.sortBy = .name

  XCTAssertEqual(sut.filteredEvents.first?.name, "Alpha Showcase")
  XCTAssertEqual(sut.filteredEvents.last?.name, "Zebra Camp")
}

// MARK: - Delete

func testDeleteEvent_removesEventFromList() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [
    .mock(id: "e1", name: "Keep"),
    .mock(id: "e2", name: "Delete Me")
  ]
  await sut.loadEvents()

  await sut.deleteEvent(id: "e2")

  XCTAssertEqual(sut.events.count, 1)
  XCTAssertEqual(sut.events.first?.name, "Keep")
  XCTAssertEqual(mockService.deleteEventCallCount, 1)
  XCTAssertEqual(mockService.lastDeleteEventId, "e2")
}

func testDeleteEvent_onFailure_setsError() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [.mock(id: "e1", name: "Event")]
  await sut.loadEvents()
  mockService.shouldThrowDeleteEvent = true

  await sut.deleteEvent(id: "e1")

  XCTAssertEqual(sut.events.count, 1) // not removed on failure
  XCTAssertNotNil(sut.error)
}

func testDeleteEvent_callsServiceWithCorrectId() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [.mock(id: "abc-123", name: "Event")]
  await sut.loadEvents()

  await sut.deleteEvent(id: "abc-123")

  XCTAssertEqual(mockService.lastDeleteEventId, "abc-123")
}
```

### Step 2b: Run tests — confirm they FAIL

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "failed|error:|passed"
```

Expected: Multiple test failures about `dateRangeFilter`, `sortBy`, `deleteEvent` not found.

### Step 2c: Add enums and new state to `EventsListViewModel`

At the bottom of `EventsListViewModel.swift`, after the `StatusFilter` enum, add:

```swift
// MARK: - DateRangeFilter

enum DateRangeFilter: String, CaseIterable {
  case all = "All Dates"
  case upcoming = "Upcoming"
  case past = "Past"
  case thisMonth = "This Month"
  case nextMonth = "Next Month"
}

// MARK: - SortOption

enum SortOption: String, CaseIterable {
  case dateDesc = "Date (Newest First)"
  case dateAsc = "Date (Oldest First)"
  case name = "Name"
  case type = "Type"
}
```

In the `EventsListViewModel` class body, add these stored properties after `var statusFilter`:

```swift
var dateRangeFilter: DateRangeFilter = .all
var sortBy: SortOption = .dateDesc
```

### Step 2d: Update `filteredEvents` computed property

Replace the entire `filteredEvents` computed property body with:

```swift
var filteredEvents: [FullEvent] {
  var result = events

  if !searchText.isEmpty {
    let query = searchText.lowercased()
    result = result.filter {
      $0.name.lowercased().contains(query)
      || ($0.city?.lowercased().contains(query) ?? false)
      || ($0.description?.lowercased().contains(query) ?? false)
      || ($0.address?.lowercased().contains(query) ?? false)
    }
  }

  if let typeFilter {
    result = result.filter { $0.type == typeFilter.rawValue }
  }

  switch statusFilter {
  case .all: break
  case .attended: result = result.filter { $0.attended }
  case .registered: result = result.filter { $0.registered && !$0.attended }
  case .notRegistered: result = result.filter { !$0.registered && !$0.attended }
  }

  let today = isoToday()
  switch dateRangeFilter {
  case .all: break
  case .upcoming: result = result.filter { $0.startDate >= today }
  case .past: result = result.filter { $0.startDate < today }
  case .thisMonth:
    let prefix = String(today.prefix(7)) // "YYYY-MM"
    result = result.filter { $0.startDate.hasPrefix(prefix) }
  case .nextMonth:
    let nextMonthPrefix = isoNextMonthPrefix()
    result = result.filter { $0.startDate.hasPrefix(nextMonthPrefix) }
  }

  return result.sorted { a, b in
    switch sortBy {
    case .dateAsc: return a.startDate < b.startDate
    case .dateDesc: return a.startDate > b.startDate
    case .name: return a.name.localizedCompare(b.name) == .orderedAscending
    case .type: return a.type < b.type
    }
  }
}
```

### Step 2e: Update `hasActiveFilters` and `clearFilters`

Replace `hasActiveFilters`:
```swift
var hasActiveFilters: Bool {
  !searchText.isEmpty || typeFilter != nil || statusFilter != .all || dateRangeFilter != .all
}
```

Replace `clearFilters`:
```swift
func clearFilters() {
  searchText = ""
  typeFilter = nil
  statusFilter = .all
  dateRangeFilter = .all
}
```

### Step 2f: Add `deleteEvent` method and `isoNextMonthPrefix` helper

Append inside `EventsListViewModel`, after `clearFilters`:

```swift
func deleteEvent(id: String) async {
  do {
    try await eventsService.deleteEvent(id: id)
    events.removeAll { $0.id == id }
  } catch {
    logger.error("Failed to delete event \(id): \(error.localizedDescription)")
    self.error = "Failed to delete event. Please try again."
  }
}
```

Append inside `// MARK: - Private Helpers`, after `isoToday`:

```swift
private func isoNextMonthPrefix() -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM"
  guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date()) else {
    return ""
  }
  return formatter.string(from: nextMonth)
}
```

### Step 2g: Run tests — confirm they PASS

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "failed|error:|passed"
```

Expected: All tests pass.

### Step 2h: Commit

```bash
git add Features/Events/ViewModels/EventsListViewModel.swift \
        TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift
git commit -m "feat(events-list): add deleteEvent, dateRangeFilter, and sortBy to EventsListViewModel"
```

---

## Task 3: Wire Delete + Filter + Sort into `EventsListView`

**Files:**
- Modify: `Features/Events/Views/EventsListView.swift`

No new tests needed here (UI wiring only; ViewModel tests cover the logic).

### Step 3a: Add sort bar above event sections

In `eventsContent`, insert a `sortResultsBar` section before the conditional sections. Replace the `List` body:

```swift
private var eventsContent: some View {
  List {
    filterBar
    sortResultsBar

    if viewModel.filteredEvents.isEmpty {
      noResultsState
    } else {
      if !viewModel.upcomingEvents.isEmpty {
        Section("Upcoming") {
          ForEach(viewModel.upcomingEvents) { event in
            eventRow(event)
          }
        }
      }
      if !viewModel.pastEvents.isEmpty {
        Section("Past") {
          ForEach(viewModel.pastEvents) { event in
            eventRow(event)
          }
        }
      }
    }
  }
  .listStyle(.insetGrouped)
}
```

Add the new `sortResultsBar` view:

```swift
private var sortResultsBar: some View {
  Section {
    HStack {
      Text("\(viewModel.filteredEvents.count) result\(viewModel.filteredEvents.count == 1 ? "" : "s")")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Picker("Sort", selection: $viewModel.sortBy) {
        ForEach(SortOption.allCases, id: \.self) { option in
          Text(option.rawValue).tag(option)
        }
      }
      .pickerStyle(.menu)
      .accessibilityLabel("Sort events")
    }
  }
}
```

### Step 3b: Add date range filter to `filterBar`

In the existing `filterBar` section, add after the Status `Picker` and before the "Clear Filters" button:

```swift
Picker("Date Range", selection: $viewModel.dateRangeFilter) {
  ForEach(DateRangeFilter.allCases, id: \.self) { range in
    Text(range.rawValue).tag(range)
  }
}
.accessibilityLabel("Filter by date range")
```

### Step 3c: Add swipe-to-delete on event rows

Replace the `eventRow` method:

```swift
private func eventRow(_ event: FullEvent) -> some View {
  NavigationLink(value: event.id) {
    EventRowView(event: event)
  }
  .accessibilityLabel(rowAccessibilityLabel(event))
  .swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
      eventToDelete = event
    } label: {
      Label("Delete", systemImage: "trash")
    }
  }
}
```

Add `@State private var eventToDelete: FullEvent? = nil` to the `EventsListView` stored properties.

Add a confirmation dialog modifier on the outer `Group`:

```swift
.confirmationDialog(
  "Delete \(eventToDelete?.name ?? "event")?",
  isPresented: Binding(
    get: { eventToDelete != nil },
    set: { if !$0 { eventToDelete = nil } }
  ),
  titleVisibility: .visible
) {
  Button("Delete", role: .destructive) {
    if let event = eventToDelete {
      Task { await viewModel.deleteEvent(id: event.id) }
      eventToDelete = nil
    }
  }
  Button("Cancel", role: .cancel) { eventToDelete = nil }
} message: {
  Text("This action cannot be undone.")
}
```

### Step 3d: Update `noResultsState` to distinguish filter vs search

Replace `noResultsState`:

```swift
private var noResultsState: some View {
  Section {
    if viewModel.hasActiveFilters && viewModel.searchText.isEmpty {
      ContentUnavailableView {
        Label("No Matching Events", systemImage: "line.3.horizontal.decrease.circle")
      } description: {
        Text("No events match your current filters.")
      } actions: {
        Button("Clear Filters") { viewModel.clearFilters() }
          .buttonStyle(.bordered)
      }
    } else {
      ContentUnavailableView.search(text: viewModel.searchText)
    }
  }
}
```

### Step 3e: Build and verify

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

### Step 3f: Commit

```bash
git add Features/Events/Views/EventsListView.swift
git commit -m "feat(events-list): add sort bar, date range filter, swipe-to-delete with confirmation"
```

---

## Task 4: Enrich `EventRowView` with Time, Cost, and Performance Notes

**Files:**
- Modify: `Features/Events/Views/EventsListView.swift` (the `EventRowView` private struct at bottom)

No ViewModel changes; `FullEvent` already has `startTime`, `cost`, `performanceNotes` fields.

### Step 4a: Update `EventRowView.body`

Replace the `VStack` body in `EventRowView`:

```swift
var body: some View {
  VStack(alignment: .leading, spacing: 6) {
    HStack(spacing: 8) {
      typeBadge
      statusBadge
      Spacer()
    }

    Text(event.name)
      .font(.headline)
      .lineLimit(2)

    Label(formattedDate, systemImage: "calendar")
      .font(.subheadline)
      .foregroundStyle(.secondary)

    if let time = event.startTime, !time.isEmpty {
      Label(time, systemImage: "clock")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    if let location = locationLine {
      Label(location, systemImage: "mappin")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    if let cost = event.cost, cost > 0 {
      Label(cost.formatted(.currency(code: "USD")), systemImage: "dollarsign.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    if let notes = event.performanceNotes, !notes.isEmpty {
      Text(notes)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .padding(.top, 2)
    }
  }
  .padding(.vertical, 4)
}
```

### Step 4b: Build and verify

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

### Step 4c: Commit

```bash
git add Features/Events/Views/EventsListView.swift
git commit -m "feat(events-list): enrich event card with time, cost, and performance notes"
```

---

## Task 5: Calendar View Component

This is the largest task. We build a standalone `EventsCalendarView` component and integrate it into `EventsListView`.

**Files:**
- Create: `Features/Events/Components/EventsCalendarView.swift`
- Modify: `Features/Events/ViewModels/EventsListViewModel.swift` (calendar state + helpers)
- Modify: `Features/Events/Views/EventsListView.swift` (embed calendar)

### Step 5a: Add calendar state to `EventsListViewModel`

In `EventsListViewModel`, add these properties after `var sortBy`:

```swift
var currentMonth: Date = {
  let calendar = Calendar.current
  let components = calendar.dateComponents([.year, .month], from: Date())
  return calendar.date(from: components) ?? Date()
}()
var selectedCalendarDate: Date? = nil
```

Add these computed properties after `var hasActiveFilters`:

```swift
var currentMonthTitle: String {
  let formatter = DateFormatter()
  formatter.dateFormat = "MMMM yyyy"
  return formatter.string(from: currentMonth)
}

var calendarDays: [Date] {
  let calendar = Calendar.current
  guard let firstOfMonth = calendar.date(
    from: calendar.dateComponents([.year, .month], from: currentMonth)
  ) else { return [] }
  let weekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sun
  let startOffset = -(weekday - 1)
  return (0..<42).compactMap {
    calendar.date(byAdding: .day, value: startOffset + $0, to: firstOfMonth)
  }
}

func hasEvent(on date: Date) -> Bool {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  let prefix = formatter.string(from: date)
  return events.contains { $0.startDate == prefix }
}

func isCurrentMonth(_ date: Date) -> Bool {
  Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
}

func eventsForDate(_ date: Date) -> [FullEvent] {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  let prefix = formatter.string(from: date)
  return filteredEvents.filter { $0.startDate == prefix }
}
```

Add calendar navigation methods after `deleteEvent`:

```swift
func navigateToPreviousMonth() {
  currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
}

func navigateToNextMonth() {
  currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
}
```

### Step 5b: Create `EventsCalendarView.swift`

Create `Features/Events/Components/EventsCalendarView.swift`:

```swift
import SwiftUI

struct EventsCalendarView: View {
  let title: String
  let days: [Date]
  let hasEvent: (Date) -> Bool
  let isCurrentMonth: (Date) -> Bool
  let selectedDate: Date?
  let onSelectDate: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

  private let columns = Array(repeating: GridItem(.flexible()), count: 7)
  private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  var body: some View {
    VStack(spacing: 12) {
      navigationHeader
      weekdayHeader
      daysGrid
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityLabel("Calendar showing \(title)")
  }

  private var navigationHeader: some View {
    HStack {
      Button(action: onPreviousMonth) {
        Image(systemName: "chevron.left")
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Previous month")

      Spacer()

      Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Button(action: onNextMonth) {
        Image(systemName: "chevron.right")
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Next month")
    }
  }

  private var weekdayHeader: some View {
    LazyVGrid(columns: columns, spacing: 4) {
      ForEach(weekdays, id: \.self) { day in
        Text(day)
          .font(.caption2)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
          .frame(minHeight: 20)
      }
    }
  }

  private var daysGrid: some View {
    LazyVGrid(columns: columns, spacing: 4) {
      ForEach(days, id: \.self) { date in
        DayCellView(
          date: date,
          isCurrentMonth: isCurrentMonth(date),
          hasEvent: hasEvent(date),
          isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
          isToday: Calendar.current.isDateInToday(date),
          onTap: { if hasEvent(date) { onSelectDate(date) } }
        )
      }
    }
  }
}

// MARK: - Day Cell

private struct DayCellView: View {
  let date: Date
  let isCurrentMonth: Bool
  let hasEvent: Bool
  let isSelected: Bool
  let isToday: Bool
  let onTap: () -> Void

  private var dayNumber: String {
    String(Calendar.current.component(.day, from: date))
  }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        Text(dayNumber)
          .font(.subheadline)
          .fontWeight(isToday ? .bold : .regular)
          .foregroundStyle(textColor)
          .frame(width: 32, height: 32)
          .background(backgroundShape)

        Circle()
          .fill(Color.accentColor)
          .frame(width: 4, height: 4)
          .opacity(hasEvent ? 1 : 0)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!hasEvent && !isToday)
    .accessibilityLabel(accessibilityLabel)
  }

  private var textColor: Color {
    if isToday { return .white }
    if !isCurrentMonth { return Color(.tertiaryLabel) }
    return .primary
  }

  @ViewBuilder
  private var backgroundShape: some View {
    if isToday {
      Circle().fill(Color.accentColor)
    } else if isSelected {
      Circle().fill(Color.accentColor.opacity(0.2))
    } else {
      Color.clear
    }
  }

  private var accessibilityLabel: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    let dateStr = formatter.string(from: date)
    let eventInfo = hasEvent ? "Has events" : "No events"
    return "\(dateStr). \(eventInfo)."
  }
}
```

### Step 5c: Integrate calendar into `EventsListView`

In `EventsListView`, add `@State private var scrollProxy: ScrollViewProxy? = nil` (as a stored property). Actually, since `List` doesn't directly support `ScrollViewReader`, the tap-to-scroll will update `selectedCalendarDate` on the VM which we use to scroll via `ScrollViewReader`.

In `eventsContent`, wrap `List` in `ScrollViewReader` and update:

```swift
private var eventsContent: some View {
  ScrollViewReader { proxy in
    List {
      calendarSection
      filterBar
      sortResultsBar

      if viewModel.filteredEvents.isEmpty {
        noResultsState
      } else {
        if !viewModel.upcomingEvents.isEmpty {
          Section("Upcoming") {
            ForEach(viewModel.upcomingEvents) { event in
              eventRow(event)
                .id(event.id)
            }
          }
        }
        if !viewModel.pastEvents.isEmpty {
          Section("Past") {
            ForEach(viewModel.pastEvents) { event in
              eventRow(event)
                .id(event.id)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .onChange(of: viewModel.selectedCalendarDate) { _, date in
      guard let date else { return }
      let firstEvent = viewModel.eventsForDate(date).first
      if let id = firstEvent?.id {
        withAnimation { proxy.scrollTo(id, anchor: .top) }
      }
    }
  }
}
```

Add `calendarSection` view:

```swift
private var calendarSection: some View {
  Section {
    EventsCalendarView(
      title: viewModel.currentMonthTitle,
      days: viewModel.calendarDays,
      hasEvent: viewModel.hasEvent(on:),
      isCurrentMonth: viewModel.isCurrentMonth(_:),
      selectedDate: viewModel.selectedCalendarDate,
      onSelectDate: { date in viewModel.selectedCalendarDate = date },
      onPreviousMonth: { viewModel.navigateToPreviousMonth() },
      onNextMonth: { viewModel.navigateToNextMonth() }
    )
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }
}
```

### Step 5d: Build and verify

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

### Step 5e: Commit

```bash
git add Features/Events/Components/EventsCalendarView.swift \
        Features/Events/ViewModels/EventsListViewModel.swift \
        Features/Events/Views/EventsListView.swift
git commit -m "feat(events-list): add calendar view with month navigation, event indicators, and scroll-to-event"
```

---

## Task 6: Tests for Calendar ViewModel Logic

**Files:**
- Modify: `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

### Step 6a: Add calendar tests

Append inside `EventsListViewModelTests`:

```swift
// MARK: - Calendar

func testCalendarDays_returns42Days() {
  XCTAssertEqual(sut.calendarDays.count, 42)
}

func testCalendarDays_firstDayIsSunday() {
  let calendar = Calendar.current
  let firstDay = sut.calendarDays.first!
  XCTAssertEqual(calendar.component(.weekday, from: firstDay), 1) // 1 = Sunday
}

func testCurrentMonthTitle_formatsCorrectly() {
  // Just ensure it returns a non-empty, readable title
  XCTAssertFalse(sut.currentMonthTitle.isEmpty)
  XCTAssertTrue(sut.currentMonthTitle.contains(String(Calendar.current.component(.year, from: Date()))))
}

func testHasEvent_returnsTrueWhenEventOnDate() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [fullEventMock(id: "e1", startDate: "2099-06-15")]
  await sut.loadEvents()

  var components = DateComponents()
  components.year = 2099; components.month = 6; components.day = 15
  let date = Calendar.current.date(from: components)!

  XCTAssertTrue(sut.hasEvent(on: date))
}

func testHasEvent_returnsFalseWhenNoEventOnDate() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [fullEventMock(id: "e1", startDate: "2099-06-15")]
  await sut.loadEvents()

  var components = DateComponents()
  components.year = 2099; components.month = 6; components.day = 16
  let date = Calendar.current.date(from: components)!

  XCTAssertFalse(sut.hasEvent(on: date))
}

func testNavigateToPreviousMonth_decrementsMonth() {
  let initial = sut.currentMonth
  sut.navigateToPreviousMonth()
  let previous = sut.currentMonth
  XCTAssertEqual(
    Calendar.current.dateComponents([.month], from: previous, to: initial).month, 1
  )
}

func testNavigateToNextMonth_incrementsMonth() {
  let initial = sut.currentMonth
  sut.navigateToNextMonth()
  let next = sut.currentMonth
  XCTAssertEqual(
    Calendar.current.dateComponents([.month], from: initial, to: next).month, 1
  )
}

func testEventsForDate_returnsMatchingEvents() async {
  mockAuth.user = userMock(id: "user-1")
  mockService.stubbedEvents = [
    fullEventMock(id: "e1", name: "June Event", startDate: "2099-06-15"),
    fullEventMock(id: "e2", name: "July Event", startDate: "2099-07-01")
  ]
  await sut.loadEvents()

  var components = DateComponents()
  components.year = 2099; components.month = 6; components.day = 15
  let date = Calendar.current.date(from: components)!

  let result = sut.eventsForDate(date)
  XCTAssertEqual(result.count, 1)
  XCTAssertEqual(result.first?.name, "June Event")
}
```

### Step 6b: Run all tests — confirm pass

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "failed|error:|Test Suite.*passed"
```

Expected: `Test Suite 'All tests' passed`

### Step 6c: Commit

```bash
git add TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift
git commit -m "test(events-list): add calendar, delete, date range filter, and sort unit tests"
```

---

## Task 7: Final Build + Test Verification

### Step 7a: Full build

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

### Step 7b: Full test run

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite.*passed|failed"
```

Expected: All suites passed, 0 failures.

### Step 7c: Final commit (if any uncommitted changes)

```bash
git status
git add -A && git commit -m "chore(events-list): final cleanup and verification"
```

---

## Unresolved Questions

1. **`FullEvent.description` field** — the ViewModel's `filteredEvents` now searches `description`. Verify `FullEvent` has a `description: String?` field (it should based on the spec model, but double-check `Models/FullEvent.swift`).

2. **`FullEvent.coachesPresent` field** — already added in Phase 6 Task 1. Confirm `FullEvent` compiles cleanly with the mock initializer in the test helper (the `fullEventMock` helper in `EventsListViewModelTests` may need updating if new required init params were added in Phase 6).

3. **Scroll-on-calendar-tap behavior** — the implementation scrolls to the first event on the tapped date within `filteredEvents`. If the tapped date's events are filtered out (e.g., type filter active), the scroll won't fire. This is acceptable per spec ("Tap calendar date to scroll to event"), but confirm with product.

4. **Calendar month limit** — spec says ±2 years from current month. The navigation methods have no guard. If this restriction is desired, add a guard in `navigateToPreviousMonth`/`navigateToNextMonth`. Skipped for now as YAGNI.

5. **`statsRecorded: [String: Any]?`** — spec's Event model has this field, but `[String: Any]` isn't `Codable`. The current `FullEvent` model may omit this field. Verify and leave as-is unless the server returns it.
