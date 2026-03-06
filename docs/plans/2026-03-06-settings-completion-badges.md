# Settings Completion Badges Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show "Complete" / "Incomplete" pill badges on the Home Location, Player Details, and School Preferences settings rows, mirroring the web app's completion logic.

**Architecture:** Add a `SettingsBadgeStatus` enum, a new `SettingsViewModel` that fetches all three preference types in parallel on `.task`, and extend `SettingsRow` to render an optional badge pill. Completion criteria match the web app exactly.

**Tech Stack:** SwiftUI, Swift `@Observable`, `PreferenceManaging` protocol, XCTest

---

## Completion Criteria (parity with web app)

| Section | Complete when |
|---|---|
| Home Location | `latitude != nil && longitude != nil` |
| Player Details | `graduationYear != nil` OR `positions` non-empty |
| School Preferences | `preferences` array non-empty |

---

## Key Paths

| What | Where |
|---|---|
| Source root | `TheRecruitingCompass/TheRecruitingCompass/` |
| Test root | `TheRecruitingCompass/TheRecruitingCompassTests/` |
| `SettingsView.swift` | `Features/Settings/Views/SettingsView.swift` |
| `PreferenceManaging.swift` | `Features/Preferences/Services/PreferenceManaging.swift` |
| `MockPreferenceManager.swift` | `TheRecruitingCompassTests/Features/Preferences/Mocks/MockPreferenceManager.swift` |
| Models | `Features/Preferences/Models/` (`HomeLocation`, `PlayerDetails`, `SchoolPreferences`) |
| `PreferenceCategory` | `Features/Preferences/Models/PreferenceCategory.swift` |

---

## Task 1: Add `SettingsBadgeStatus` enum

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Models/SettingsBadgeStatus.swift`

**Step 1: Create the file**

```swift
import SwiftUI

enum SettingsBadgeStatus {
  case complete
  case incomplete

  var label: String {
    switch self {
    case .complete: return "Complete"
    case .incomplete: return "Incomplete"
    }
  }

  var foregroundColor: Color {
    switch self {
    case .complete: return Color(red: 0.06, green: 0.52, blue: 0.28)   // emerald-700
    case .incomplete: return Color(red: 0.65, green: 0.44, blue: 0.09) // amber-700
    }
  }

  var backgroundColor: Color {
    switch self {
    case .complete: return Color(red: 0.85, green: 0.97, blue: 0.90)   // emerald-100
    case .incomplete: return Color(red: 0.99, green: 0.95, blue: 0.83) // amber-100
    }
  }
}
```

**Step 2: Build to confirm it compiles**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add TheRecruitingCompass/Features/Settings/Models/SettingsBadgeStatus.swift
git commit -m "feat(settings): add SettingsBadgeStatus enum for completion badges"
```

---

## Task 2: Add `SettingsViewModel` with tests (TDD)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/ViewModels/SettingsViewModel.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Settings/ViewModels/SettingsViewModelTests.swift`

### Step 1: Write the failing tests first

Create the test file:

```swift
import XCTest
@testable import TheRecruitingCompass

// A smarter mock that returns different data per category
final class MockPerCategoryPreferenceManager: PreferenceManaging, @unchecked Sendable {
  var results: [PreferenceCategory: Any?] = [:]
  var shouldThrow = false

  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    if shouldThrow { throw NSError(domain: "Test", code: 0) }
    return results[category] as? T
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T {
    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {}
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
  var viewModel: SettingsViewModel!
  var mockService: MockPerCategoryPreferenceManager!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPerCategoryPreferenceManager()
    viewModel = SettingsViewModel(preferenceService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Initial state

  func testInitialState_StatusesAreNil() {
    XCTAssertNil(viewModel.homeLocationStatus)
    XCTAssertNil(viewModel.playerDetailsStatus)
    XCTAssertNil(viewModel.schoolPreferencesStatus)
  }

  // MARK: - Home Location

  func testHomeLocationStatus_WithCoordinates_IsComplete() async {
    mockService.results[.location] = HomeLocation(
      address: nil, city: "Austin", state: "TX", zip: nil,
      latitude: 30.27, longitude: -97.74
    )
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .complete)
  }

  func testHomeLocationStatus_WithoutCoordinates_IsIncomplete() async {
    mockService.results[.location] = HomeLocation(
      address: nil, city: "Austin", state: "TX", zip: nil,
      latitude: nil, longitude: nil
    )
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .incomplete)
  }

  func testHomeLocationStatus_Nil_IsIncomplete() async {
    mockService.results[.location] = Optional<HomeLocation>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .incomplete)
  }

  // MARK: - Player Details

  func testPlayerDetailsStatus_WithGraduationYear_IsComplete() async {
    var details = PlayerDetails()
    details.graduationYear = 2027
    mockService.results[.player] = details
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
  }

  func testPlayerDetailsStatus_WithPositions_IsComplete() async {
    var details = PlayerDetails()
    details.positions = ["Pitcher", "Outfield"]
    mockService.results[.player] = details
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
  }

  func testPlayerDetailsStatus_EmptyDetails_IsIncomplete() async {
    mockService.results[.player] = PlayerDetails()
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .incomplete)
  }

  func testPlayerDetailsStatus_Nil_IsIncomplete() async {
    mockService.results[.player] = Optional<PlayerDetails>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .incomplete)
  }

  // MARK: - School Preferences

  func testSchoolPreferencesStatus_WithPreferences_IsComplete() async {
    let prefs = SchoolPreferences(
      preferences: [
        SchoolPreference(id: "1", category: .location, type: "max_distance_miles",
                         value: .int(500), priority: 1, isDealbreaker: false)
      ],
      templateUsed: nil, lastUpdated: nil
    )
    mockService.results[.school] = prefs
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .complete)
  }

  func testSchoolPreferencesStatus_EmptyPreferences_IsIncomplete() async {
    mockService.results[.school] = SchoolPreferences(preferences: [], templateUsed: nil, lastUpdated: nil)
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }

  func testSchoolPreferencesStatus_Nil_IsIncomplete() async {
    mockService.results[.school] = Optional<SchoolPreferences>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }

  // MARK: - Error handling

  func testLoadCompletionStatus_OnError_StatusesRemainNil() async {
    mockService.shouldThrow = true
    await viewModel.loadCompletionStatus()
    // Errors are swallowed — statuses stay nil (badges just won't show)
    XCTAssertNil(viewModel.homeLocationStatus)
    XCTAssertNil(viewModel.playerDetailsStatus)
    XCTAssertNil(viewModel.schoolPreferencesStatus)
  }

  // MARK: - Parallel loading

  func testLoadCompletionStatus_AllThreeLoaded_AllStatusesSet() async {
    var details = PlayerDetails()
    details.graduationYear = 2028
    mockService.results[.location] = HomeLocation(
      address: nil, city: nil, state: nil, zip: nil,
      latitude: 30.27, longitude: -97.74
    )
    mockService.results[.player] = details
    mockService.results[.school] = SchoolPreferences(preferences: [], templateUsed: nil, lastUpdated: nil)

    await viewModel.loadCompletionStatus()

    XCTAssertEqual(viewModel.homeLocationStatus, .complete)
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }
}
```

**Step 2: Run tests to confirm they fail (SettingsViewModel doesn't exist yet)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/SettingsViewModelTests \
  2>&1 | tail -10
```

Expected: build error — `SettingsViewModel` not found.

**Step 3: Implement `SettingsViewModel`**

```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SettingsViewModel"
)

@Observable
@MainActor
final class SettingsViewModel {
  var homeLocationStatus: SettingsBadgeStatus?
  var playerDetailsStatus: SettingsBadgeStatus?
  var schoolPreferencesStatus: SettingsBadgeStatus?

  private let preferenceService: any PreferenceManaging

  init(preferenceService: any PreferenceManaging) {
    self.preferenceService = preferenceService
  }

  nonisolated deinit {}

  func loadCompletionStatus() async {
    logger.debug("Loading completion status for settings badges")
    async let locationResult: HomeLocation? = fetchSilently(category: .location)
    async let playerResult: PlayerDetails? = fetchSilently(category: .player)
    async let schoolResult: SchoolPreferences? = fetchSilently(category: .school)

    let (location, player, school) = await (locationResult, playerResult, schoolResult)

    homeLocationStatus = location.map { loc in
      (loc.latitude != nil && loc.longitude != nil) ? .complete : .incomplete
    } ?? .incomplete

    playerDetailsStatus = player.map { details in
      (details.graduationYear != nil || details.positions?.isEmpty == false) ? .complete : .incomplete
    } ?? .incomplete

    schoolPreferencesStatus = school.map { prefs in
      prefs.preferences.isEmpty ? .incomplete : .complete
    } ?? .incomplete

    logger.info("Completion status loaded — location: \(String(describing: self.homeLocationStatus)), player: \(String(describing: self.playerDetailsStatus)), school: \(String(describing: self.schoolPreferencesStatus))")
  }

  // MARK: - Private

  private func fetchSilently<T: Codable>(category: PreferenceCategory) async -> T? {
    do {
      return try await preferenceService.fetchPreferences(category: category)
    } catch {
      logger.error("Failed to fetch \(category.rawValue) for badge status: \(error.localizedDescription)")
      return nil
    }
  }
}
```

**Step 4: Run tests — confirm they pass**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/SettingsViewModelTests \
  2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

**Step 5: Commit**

```bash
git add \
  TheRecruitingCompass/Features/Settings/ViewModels/SettingsViewModel.swift \
  TheRecruitingCompassTests/Features/Settings/ViewModels/SettingsViewModelTests.swift
git commit -m "feat(settings): add SettingsViewModel for completion badge status"
```

---

## Task 3: Update `SettingsRow` to support an optional badge

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`

The `SettingsRow` struct lives at the bottom of `SettingsView.swift`. Add an optional `badgeStatus` parameter and render a pill badge inline with the title.

**Step 1: Update `SettingsRow`**

Replace the existing `SettingsRow` struct (lines ~192–224) with:

```swift
private struct SettingsRow: View {
  let icon: String
  let title: String
  let description: String
  let color: Color
  var badgeStatus: SettingsBadgeStatus? = nil

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.white)
        .frame(width: 36, height: 36)
        .background(color)
        .cornerRadius(8)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(title)
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.primary)

          if let status = badgeStatus {
            Text(status.label)
              .font(.caption2.weight(.medium))
              .foregroundColor(status.foregroundColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(status.backgroundColor)
              .clipShape(Capsule())
          }
        }

        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(badgeStatus.map { "\(title): \($0.label). \(description)" } ?? "\(title): \(description)")
  }
}
```

**Step 2: Build to confirm no regressions**

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add TheRecruitingCompass/Features/Settings/Views/SettingsView.swift
git commit -m "feat(settings): add optional badge pill to SettingsRow"
```

---

## Task 4: Wire `SettingsViewModel` into `SettingsView`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`

**Step 1: Add the ViewModel and wire up `.task` + badge props**

Replace the top of `SettingsView` body (the struct body, not the `List`):

1. Add `@State private var viewModel: SettingsViewModel` alongside existing `@State` vars:

```swift
@State private var viewModel: SettingsViewModel
```

2. Update the `init` to create the ViewModel:

```swift
init(preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)) {
  self.preferenceService = preferenceService
  _viewModel = State(initialValue: SettingsViewModel(preferenceService: preferenceService))
}
```

3. Pass badge status to the three rows that need it. Find the three `SettingsRow` calls and add `badgeStatus:`:

**Home Location row** (inside the `NavigationLink` label):
```swift
SettingsRow(
  icon: "house.fill",
  title: "Home Location",
  description: "Set your home address to calculate distances to schools",
  color: .blue,
  badgeStatus: viewModel.homeLocationStatus
)
```

**Player Details row**:
```swift
SettingsRow(
  icon: "person.fill",
  title: "Player Details",
  description: "Graduation year, positions, stats, and athletic profile",
  color: .green,
  badgeStatus: viewModel.playerDetailsStatus
)
```

**School Preferences row**:
```swift
SettingsRow(
  icon: "target",
  title: "School Preferences",
  description: "Set criteria for finding your ideal schools",
  color: .purple,
  badgeStatus: viewModel.schoolPreferencesStatus
)
```

4. Add `.task` to reload after navigation returns (badges refresh when you come back from a detail screen). Add this alongside the existing `.task { await familyManager.loadFamilyData() }`:

```swift
.task {
  await familyManager.loadFamilyData()
  await viewModel.loadCompletionStatus()
}
```

**Step 2: Build**

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Run full unit test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skip-testing TheRecruitingCompassUITests \
  2>&1 | grep -E "(PASSED|FAILED|error:)" | tail -20
```

Expected: All tests pass, no regressions.

**Step 4: Commit**

```bash
git add TheRecruitingCompass/Features/Settings/Views/SettingsView.swift
git commit -m "feat(settings): wire SettingsViewModel to show completion badges on settings rows"
```

---

## Verification Checklist

- [ ] Badges are absent on first load (nil), appear once `.task` completes
- [ ] Home Location: shows "Complete" when city/state geocoded (lat/lon present)
- [ ] Home Location: shows "Incomplete" when address saved but not geocoded
- [ ] Player Details: shows "Complete" with just a graduation year set
- [ ] Player Details: shows "Complete" with positions but no year
- [ ] School Preferences: shows "Complete" after adding any preference
- [ ] School Preferences: shows "Incomplete" with empty preferences list
- [ ] Navigating to a detail screen and saving updates badge on return
- [ ] Badge pill text is read by VoiceOver as part of the row label
- [ ] Rows without badges (Notifications, Dashboard, etc.) unchanged
