# SwiftUI Code Review Fixes

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 18 issues found in the SwiftUI code review against iOS 17/18 standards.

**Architecture:** All changes are in-place refactors — no new screens or features. The worktree is `refactor/swiftui-code-review`. Source lives in the double-nested path: `TheRecruitingCompass/TheRecruitingCompass/`. Tests live in `TheRecruitingCompass/TheRecruitingCompassTests/`.

**Tech Stack:** Swift 6, SwiftUI, `@Observable` (iOS 17+), `@MainActor`, OSLog, XCTest

**Build command:** `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|warning:|BUILD)'`

**Test command:** `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`

**Working directory for all tasks:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review`

---

## Task 1: Fix deprecated APIs and trivial cleanup

Covers issues #13, #14, #15, #17 — all mechanical find-and-replace changes.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

**Step 1: Fix `.navigationBarTrailing` → `.topBarTrailing` (EventsListView.swift line 23)**

```swift
// BEFORE:
ToolbarItem(placement: .navigationBarTrailing) {

// AFTER:
ToolbarItem(placement: .topBarTrailing) {
```

**Step 2: Fix deprecated `.cornerRadius` → `.clipShape` (SchoolDetailView.swift line 257)**

```swift
// BEFORE:
.background(Color.red.opacity(0.1))
.foregroundStyle(.red)
.cornerRadius(12)

// AFTER:
.background(Color.red.opacity(0.1))
.foregroundStyle(.red)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

**Step 3: Remove empty duplicate `// MARK: - Metrics` (EventDetailViewModel.swift line 322)**

The file has two consecutive MARK sections. Remove the empty one:

```swift
// REMOVE these two lines (line ~322):
  // MARK: - Metrics

  // MARK: - Coach Management
// REPLACE with just:
  // MARK: - Coach Management
```

**Step 4: Remove "Phase N:" prefixes from SchoolDetailViewModel.swift MARKs**

Find and replace these exact strings in SchoolDetailViewModel.swift:
```
// MARK: - Phase 2: Notes Editing          → // MARK: - Notes
// MARK: - Phase 2: Private Notes Editing  → // MARK: - Private Notes
// MARK: - Phase 2: Pros & Cons            → // MARK: - Pros & Cons
// MARK: - Phase 2: Basic Info Editing     → // MARK: - Basic Info
// MARK: - Phase 3: Fit Score              → // MARK: - Fit Score
// MARK: - Phase 3: College Scorecard      → // MARK: - College Scorecard
// MARK: - Phase 4: Coaches                → // MARK: - Coaches
// MARK: - Phase 4: Coaching Philosophy    → // MARK: - Coaching Philosophy
// MARK: - Phase 4: Delete                 → // MARK: - Delete
// MARK: - Phase 4: Priority Tier          → // MARK: - Priority Tier
```

**Step 5: Build to verify no regressions**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 6: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift
git commit -m "refactor: fix deprecated APIs and clean up MARK comments"
```

---

## Task 2: EventUpdateRequest — add default nil values

Covers issue #4. `EventUpdateRequest` forces callers to spell out every `nil` field. Adding `= nil` defaults eliminates the boilerplate at 3 call sites.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Models/EventUpdateRequest.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`

**Step 1: Add default nil to all optional fields in EventUpdateRequest.swift**

Replace the entire struct body — add `= nil` to every optional property:

```swift
struct EventUpdateRequest: Encodable, Sendable {
  let name: String?
  let type: String?
  let startDate: String?
  let endDate: String?
  let startTime: String?
  let endTime: String?
  let checkinTime: String?
  let schoolId: String?
  let location: String?
  let address: String?
  let city: String?
  let state: String?
  let url: String?
  let description: String?
  let eventSource: String?
  let cost: Double?
  let registered: Bool?
  let attended: Bool?
  let performanceNotes: String?
  let coachesPresent: [String]?

  init(
    name: String? = nil,
    type: String? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    startTime: String? = nil,
    endTime: String? = nil,
    checkinTime: String? = nil,
    schoolId: String? = nil,
    location: String? = nil,
    address: String? = nil,
    city: String? = nil,
    state: String? = nil,
    url: String? = nil,
    description: String? = nil,
    eventSource: String? = nil,
    cost: Double? = nil,
    registered: Bool? = nil,
    attended: Bool? = nil,
    performanceNotes: String? = nil,
    coachesPresent: [String]? = nil
  ) {
    self.name = name
    self.type = type
    self.startDate = startDate
    self.endDate = endDate
    self.startTime = startTime
    self.endTime = endTime
    self.checkinTime = checkinTime
    self.schoolId = schoolId
    self.location = location
    self.address = address
    self.city = city
    self.state = state
    self.url = url
    self.description = description
    self.eventSource = eventSource
    self.cost = cost
    self.registered = registered
    self.attended = attended
    self.performanceNotes = performanceNotes
    self.coachesPresent = coachesPresent
  }

  enum CodingKeys: String, CodingKey {
    case name, type, location, address, city, state, url, description, cost, registered, attended
    case startDate = "start_date"
    case endDate = "end_date"
    case startTime = "start_time"
    case endTime = "end_time"
    case checkinTime = "checkin_time"
    case schoolId = "school_id"
    case eventSource = "event_source"
    case performanceNotes = "performance_notes"
    case coachesPresent = "coaches_present"
  }
}
```

**Step 2: Simplify the 3 call sites in EventDetailViewModel.swift**

*Call site 1* — `markAsAttended()` (was ~lines 216–222):
```swift
// BEFORE:
let request = EventUpdateRequest(
  name: nil, type: nil, startDate: nil, endDate: nil,
  startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
  location: nil, address: nil, city: nil, state: nil,
  url: nil, description: nil, eventSource: nil, cost: nil,
  registered: nil, attended: true, performanceNotes: nil, coachesPresent: nil
)

// AFTER:
let request = EventUpdateRequest(attended: true)
```

*Call site 2* — `addCoach()` (was ~lines 339–345):
```swift
// BEFORE:
let request = EventUpdateRequest(
  name: nil, type: nil, startDate: nil, endDate: nil,
  startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
  location: nil, address: nil, city: nil, state: nil,
  url: nil, description: nil, eventSource: nil, cost: nil,
  registered: nil, attended: nil, performanceNotes: nil,
  coachesPresent: currentCoaches
)

// AFTER:
let request = EventUpdateRequest(coachesPresent: currentCoaches)
```

*Call site 3* — `removeCoach()` (was ~lines 367–374):
```swift
// BEFORE:
let request = EventUpdateRequest(
  name: nil, type: nil, startDate: nil, endDate: nil,
  startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
  location: nil, address: nil, city: nil, state: nil,
  url: nil, description: nil, eventSource: nil, cost: nil,
  registered: nil, attended: nil, performanceNotes: nil,
  coachesPresent: currentCoaches
)

// AFTER:
let request = EventUpdateRequest(coachesPresent: currentCoaches)
```

**Step 3: Build and run tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/EventDetailViewModelTests 2>&1 | tail -10
```

Expected: `TEST SUCCEEDED` (all existing EventDetailViewModelTests pass)

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Models/EventUpdateRequest.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift
git commit -m "refactor: add default nil values to EventUpdateRequest, remove verbose call sites"
```

---

## Task 3: Consolidate ISO date parsing into DateFormatting.swift

Covers issue #5. Two views independently parse ISO date strings (`yyyy-MM-dd`) via manual split/DateComponents. Move to the shared `DateFormatting` enum. Also remove the duplicate `DateFormatter` in `prepareCSVExport()`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/DateFormatting.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Step 1: Add `isoDateString(_:)` and `isoDateRangeString(from:to:)` to DateFormatting.swift**

Add after the existing `mediumDate` function:

```swift
/// Converts an ISO date string ("yyyy-MM-dd") to a display string ("Apr 15, 2026")
static func isoDateString(_ isoDate: String) -> String {
  let components = isoDate.split(separator: "-").compactMap { Int($0) }
  guard components.count == 3 else { return isoDate }
  let date = DateComponents(
    calendar: .current,
    year: components[0], month: components[1], day: components[2]
  ).date
  return date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? isoDate
}

/// Converts an ISO date range to "Apr 15, 2026" or "Apr 15 – Jun 5, 2026"
static func isoDateRangeString(from startDate: String, to endDate: String?) -> String {
  let start = isoDateString(startDate)
  guard let endDate, endDate != startDate else { return start }
  let endComponents = endDate.split(separator: "-").compactMap { Int($0) }
  guard endComponents.count == 3,
        let end = DateComponents(
          calendar: .current,
          year: endComponents[0], month: endComponents[1], day: endComponents[2]
        ).date else { return "\(start) – \(isoDateString(endDate))" }
  return "\(start) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
}

/// ISO date string formatter for use in CSV/file export ("yyyy-MM-dd")
static let isoExportFormatter: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "en_US_POSIX")
  f.dateFormat = "yyyy-MM-dd"
  return f
}()
```

**Step 2: Update EventDetailViewModel.swift**

Remove the module-level `metricDateFormatter` (lines 5–10 at top of file) and the private `formatDate()` method at the bottom. Update callers:

*Replace `formattedDateRange` computed property:*
```swift
// BEFORE:
var formattedDateRange: String {
  guard let event else { return "" }
  let start = formatDate(event.startDate)
  guard let endDate = event.endDate, endDate != event.startDate else { return start }
  return "\(start) – \(formatDate(endDate))"
}

// AFTER:
var formattedDateRange: String {
  guard let event else { return "" }
  return DateFormatting.isoDateRangeString(from: event.startDate, to: event.endDate)
}
```

*Replace local DateFormatter in `prepareCSVExport()`:*
```swift
// BEFORE (inside prepareCSVExport):
let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "en_US_POSIX")
dateFormatter.dateFormat = "yyyy-MM-dd"
...
let dateStr = dateFormatter.string(from: m.recordedDate)

// AFTER:
let dateStr = DateFormatting.isoExportFormatter.string(from: m.recordedDate)
```

*Remove the `private func formatDate(_:)` helper method at the bottom of EventDetailViewModel.*

*Remove the module-level `metricDateFormatter` at lines 5–10 of EventDetailViewModel.swift.*

**Step 3: Update EventRowView in EventsListView.swift**

Replace the `formattedDate` computed property (EventRowView, ~lines 361–379):

```swift
// BEFORE:
private var formattedDate: String {
  let components = event.startDate.split(separator: "-").compactMap { Int($0) }
  guard components.count == 3 else { return event.startDate }
  let date = DateComponents(
    calendar: .current,
    year: components[0],
    month: components[1],
    day: components[2]
  ).date
  let formatted = date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? event.startDate
  if let endDate = event.endDate, endDate != event.startDate {
    let endComponents = endDate.split(separator: "-").compactMap { Int($0) }
    if endComponents.count == 3,
       let end = DateComponents(calendar: .current, year: endComponents[0], month: endComponents[1], day: endComponents[2]).date {
      return "\(formatted) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }
  }
  return formatted
}

// AFTER:
private var formattedDate: String {
  DateFormatting.isoDateRangeString(from: event.startDate, to: event.endDate)
}
```

**Step 4: Build and run tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/EventDetailViewModelTests 2>&1 | tail -10
```

Expected: `TEST SUCCEEDED` (date formatting tests pass)

**Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/DateFormatting.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "refactor: consolidate ISO date parsing into DateFormatting shared utility"
```

---

## Task 4: Extract MetricsExportService

Covers issue #3 (file I/O in ViewModel). Extract CSV generation and temp-file writing from `EventDetailViewModel` into a dedicated service.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Services/MetricsExportService.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`

**Step 1: Create MetricsExportService.swift**

```swift
import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "MetricsExportService"
)

struct MetricsExportService {
  func prepareCSV(metrics: [PerformanceMetric], eventName: String) throws -> URL {
    var rows: [String] = ["Metric Type,Value,Unit,Recorded Date,Verified,Notes"]
    for m in metrics {
      let notesEscaped = (m.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
      let notes = notesEscaped.isEmpty ? "" : "\"\(notesEscaped)\""
      let dateStr = DateFormatting.isoExportFormatter.string(from: m.recordedDate)
      rows.append("\(m.displayName),\(m.value),\(m.unit),\(dateStr),\(m.verified),\(notes)")
    }
    let csv = rows.joined(separator: "\n")
    let safeName = eventName
      .filter { $0.isLetter || $0.isNumber || $0 == " " }
      .replacingOccurrences(of: " ", with: "-")
    let fileName = "event-metrics-\(safeName).csv"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    logger.info("CSV export prepared: \(fileName)")
    return fileURL
  }

  func cleanup(url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
```

**Step 2: Update EventDetailViewModel.swift**

Add a `private let exportService = MetricsExportService()` property in the Dependencies section.

Replace `prepareCSVExport()` and `clearExport()`:

```swift
func prepareCSVExport() {
  guard let event, !metrics.isEmpty else { return }
  do {
    exportFileURL = try exportService.prepareCSV(metrics: metrics, eventName: event.name)
  } catch {
    logger.error("Failed to write CSV: \(error.localizedDescription)")
    self.error = "Failed to prepare export."
  }
}

func clearExport() {
  if let url = exportFileURL {
    exportService.cleanup(url: url)
  }
  exportFileURL = nil
}
```

**Step 3: Build and run export tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/EventDetailViewModelTests/testPrepareCSVExport_withMetrics_setsExportFileURL 2>&1 | tail -10
```

Expected: `TEST SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Services/MetricsExportService.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift
git commit -m "refactor: extract CSV file I/O from ViewModel into MetricsExportService"
```

---

## Task 5: Fix haptic feedback inconsistency in EventsListView

Covers issue #7. EventsListView calls raw UIKit haptic APIs directly. Replace with `HapticFeedbackManager.shared`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Step 1: Replace raw haptics in the swipe-to-delete action (~line 219)**

```swift
// BEFORE:
Button(role: .destructive) {
  UIImpactFeedbackGenerator(style: .light).impactOccurred()
  eventToDelete = event
} label: {
  Label("Delete", systemImage: "trash")
}

// AFTER:
Button(role: .destructive) {
  HapticFeedbackManager.shared.lightImpact()
  eventToDelete = event
} label: {
  Label("Delete", systemImage: "trash")
}
```

**Step 2: Replace raw haptic in the delete confirmation action (~line 69)**

```swift
// BEFORE:
Button("Delete", role: .destructive) {
  if let event = eventToDelete {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    Task { await viewModel.deleteEvent(id: event.id) }
    eventToDelete = nil
  }
}

// AFTER:
Button("Delete", role: .destructive) {
  if let event = eventToDelete {
    HapticFeedbackManager.shared.warning()
    Task { await viewModel.deleteEvent(id: event.id) }
    eventToDelete = nil
  }
}
```

**Step 3: Build to verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "refactor: replace raw UIKit haptics with HapticFeedbackManager in EventsListView"
```

---

## Task 6: Fix userId Optional handling in SchoolDetailViewModel

Covers issue #16. `currentUserId` returns `""` as a fallback — an empty string is indistinguishable from a real ID. Return `String?` and let callers guard-unwrap.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

**Step 1: Change `currentUserId` to return `String?`**

```swift
// BEFORE:
var currentUserId: String {
  authManager.user?.id ?? ""
}

// AFTER:
var currentUserId: String? {
  authManager.user?.id
}
```

**Step 2: Update all call sites that relied on the empty string fallback**

There are usages in:
- `privateNoteForCurrentUser` — wrap:
```swift
var privateNoteForCurrentUser: String {
  guard let userId = currentUserId else { return "" }
  return school?.privateNote(for: userId) ?? ""
}
```
- `updateStatus(to:)` — already has `guard let school, !currentUserId.isEmpty` — change to:
```swift
guard let school, let currentUserId else { return }
```
- `toggleFavorite()` — no userId usage, no change needed
- `savePrivateNotes()` — already uses `currentUserId` in the service call — update:
```swift
let updated = try await schoolsService.updatePrivateNotes(
  id: schoolId,
  familyUnitId: familyId,
  userId: currentUserId,   // currentUserId is now String? — update to:
  note: note
)
// Guard earlier:
guard let userId = currentUserId else {
  errorMessage = "You must be signed in"
  return
}
// Then use `userId` in the call
```
- `addPro()`, `addCon()`, `removePro()`, `removeCon()` — check if these pass `currentUserId` to service calls. If so, guard-unwrap each.
- `deleteSchool()` — check for userId usage
- Any `loadSchool()` that passes userId

Trace every `currentUserId` reference in the file and update the guard pattern consistently.

**Step 3: Build and run SchoolDetailViewModel tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase1Tests \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase2Tests \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase3Tests \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPriorityTierTests \
  2>&1 | tail -15
```

Expected: `TEST SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift
git commit -m "refactor: make currentUserId Optional in SchoolDetailViewModel"
```

---

## Task 7: Standardize DI pattern in SchoolDetailViewModel

Covers issue #12. SchoolDetailViewModel uses optional `?(any Protocol)?` parameters in init. EventDetailViewModel uses non-optional with concrete defaults. Standardize on non-optional.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift`

**Step 1: Change init parameters from optional to non-optional with defaults**

```swift
// BEFORE:
init(
  schoolId: String,
  schoolsService: (any SchoolsManaging)? = nil,
  authManager: (any AuthManaging)? = nil,
  familyManager: FamilyManager? = nil,
  fitScoreService: (any FitScoreManaging)? = nil,
  collegeService: (any CollegeScorecardManaging)? = nil,
  coachesService: (any CoachesManaging)? = nil
) {
  self.schoolId = schoolId
  self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
  self.authManager = authManager ?? AuthManager.shared
  self.familyManager = familyManager ?? .shared
  self.fitScoreService = fitScoreService ?? FitScoreService()
  self.collegeService = collegeService ?? CollegeScorecardService()
  self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
}

// AFTER:
init(
  schoolId: String,
  schoolsService: any SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
  authManager: any AuthManaging = AuthManager.shared,
  familyManager: FamilyManager = .shared,
  fitScoreService: any FitScoreManaging = FitScoreService(),
  collegeService: any CollegeScorecardManaging = CollegeScorecardService(),
  coachesService: any CoachesManaging = CoachesServiceImpl(supabaseManager: .shared)
) {
  self.schoolId = schoolId
  self.schoolsService = schoolsService
  self.authManager = authManager
  self.familyManager = familyManager
  self.fitScoreService = fitScoreService
  self.collegeService = collegeService
  self.coachesService = coachesService
}
```

Note: This `init` is NOT `nonisolated` yet. If the compiler complains about `@MainActor init` with concrete default values, add `nonisolated` and move the assignment into a separate method, or use the same `nonisolated init` pattern as EventDetailViewModel.

**Step 2: Build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`. If build fails due to `nonisolated` requirements, add `nonisolated` to the init.

**Step 3: Run SchoolDetailViewModel tests**

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase1Tests 2>&1 | tail -5
```

Expected: `TEST SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift
git commit -m "refactor: standardize DI pattern in SchoolDetailViewModel to match EventDetailViewModel"
```

---

## Task 8: Fix optional-to-Bool Binding boilerplate for alerts

Covers issue #6. Both EventDetailView and EventsListView use manual `Binding(get:set:)` to show `.alert` for optional string state. Replace with `.alert(_:isPresented:presenting:)`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Step 1: Update EventDetailView.swift — replace the error alert (lines 70–78)**

```swift
// BEFORE:
.alert("Error", isPresented: Binding(
  get: { viewModel.error != nil && viewModel.event != nil },
  set: { if !$0 { viewModel.error = nil } }
)) {
  Button("Retry") { Task { await viewModel.loadAll() } }
  Button("OK", role: .cancel) { viewModel.error = nil }
} message: {
  Text(viewModel.error ?? "")
}

// AFTER:
.alert("Error", isPresented: .init(
  get: { viewModel.error != nil && viewModel.event != nil },
  set: { if !$0 { viewModel.error = nil } }
), presenting: viewModel.error) { _ in
  Button("Retry") { Task { await viewModel.loadAll() } }
  Button("OK", role: .cancel) { viewModel.error = nil }
} message: { error in
  Text(error)
}
```

**Step 2: Update EventsListView.swift — replace the error alert (lines 50–58)**

```swift
// BEFORE:
.alert("Error", isPresented: Binding(
  get: { viewModel.error != nil },
  set: { if !$0 { viewModel.error = nil } }
)) {
  Button("Retry") { Task { await viewModel.loadEvents() } }
  Button("OK", role: .cancel) { viewModel.error = nil }
} message: {
  Text(viewModel.error ?? "")
}

// AFTER:
.alert("Error", isPresented: .init(
  get: { viewModel.error != nil },
  set: { if !$0 { viewModel.error = nil } }
), presenting: viewModel.error) { _ in
  Button("Retry") { Task { await viewModel.loadEvents() } }
  Button("OK", role: .cancel) { viewModel.error = nil }
} message: { error in
  Text(error)
}
```

**Step 3: Build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventDetailView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "refactor: replace manual Binding boilerplate with alert(presenting:) for optional error state"
```

---

## Task 9: Fix navigation pattern in EventsListView

Covers issue #8. Two separate `Bool` navigation states (`showCreateEvent`, `isShowingCreatedDetail`) can conflict. Replace with a single `EventsListDestination?` enum.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Step 1: Add navigation enum and replace @State vars**

Replace:
```swift
@State private var showCreateEvent = false
@State private var isShowingCreatedDetail = false
@State private var createdEventIdForDetail: String = ""
```

With:
```swift
private enum EventsListDestination: Hashable {
  case createEvent
  case createdEventDetail(eventId: String)
}

@State private var navigationDestination: EventsListDestination?
```

**Step 2: Update `.navigationDestination` modifiers**

Replace:
```swift
.navigationDestination(isPresented: $showCreateEvent) {
  createEventDestination
}
.navigationDestination(isPresented: $isShowingCreatedDetail) {
  EventDetailView(eventId: createdEventIdForDetail)
}
```

With:
```swift
.navigationDestination(item: $navigationDestination) { destination in
  switch destination {
  case .createEvent:
    createEventDestination
  case .createdEventDetail(let eventId):
    EventDetailView(eventId: eventId)
  }
}
```

**Step 3: Update toolbar button**

```swift
// BEFORE:
Button { showCreateEvent = true } label: { ... }

// AFTER:
Button { navigationDestination = .createEvent } label: { ... }
```

**Step 4: Update `createEventDestination` computed property**

The `CreateEventViewWrapper` callback needs to set the new destination:

```swift
private var createEventDestination: some View {
  CreateEventViewWrapper(
    onEventCreated: { eventId in
      navigationDestination = .createdEventDetail(eventId: eventId)
      Task { await viewModel.loadEvents() }
    }
  )
}
```

**Step 5: Update `emptyState` button**

```swift
// BEFORE:
Button("Add Event") { showCreateEvent = true }

// AFTER:
Button("Add Event") { navigationDestination = .createEvent }
```

**Step 6: Build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 7: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "refactor: replace dual isPresented navigation booleans with EventsListDestination enum"
```

---

## Task 10: Fix @Environment injection in CreateEventViewWrapper

Covers issue #9. `CreateEventViewWrapper` accesses `AuthManager` from environment when it only needs `userId: String`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`

**Step 1: Identify where `CreateEventViewWrapper` is instantiated**

In `EventsListView`, the `createEventDestination` computed property creates `CreateEventViewWrapper`. The view itself uses `@Environment(AuthManager.self)` to read `userId`.

**Step 2: Change `CreateEventViewWrapper` to receive userId directly**

Instead of reading `AuthManager` from environment, read `userId` from environment (or pass it from the parent):

```swift
// BEFORE (at bottom of EventsListView.swift):
private struct CreateEventViewWrapper: View {
  @Environment(AuthManager.self) private var authManager
  let onEventCreated: (String) -> Void

  var body: some View {
    if let userId = authManager.user?.id {
      CreateEventView(
        eventsService: EventsServiceImpl(),
        userId: userId,
        onEventCreated: onEventCreated
      )
    }
  }
}

// AFTER:
private struct CreateEventViewWrapper: View {
  let userId: String
  let onEventCreated: (String) -> Void

  var body: some View {
    CreateEventView(
      eventsService: EventsServiceImpl(),
      userId: userId,
      onEventCreated: onEventCreated
    )
  }
}
```

**Step 3: Update the call site in `createEventDestination`**

`EventsListView` has access to `AuthManager` via `@Environment`, so read `userId` there and pass it down:

```swift
// In EventsListView, add:
@Environment(AuthManager.self) private var authManager

// Update createEventDestination:
private var createEventDestination: some View {
  if let userId = authManager.user?.id {
    CreateEventViewWrapper(
      userId: userId,
      onEventCreated: { eventId in
        navigationDestination = .createdEventDetail(eventId: eventId)
        Task { await viewModel.loadEvents() }
      }
    )
  }
}
```

**Step 4: Build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift
git commit -m "refactor: pass userId directly to CreateEventViewWrapper instead of full AuthManager"
```

---

## Task 11: Fix deprecated Alert API in SchoolDetailView

Covers issue #11. `SchoolDetailView` uses the deprecated `Alert(title:message:primaryButton:secondaryButton:)` constructor via `.alert(item:)`. Migrate to modern `.alert(_:isPresented:)` and `.confirmationDialog`.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`

**Step 1: Replace `.alert(item: $viewModel.activeAlert)` block**

The current block handles three `AlertType` cases in one `.alert(item:)` call. Split into two separate modifiers matching modern patterns:

```swift
// REMOVE the existing .alert(item:) block (lines 43–71)
// ADD two separate modifiers after .task:

.alert("Error", isPresented: Binding(
  get: { viewModel.activeAlert == .error(viewModel.errorMessage ?? "") ||
         viewModel.activeAlert == .deleteError(viewModel.deleteErrorMessage ?? "") },
  set: { if !$0 { viewModel.activeAlert = nil } }
), presenting: viewModel.errorMessage) { _ in
  Button("OK") { viewModel.activeAlert = nil }
} message: { message in
  Text(message)
}
.confirmationDialog(
  "Delete School?",
  isPresented: Binding(
    get: { viewModel.activeAlert == .deleteConfirmation },
    set: { if !$0 { viewModel.activeAlert = nil } }
  ),
  titleVisibility: .visible
) {
  Button("Delete", role: .destructive) {
    Task {
      await viewModel.deleteSchool { dismiss() }
    }
  }
  Button("Cancel", role: .cancel) { viewModel.activeAlert = nil }
} message: {
  Text("This will permanently delete the school and all related data. This action cannot be undone.")
}
```

Note: The `AlertType` enum has `Equatable` conformance needed for the `==` check — add it if missing, or simplify by using a separate `Bool` property on the ViewModel (`var showDeleteConfirmation: Bool` already exists).

**Step 2: Simplify using existing ViewModel bool state**

`SchoolDetailViewModel` already has `showDeleteConfirmation: Bool`. Use that directly:

```swift
// After .task, add:
.alert("Error", isPresented: Binding(
  get: { viewModel.errorMessage != nil && !viewModel.showDeleteConfirmation },
  set: { if !$0 { viewModel.errorMessage = nil; viewModel.activeAlert = nil } }
), presenting: viewModel.errorMessage) { _ in
  Button("OK") { viewModel.errorMessage = nil; viewModel.activeAlert = nil }
} message: { message in
  Text(message)
}
.confirmationDialog(
  "Delete School?",
  isPresented: $viewModel.showDeleteConfirmation,
  titleVisibility: .visible
) {
  Button("Delete", role: .destructive) {
    Task { await viewModel.deleteSchool { dismiss() } }
  }
  Button("Cancel", role: .cancel) {}
} message: {
  Text("This will permanently delete the school and all related data. This action cannot be undone.")
}
```

Also update `SchoolDetailViewModel.confirmDelete()` to not set `activeAlert = .deleteConfirmation` (it already sets `showDeleteConfirmation = true`, which is sufficient).

**Step 3: Remove the `AlertType` enum if it's no longer needed**

Check if `AlertType` is used anywhere else:
```bash
grep -r "AlertType" /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass/TheRecruitingCompass
```
If only used in SchoolDetailViewModel and SchoolDetailView, remove the file after cleaning up all references.

**Step 4: Build and run SchoolDetail tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED`

**Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift
git commit -m "refactor: replace deprecated Alert API with modern alert/confirmationDialog in SchoolDetailView"
```

---

## Task 12: Remove placeholder navigation destination

Covers issue #10. `SchoolDetailView` has `Text("Add Interaction for School: \(schoolId)")` as a navigation destination.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`

**Step 1: Check if AddInteractionView exists**

```bash
find /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass -name "AddInteraction*.swift" | head -5
```

**Step 2a: If AddInteractionView exists, wire it up**

```swift
case .addInteraction(let schoolId):
  AddInteractionView(schoolId: schoolId)
```

**Step 2b: If it doesn't exist yet, use ContentUnavailableView**

```swift
case .addInteraction:
  ContentUnavailableView(
    "Coming Soon",
    systemImage: "bubble.left.and.text.bubble.right",
    description: Text("Log interactions from the Interactions tab.")
  )
```

**Step 3: Build and commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift
git commit -m "refactor: replace placeholder nav destination with proper view in SchoolDetailView"
```

---

## Task 13: Standardize withLoading vs defer pattern

Covers issue #18. SchoolDetailViewModel uses `withLoading(setting:operation:)` with `ReferenceWritableKeyPath`. EventDetailViewModel uses `defer { flag = false }`. Both patterns are valid — but they should be consistent within the codebase. Decision: keep `withLoading` in SchoolDetailViewModel (it's more elegant there given the many operations) and add a similar `withLoading` to EventDetailViewModel where it reduces repetition.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`

**Step 1: Add `withLoading` to EventDetailViewModel**

Add after the `// MARK: - Dependencies` section, before `// MARK: - Computed`:

```swift
// MARK: - Loading Helper

@discardableResult
private func withLoading<T>(
  setting flag: ReferenceWritableKeyPath<EventDetailViewModel, Bool>,
  operation: () async throws -> T
) async rethrows -> T {
  self[keyPath: flag] = true
  defer { self[keyPath: flag] = false }
  return try await operation()
}
```

**Step 2: Refactor methods to use withLoading where it cleanly applies**

`updateEvent()`:
```swift
func updateEvent() async {
  await withLoading(setting: \.isSaving) {
    do {
      let request = editData.toUpdateRequest()
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      event = updated
      showEditSheet = false
      haptics.success()
      showSuccess("Event updated")
    } catch {
      self.error = "Failed to update event. Please try again."
      haptics.error()
    }
  }
}
```

Apply the same to `markAsAttended()`, `deleteEvent()`, `logInteraction()`, `addMetric()`, `addCoach()`, `removeCoach()`.

**Step 3: Build and run all EventDetailViewModel tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/EventDetailViewModelTests 2>&1 | tail -10
```

Expected: `TEST SUCCEEDED`

**Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git add TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift
git commit -m "refactor: standardize loading state management with withLoading helper in EventDetailViewModel"
```

---

## Task 14: Full test suite verification and PR

**Step 1: Run the full unit test suite**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED` — all 126+ tests pass

**Step 2: Fix any test failures**

If tests fail, read the error output and fix the specific test. Do not modify tests to match broken behavior — fix the implementation.

**Step 3: Update MEMORY.md**

Add to the project memory file `/Users/chrisandrikanich/.claude/projects/-Volumes-AlphabetSoup-TheRecruitingCompass-code-recruiting-compass-ios/memory/MEMORY.md`:

```
## Completed Refactors (2026-02-18)
- SwiftUI code review fixes: deprecated APIs, EventUpdateRequest defaults, DateFormatting shared utility, MetricsExportService extraction, haptics consistency, navigation enum, DI pattern standardization
- `EventUpdateRequest` now has default `nil` values — pass only changed fields
- `DateFormatting.isoDateString()` / `isoDateRangeString()` / `isoExportFormatter` now available
- `MetricsExportService` handles CSV file I/O (was in EventDetailViewModel)
```

**Step 4: Push branch and open PR**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.worktrees/swiftui-code-review
git push -u origin refactor/swiftui-code-review
```

---

## Unresolved Questions

1. **God Object decomposition (issues #1 and #2):** Full decomposition of `EventDetailViewModel` and `SchoolDetailViewModel` into child VMs requires a separate planning session. Both VMs have 1000+ lines of tests tightly coupled to their current interface. Scope creep risk is high. Recommend a dedicated `refactor/viewmodel-decomposition` branch after this PR is merged.

2. **`SchoolDetailView` Add Interaction destination (Task 12):** Depends on whether `AddInteractionView` already exists (check during execution). If not, use `ContentUnavailableView` as placeholder until the interaction flow is built.

3. **`AlertType` enum removal (Task 11):** Only safe to remove if no other file references it. Verify with grep before deleting.
