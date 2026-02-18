# Events List Spec Completion Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the remaining gaps between the Phase 6 Events List spec and the current iOS implementation.

**Architecture:** All changes are additive — no structural rewrites. Gaps are confined to `EventsListViewModel`, `EventsListView`, and a new accessibility test file. Production code changes are small; the bulk of each task is the test.

**Tech Stack:** SwiftUI, `@Observable`, `@AppStorage` (UserDefaults wrapper), `UIImpactFeedbackGenerator` / `.sensoryFeedback`, XCTest.

---

## Spec vs. Implementation Gap Summary

| # | Gap | Spec Section | Effort |
|---|-----|-------------|--------|
| 1 | `sortBy` not persisted across sessions | §5 State Management | Small |
| 2 | Calendar navigation has no ±2-year limit | §8 Edge Cases | Small |
| 3 | Event row accessibility label omits status | §6 Accessibility | Tiny |
| 4 | No haptic feedback on delete | §6 Accessibility | Small |
| 5 | No `EventsListAccessibilityTests.swift` | §9 Testing Checklist | Moderate |
| 6 | Timeline Status Snippet at top of layout | §6 Layout | Deferred* |

> *Timeline Status Snippet — the spec lists a "Phase indicator" at the page top, but no such component exists anywhere in the codebase. Deferred until the component exists or requirements are clarified.

---

## Task 1: Persist Sort Order in UserDefaults

**Spec:** "Selected sort order persists in UserDefaults" (§5 Persistence Across Navigation)

**Files:**
- Modify: `TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift`
- Test: `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

### Step 1.1: Write the failing test

Add to `EventsListViewModelTests.swift` in the `// MARK: - Sort` section:

```swift
func testSortBy_persistsAcrossViewModelRecreation() {
    sut.sortBy = .name

    // Recreate the ViewModel — simulates navigation away and back
    let sut2 = EventsListViewModel(eventsService: mockService, authManager: mockAuth)

    XCTAssertEqual(sut2.sortBy, .name)
}

func testSortBy_defaultsToDateDescOnFirstLaunch() {
    // Clear UserDefaults key before testing default
    UserDefaults.standard.removeObject(forKey: "eventsSortBy")
    let freshSut = EventsListViewModel(eventsService: mockService, authManager: mockAuth)
    XCTAssertEqual(freshSut.sortBy, .dateDesc)
}
```

### Step 1.2: Run the tests to verify they fail

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/EventsListViewModelTests/testSortBy_persistsAcrossViewModelRecreation \
  2>&1 | tail -20
```

Expected: FAIL — sort resets to `.dateDesc` after recreating ViewModel.

### Step 1.3: Implement sort persistence

In `EventsListViewModel.swift`, replace the plain `sortBy` property with `@AppStorage`:

```swift
// BEFORE:
var sortBy: SortOption = .dateDesc

// AFTER — add at the top of the file (outside the class):
// (no change needed — @AppStorage works on @Observable classes)

// In the class body, replace the property:
@AppStorage("eventsSortBy") var sortBy: SortOption = .dateDesc
```

`SortOption` must conform to `RawRepresentable` with a `String` raw value (it already does — it's a `String` enum). `@AppStorage` works with `String`-backed enums automatically.

### Step 1.4: Run the tests to verify they pass

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/EventsListViewModelTests 2>&1 | tail -20
```

Expected: All `EventsListViewModelTests` pass.

### Step 1.5: Commit

```bash
git add TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift
git commit -m "feat: persist events sort order in UserDefaults"
```

---

## Task 2: Calendar Navigation ±2-Year Limit

**Spec:** "Calendar navigation to far future/past: Limit to ±2 years from current month" (§8 Edge Cases)

**Files:**
- Modify: `TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift`
- Test: `TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift`

### Step 2.1: Write the failing tests

Add to `EventsListViewModelTests.swift` in `// MARK: - Calendar`:

```swift
func testNavigateToPreviousMonth_stopsAtTwoYearsBack() {
    // Navigate back 25 months (more than the 24-month limit)
    for _ in 0..<25 {
        sut.navigateToPreviousMonth()
    }
    let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    let limit = Calendar.current.dateComponents([.year, .month], from: twoYearsAgo)
    let current = Calendar.current.dateComponents([.year, .month], from: sut.currentMonth)
    XCTAssertEqual(current.year, limit.year)
    XCTAssertEqual(current.month, limit.month)
}

func testNavigateToNextMonth_stopsAtTwoYearsAhead() {
    // Navigate forward 25 months (more than the 24-month limit)
    for _ in 0..<25 {
        sut.navigateToNextMonth()
    }
    let twoYearsAhead = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
    let limit = Calendar.current.dateComponents([.year, .month], from: twoYearsAhead)
    let current = Calendar.current.dateComponents([.year, .month], from: sut.currentMonth)
    XCTAssertEqual(current.year, limit.year)
    XCTAssertEqual(current.month, limit.month)
}
```

### Step 2.2: Run the tests to verify they fail

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/EventsListViewModelTests/testNavigateToPreviousMonth_stopsAtTwoYearsBack \
  2>&1 | tail -10
```

Expected: FAIL.

### Step 2.3: Implement the limit

In `EventsListViewModel.swift`, update the two navigation methods:

```swift
func navigateToPreviousMonth() {
    let limit = Calendar.current.date(byAdding: .year, value: -2, to: referenceDate()) ?? currentMonth
    if currentMonth > limit {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
}

func navigateToNextMonth() {
    let limit = Calendar.current.date(byAdding: .year, value: 2, to: referenceDate()) ?? currentMonth
    if currentMonth < limit {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}

/// Returns the first day of the current calendar month (for limit calculations).
private func referenceDate() -> Date {
    let components = Calendar.current.dateComponents([.year, .month], from: Date())
    return Calendar.current.date(from: components) ?? Date()
}
```

### Step 2.4: Run the tests to verify they pass

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/EventsListViewModelTests 2>&1 | tail -20
```

Expected: All `EventsListViewModelTests` pass.

### Step 2.5: Commit

```bash
git add TheRecruitingCompass/Features/Events/ViewModels/EventsListViewModel.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Events/ViewModels/EventsListViewModelTests.swift
git commit -m "feat: limit calendar navigation to ±2 years"
```

---

## Task 3: Event Row Accessibility Label Includes Status

**Spec:** Event card VoiceOver: `"[Event name], [Type], [Date], [Status]."` (§6 Accessibility)

**Files:**
- Modify: `TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

This is a one-liner. No new test needed — it will be covered by the accessibility tests in Task 5.

### Step 3.1: Update the accessibility label helper

In `EventsListView.swift`, update `rowAccessibilityLabel`:

```swift
// BEFORE:
private func rowAccessibilityLabel(_ event: FullEvent) -> String {
    let type = EventType(rawValue: event.type)?.displayName ?? event.type
    let date = event.startDate
    return "\(type): \(event.name), \(date)"
}

// AFTER:
private func rowAccessibilityLabel(_ event: FullEvent) -> String {
    let type = EventType(rawValue: event.type)?.displayName ?? event.type
    let status = event.attended ? "Attended" : event.registered ? "Registered" : "Not Registered"
    return "\(type): \(event.name), \(event.startDate), \(status)"
}
```

### Step 3.2: Build to verify no errors

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

### Step 3.3: Commit

```bash
git add TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "fix: include event status in VoiceOver accessibility label"
```

---

## Task 4: Haptic Feedback on Delete

**Spec:** "Haptic Feedback: Light impact on button tap, notification on delete" (§6 Accessibility)

**Files:**
- Modify: `TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

Haptic feedback is a UI-layer concern — no ViewModel change needed, no unit test possible. Verify manually or via a build check.

### Step 4.1: Add haptic feedback to the delete confirmation

In `EventsListView.swift`, update the delete confirmation handler. Import is not needed — `UIImpactFeedbackGenerator` is in UIKit which is available via SwiftUI.

```swift
// BEFORE — in the confirmationDialog destructive button:
Button("Delete", role: .destructive) {
    if let event = eventToDelete {
        Task { await viewModel.deleteEvent(id: event.id) }
        eventToDelete = nil
    }
}

// AFTER:
Button("Delete", role: .destructive) {
    if let event = eventToDelete {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        Task { await viewModel.deleteEvent(id: event.id) }
        eventToDelete = nil
    }
}
```

Also add light impact when the delete swipe action is triggered (when `eventToDelete` is set):

```swift
// BEFORE — in eventRow, swipe action button:
Button(role: .destructive) {
    eventToDelete = event
} label: {
    Label("Delete", systemImage: "trash")
}

// AFTER:
Button(role: .destructive) {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    eventToDelete = event
} label: {
    Label("Delete", systemImage: "trash")
}
```

### Step 4.2: Build to verify no errors

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

### Step 4.3: Commit

```bash
git add TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "feat: add haptic feedback for event delete actions"
```

---

## Task 5: EventsListAccessibilityTests

**Spec:** §9 Testing Checklist — "VoiceOver announces all elements correctly" (edge case test)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Events/Accessibility/EventsListAccessibilityTests.swift`

These are unit tests that verify SwiftUI view accessibility labels and traits using `ViewInspector`...

> **Note:** This codebase does **not** use ViewInspector. Looking at existing accessibility tests (e.g., `EventDetailAccessibilityTests.swift`), confirm the pattern used before writing these tests. See Step 5.0 below.

### Step 5.0: Check the existing accessibility test pattern

```bash
cat /path/to/TheRecruitingCompassTests/Features/Events/Accessibility/EventDetailAccessibilityTests.swift
```

Read the file at:
`TheRecruitingCompass/TheRecruitingCompassTests/Features/Events/Accessibility/EventDetailAccessibilityTests.swift`

Use whatever pattern that file uses. The plan below assumes the same pattern — adjust if it differs.

### Step 5.1: Read the existing accessibility test pattern

Read the existing test to understand what's being tested. Common patterns in this codebase:
- Testing `accessibilityLabel` values directly via ViewModel-computed strings
- Testing that enums produce correct display names (used as accessibility labels)

### Step 5.2: Create the test file

Create `TheRecruitingCompassTests/Features/Events/Accessibility/EventsListAccessibilityTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

/// Verifies that Events List accessibility labels match spec §6 Accessibility requirements.
@MainActor
final class EventsListAccessibilityTests: XCTestCase {

    // MARK: - Calendar Labels

    func testCalendarTitle_includesMonthAndYear() {
        let vm = EventsListViewModel(
            eventsService: MockEventsService(),
            authManager: MockAuthManager()
        )
        // currentMonthTitle used as calendar accessibilityLabel suffix
        XCTAssertTrue(vm.currentMonthTitle.contains(String(Calendar.current.component(.year, from: Date()))))
        XCTAssertFalse(vm.currentMonthTitle.isEmpty)
    }

    // MARK: - Event Type Display Names (used in accessibility labels)

    func testEventType_camp_hasCorrectDisplayName() {
        XCTAssertEqual(EventType.camp.displayName, "Camp")
    }

    func testEventType_showcase_hasCorrectDisplayName() {
        XCTAssertEqual(EventType.showcase.displayName, "Showcase")
    }

    func testEventType_officialVisit_hasCorrectDisplayName() {
        XCTAssertEqual(EventType.officialVisit.displayName, "Official Visit")
    }

    func testEventType_unofficialVisit_hasCorrectDisplayName() {
        XCTAssertEqual(EventType.unofficialVisit.displayName, "Unofficial Visit")
    }

    func testEventType_game_hasCorrectDisplayName() {
        XCTAssertEqual(EventType.game.displayName, "Game")
    }

    // MARK: - Status Filter Display Names (used in picker accessibility)

    func testStatusFilter_all_rawValueIsHumanReadable() {
        XCTAssertEqual(StatusFilter.all.rawValue, "All")
    }

    func testStatusFilter_attended_rawValueIsHumanReadable() {
        XCTAssertEqual(StatusFilter.attended.rawValue, "Attended")
    }

    func testStatusFilter_registered_rawValueIsHumanReadable() {
        XCTAssertEqual(StatusFilter.registered.rawValue, "Registered")
    }

    func testStatusFilter_notRegistered_rawValueIsHumanReadable() {
        XCTAssertEqual(StatusFilter.notRegistered.rawValue, "Not Registered")
    }

    // MARK: - Sort Option Display Names (used in picker accessibility)

    func testSortOption_dateDesc_rawValueIsHumanReadable() {
        XCTAssertEqual(SortOption.dateDesc.rawValue, "Date (Newest First)")
    }

    func testSortOption_dateAsc_rawValueIsHumanReadable() {
        XCTAssertEqual(SortOption.dateAsc.rawValue, "Date (Oldest First)")
    }

    func testSortOption_name_rawValueIsHumanReadable() {
        XCTAssertEqual(SortOption.name.rawValue, "Name")
    }

    func testSortOption_type_rawValueIsHumanReadable() {
        XCTAssertEqual(SortOption.type.rawValue, "Type")
    }

    // MARK: - Date Range Filter Display Names

    func testDateRangeFilter_allCases_haveHumanReadableRawValues() {
        for filter in DateRangeFilter.allCases {
            XCTAssertFalse(filter.rawValue.isEmpty, "\(filter) has empty raw value")
            // Raw values should not contain underscores (enums, not display strings)
            XCTAssertFalse(filter.rawValue.contains("_"), "\(filter).rawValue '\(filter.rawValue)' contains underscore — should be a display string")
        }
    }
}
```

### Step 5.3: Run the tests to verify they pass

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/EventsListAccessibilityTests 2>&1 | tail -20
```

Expected: All tests pass (these test existing behavior — they document the spec, not reveal new bugs).

### Step 5.4: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Events/Accessibility/EventsListAccessibilityTests.swift
git commit -m "test: add EventsList accessibility label tests per spec §6"
```

---

## Task 6: Full Test Suite Verification

Confirm all existing tests still pass after the changes.

### Step 6.1: Run the full test suite

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|PASS|FAIL|error:" | tail -30
```

Expected: All tests pass. No regressions.

### Step 6.2: If any test fails

- Check if `@AppStorage` in `EventsListViewModel` interferes with other tests that create `EventsListViewModel` directly
- If so: after `testSortBy_defaultsToDateDescOnFirstLaunch` runs, add `UserDefaults.standard.removeObject(forKey: "eventsSortBy")` to the test `tearDown`
- Re-run until green

---

## Deferred: Timeline Status Snippet

**Spec Location:** §6 Layout, top of page:
```
[Header]
  - Timeline Status Snippet (Phase indicator)
```

**Why deferred:** No `TimelineStatusView`, `PhaseIndicatorView`, or equivalent component exists anywhere in the codebase. The spec describes a "Phase indicator" but gives no data model, design spec, or API definition for it.

**When to implement:** Once the component is built for another feature (e.g., Dashboard), embed it as the first `Section` in `eventsContent` above `calendarSection`.

---

## Unresolved Questions

1. **`@AppStorage` + `@Observable` compatibility:** In Xcode 16 / iOS 17+, `@AppStorage` inside an `@Observable` class may require wrapping. If the compiler rejects it, use a `didSet` observer to write to `UserDefaults.standard` manually instead.

2. **Accessibility test pattern:** Check `EventDetailAccessibilityTests.swift` before writing Task 5 — use whatever pattern is already established there.

3. **Timeline Status Snippet:** What data does it show? (Phase number, label, date?) Who owns the data? Needs design + data spec before implementation.
