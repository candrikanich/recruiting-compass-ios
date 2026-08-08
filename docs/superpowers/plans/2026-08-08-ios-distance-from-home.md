# iOS Distance from Home — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show "Distance from Home: N miles" under the school map (and keep the Schools list distance working) by reading home coordinates from the web-compatible `user_preferences` (`location`) store instead of the dead `family_units` columns, with web-parity distance math and a CTA when home is unset.

**Architecture:** `SchoolDetailViewModel` gains a `PreferenceManaging` dependency and loads `HomeLocation` from `user_preferences` (category `.location`), exposing `homeCoordinate`. `SchoolDetailView` passes that (not the dead `FamilyUnit` coords) into `SchoolMapView`, which renders distance, a set-home CTA, or the existing no-school-coords empty state. `DistanceCalculator` is upgraded to the web haversine formula + a `formatMiles` helper, and both `SchoolMapView` and the Schools list route through it. The Schools list VM drops its dead `FamilyUnit` branch.

**Tech Stack:** Swift, SwiftUI, CoreLocation, XCTest. Xcode 26.x / iOS 26.5 simulator (iPhone 17).

## Global Constraints

- Source of truth for home coords: `user_preferences` table, category `location` (Swift `PreferenceCategory.location`), JSON fields `latitude`/`longitude` — decoded via the existing `HomeLocation` model. Never read/write `family_units.home_latitude/home_longitude` (dead, absent from web schema).
- Distance formula MUST match web `utils/distance.ts`: haversine, Earth radius `R = 3958.8` miles, `round()` to nearest whole mile.
- Distance label format MUST match web `formatDistance`: `"<n> miles"` with thousands separator (e.g. `"1,234 miles"`).
- All user-visible strings use `String(localized:)`. Keep the number + " miles" as ONE localized unit — do not split into separate keys.
- All ViewModels are `@Observable @MainActor` with `nonisolated deinit {}` (project rule for macOS 26 test teardown).
- Line length ≤ 120 (SwiftLint). No `foregroundColor`/`NavigationView`/`print`/`try!`/`as!` in app source.
- Build/test from `TheRecruitingCompass/` (the Xcode project wrapper). Source files use the double-nested path `TheRecruitingCompass/TheRecruitingCompass/...`.
- New `.swift` files are auto-included (PBXFileSystemSynchronizedRootGroup) — do NOT edit the `.xcodeproj`.
- Button hit targets ≥ 44×44pt; decorative icons `.accessibilityHidden(true)`.

Build: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Test one class: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/<ClassName>`

---

## File Structure

- `Core/Utilities/DistanceCalculator.swift` (modify) — web-parity haversine + `milesRounded` + `formatMiles`.
- `Core/Utilities/DistanceCalculatorTests.swift` under `TheRecruitingCompassTests/Core/Utilities/` (create) — formula + format tests.
- `Features/Schools/ViewModels/SchoolDetailViewModel.swift` (modify) — inject `preferenceService`, add `homeCoordinate` + `loadHomeLocation()`.
- `Features/Schools/Views/SchoolDetailView.swift` (modify) — repoint home coords, pass `preferenceService`, present Home Location sheet, reload on dismiss.
- `Features/Schools/Components/SchoolMapView.swift` (modify) — 3 states incl. set-home CTA; route distance through `DistanceCalculator`; add testable computed state.
- `Features/Schools/ViewModels/SchoolsListViewModel.swift` (modify) — drop dead `FamilyUnit` home branch.
- Tests: `SchoolDetailViewModelPhase1Tests.swift` (modify — pass mock), plus new assertions in the Schools detail/list test files as noted.

---

### Task 1: Web-parity distance math in `DistanceCalculator`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/DistanceCalculator.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/DistanceCalculatorTests.swift` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `DistanceCalculator.haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double` (miles, unrounded — signature unchanged, formula updated).
  - `DistanceCalculator.milesRounded(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int` (rounded, web parity).
  - `DistanceCalculator.formatMiles(_ miles: Int) -> String` (localized, thousands separator, includes " miles").

- [ ] **Step 1: Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/DistanceCalculatorTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import TheRecruitingCompass

final class DistanceCalculatorTests: XCTestCase {
  nonisolated deinit {}

  // Winston-Salem, NC (Wake Forest area) -> a home ~372 mi away.
  // Reference pair validated against web utils/distance.ts (R = 3958.8, Math.round).
  private let wakeForest = CLLocationCoordinate2D(latitude: 36.1330, longitude: -80.2770)
  private let home = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060) // NYC

  func testHaversineDistance_matchesWebFormula_withinTolerance() {
    // Web: haversine, R = 3958.8 miles.
    let miles = DistanceCalculator.haversineDistance(from: home, to: wakeForest)
    // Great-circle NYC <-> Winston-Salem ~= 425 mi. Assert the formula is in range
    // and stable (not the old meters/1609.34 path, which this replaces).
    XCTAssertEqual(miles, 425, accuracy: 5)
  }

  func testMilesRounded_roundsToNearestWholeMile() {
    let rounded = DistanceCalculator.milesRounded(from: home, to: wakeForest)
    let raw = DistanceCalculator.haversineDistance(from: home, to: wakeForest)
    XCTAssertEqual(rounded, Int(raw.rounded()))
  }

  func testMilesRounded_zeroForSameCoordinate() {
    XCTAssertEqual(DistanceCalculator.milesRounded(from: home, to: home), 0)
  }

  func testFormatMiles_addsThousandsSeparatorAndUnit() {
    XCTAssertEqual(DistanceCalculator.formatMiles(1234), "1,234 miles")
  }

  func testFormatMiles_smallValue() {
    XCTAssertEqual(DistanceCalculator.formatMiles(372), "372 miles")
  }

  func testFormatMiles_zero() {
    XCTAssertEqual(DistanceCalculator.formatMiles(0), "0 miles")
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DistanceCalculatorTests`
Expected: FAIL — `milesRounded`/`formatMiles` don't exist yet (compile failure is an acceptable RED).

- [ ] **Step 3: Implement the web-parity formula + helpers**

Replace the body of `DistanceCalculator.swift` with:

```swift
import Foundation
import CoreLocation

enum DistanceCalculator {
  /// Earth's radius in miles — matches web `utils/distance.ts`.
  private static let earthRadiusMiles = 3958.8

  /// Great-circle distance in miles (unrounded). Haversine, matching the web app.
  static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let deltaLat = (to.latitude - from.latitude) * .pi / 180
    let deltaLon = (to.longitude - from.longitude) * .pi / 180

    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
      + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadiusMiles * c
  }

  /// Distance in whole miles, rounded to nearest — matches web `Math.round`.
  static func milesRounded(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    Int(haversineDistance(from: from, to: to).rounded())
  }

  /// Localized "N miles" with thousands separator — matches web `formatDistance`.
  static func formatMiles(_ miles: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let number = formatter.string(from: NSNumber(value: miles)) ?? "\(miles)"
    return String(localized: "\(number) miles")
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/DistanceCalculatorTests`
Expected: PASS (6 tests).

Note: `formatMiles` tests assume the test simulator locale uses `,` as the thousands separator (US default). If CI locale differs, that's an environment concern, not a logic bug.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/DistanceCalculator.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/DistanceCalculatorTests.swift
git commit -m "feat: web-parity haversine + formatMiles in DistanceCalculator

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

### Task 2: `SchoolDetailViewModel` loads home from `user_preferences`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift:74-105`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelPhase1Tests.swift` (add tests + pass mock in setUp)

**Interfaces:**
- Consumes: `PreferenceManaging.fetchPreferences<T: Codable>(category:) async throws -> T?`, `HomeLocation` model, `PreferenceCategory.location`, `MockPreferenceManager` (test).
- Produces:
  - `SchoolDetailViewModel.init(..., preferenceService: (any PreferenceManaging)? = nil, ...)` — new optional param, defaults to `PreferenceServiceImpl(supabaseManager: .shared)`.
  - `SchoolDetailViewModel.homeCoordinate: CLLocationCoordinate2D?` (`private(set)`).
  - `SchoolDetailViewModel.loadHomeLocation() async`.

- [ ] **Step 1: Write the failing tests**

Add to `SchoolDetailViewModelPhase1Tests.swift` (inside the class). Also add a `mockPreferenceService` property and pass it in `setUp` (Step 3 covers wiring):

```swift
func testLoadHomeLocation_setsCoordinate_whenPreferencesHaveLatLon() async {
  mockPreferenceService.fetchPreferencesResult = .success(
    HomeLocation(address: nil, city: nil, state: nil, zip: nil,
                 latitude: 40.7128, longitude: -74.0060)
  )

  await viewModel.loadHomeLocation()

  XCTAssertEqual(viewModel.homeCoordinate?.latitude, 40.7128)
  XCTAssertEqual(viewModel.homeCoordinate?.longitude, -74.0060)
  XCTAssertTrue(mockPreferenceService.fetchPreferencesCalls.contains(.location))
}

func testLoadHomeLocation_nil_whenLongitudeMissing() async {
  mockPreferenceService.fetchPreferencesResult = .success(
    HomeLocation(address: nil, city: nil, state: nil, zip: nil,
                 latitude: 40.7128, longitude: nil)
  )

  await viewModel.loadHomeLocation()

  XCTAssertNil(viewModel.homeCoordinate)
}

func testLoadHomeLocation_nil_whenNoPreferences() async {
  mockPreferenceService.fetchPreferencesResult = .success(Optional<HomeLocation>.none as Any?)

  await viewModel.loadHomeLocation()

  XCTAssertNil(viewModel.homeCoordinate)
}

func testLoadHomeLocation_nil_andDoesNotThrow_whenFetchFails() async {
  mockPreferenceService.fetchPreferencesResult = .failure(
    NSError(domain: "test", code: 1)
  )

  await viewModel.loadHomeLocation()

  XCTAssertNil(viewModel.homeCoordinate)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase1Tests`
Expected: FAIL — `mockPreferenceService`, `homeCoordinate`, `loadHomeLocation` don't exist (compile failure acceptable).

- [ ] **Step 3: Implement — inject dependency + method**

In `SchoolDetailViewModel.swift`, add to the imports at top if missing: `import CoreLocation`.

Add a stored property near the other dependencies (after line 82):

```swift
  private let preferenceService: any PreferenceManaging
```

Add the observable coordinate near the other `MARK` groups (e.g. after the College Scorecard group, ~line 58):

```swift
  // MARK: - Home Location (for distance)
  private(set) var homeCoordinate: CLLocationCoordinate2D?
```

Add the param to `init` (after `coachesService`, before `cache`):

```swift
    coachesService: (any CoachesManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    cache: (any CacheManaging)? = nil
```

And in the init body (after the `coachesService` assignment):

```swift
    self.preferenceService = preferenceService
      ?? PreferenceServiceImpl(supabaseManager: SupabaseManager.shared)
```

Add the method (in the `// MARK: - Loading` region, after `loadSchool()`):

```swift
  /// Loads the player's home coordinate from user_preferences (category `location`),
  /// the same store the web app and the Home Location settings screen use.
  /// Silent on failure: a preferences fetch error must not block the detail view —
  /// distance simply won't show.
  func loadHomeLocation() async {
    do {
      if let location: HomeLocation = try await preferenceService.fetchPreferences(category: .location),
         let lat = location.latitude,
         let lon = location.longitude {
        homeCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
      } else {
        homeCoordinate = nil
      }
    } catch {
      logger.debug("Could not load home location: \(error.localizedDescription)")
      homeCoordinate = nil
    }
  }
```

Wire the test mock in `SchoolDetailViewModelPhase1Tests.swift` setUp — add a property `var mockPreferenceService: MockPreferenceManager!`, instantiate it in `setUp` (`mockPreferenceService = MockPreferenceManager()`), pass `preferenceService: mockPreferenceService` in the `SchoolDetailViewModel(...)` call, and null it in `tearDown`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase1Tests`
Expected: PASS (existing tests + 4 new).

- [ ] **Step 5: Verify other detail-VM test files still compile/pass**

The `preferenceService` param is optional-with-default, so `Phase2`/`Phase3` construction sites need no change. Confirm:
Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase2Tests -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelPhase3Tests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolDetailViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/SchoolDetailViewModelPhase1Tests.swift
git commit -m "feat: SchoolDetailViewModel loads home coord from user_preferences

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

### Task 3: `SchoolMapView` — distance, set-home CTA, testable states

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolMapView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/SchoolMapViewTests.swift` (create)

**Interfaces:**
- Consumes: `DistanceCalculator.milesRounded`, `DistanceCalculator.formatMiles` (Task 1); `School`, `School.academicInfo?.latitude/longitude`.
- Produces:
  - `SchoolMapView(school:homeLocation:onSetHomeLocation:)` — new `onSetHomeLocation: () -> Void` closure (default `{}`).
  - `SchoolMapView.mapState` (non-private, testable) → enum `MapState { case distance(String), setHomeCTA, noSchoolCoords }`.

- [ ] **Step 1: Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/SchoolMapViewTests.swift`:

```swift
import XCTest
import CoreLocation
@testable import TheRecruitingCompass

@MainActor
final class SchoolMapViewTests: XCTestCase {
  nonisolated deinit {}

  private func school(lat: Double?, lon: Double?) -> School {
    School(
      id: "1", userId: "u1", name: "Wake Forest", location: "Winston-Salem, NC",
      city: "Winston-Salem", state: "NC", division: "D1", conference: "ACC",
      ranking: nil, isFavorite: false, website: nil, faviconUrl: nil,
      twitterHandle: nil, instagramHandle: nil, ncaaId: nil, status: "interested",
      statusChangedAt: nil, notes: nil, pros: [], cons: [], offerDetails: nil,
      academicInfo: AcademicInfo(
        gpaRequirement: nil, satRequirement: nil, actRequirement: nil,
        additionalRequirements: nil, address: nil, city: nil, state: nil,
        latitude: lat, longitude: lon, studentSize: nil,
        baseballFacilityAddress: nil, mascot: nil, undergradSize: nil,
        carnegieSize: nil, tuitionInState: nil, tuitionOutOfState: nil,
        admissionRate: nil, distanceFromHome: nil
      ),
      amenities: nil, coachingPhilosophy: nil, coachingStyle: nil,
      recruitingApproach: nil, communicationStyle: nil, successMetrics: nil,
      fitScore: nil, fitTier: nil, familyUnitId: "f1", createdBy: nil,
      updatedBy: nil, createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  func testState_distance_whenSchoolAndHomeCoordsPresent() {
    let view = SchoolMapView(
      school: school(lat: 36.1330, lon: -80.2770),
      homeLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    )
    guard case .distance(let label) = view.mapState else {
      return XCTFail("expected .distance")
    }
    XCTAssertTrue(label.contains("miles"))
  }

  func testState_setHomeCTA_whenSchoolCoordsButNoHome() {
    let view = SchoolMapView(school: school(lat: 36.1330, lon: -80.2770), homeLocation: nil)
    guard case .setHomeCTA = view.mapState else {
      return XCTFail("expected .setHomeCTA")
    }
  }

  func testState_noSchoolCoords_whenSchoolMissingCoords() {
    let view = SchoolMapView(
      school: school(lat: nil, lon: nil),
      homeLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    )
    guard case .noSchoolCoords = view.mapState else {
      return XCTFail("expected .noSchoolCoords")
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolMapViewTests`
Expected: FAIL — `mapState` / `MapState` / `onSetHomeLocation` don't exist (compile failure acceptable).

- [ ] **Step 3: Implement — states + CTA + shared calculator**

Rewrite `SchoolMapView.swift` (keep the `#Preview` block, updating the initializer call if needed):

```swift
import SwiftUI
import MapKit

struct SchoolMapView: View {
  let school: School
  let homeLocation: CLLocationCoordinate2D?
  var onSetHomeLocation: () -> Void = {}

  enum MapState: Equatable {
    case distance(String)
    case setHomeCTA
    case noSchoolCoords
  }

  /// Testable view state derived from the school + home coordinates.
  var mapState: MapState {
    guard let lat = school.academicInfo?.latitude,
          let lon = school.academicInfo?.longitude else {
      return .noSchoolCoords
    }
    guard let home = homeLocation else {
      return .setHomeCTA
    }
    let miles = DistanceCalculator.milesRounded(
      from: home,
      to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
    )
    return .distance(DistanceCalculator.formatMiles(miles))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let lat = school.academicInfo?.latitude,
         let lon = school.academicInfo?.longitude {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(
          center: coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        Map(initialPosition: .region(region)) {
          Marker(school.name, coordinate: coordinate)
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityLabel(String(localized: "Map showing \(school.name) location"))
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityHint("Use two fingers to pan and pinch to zoom the map")

        switch mapState {
        case .distance(let label):
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
              .foregroundStyle(.secondary)
              .font(.caption)
              .accessibilityHidden(true)

            Text("Distance from Home: \(label)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 4)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(String(localized: "Distance from Home: \(label)"))

        case .setHomeCTA:
          Button(action: onSetHomeLocation) {
            HStack(spacing: 6) {
              Image(systemName: "mappin.and.ellipse")
                .font(.caption)
                .accessibilityHidden(true)
              Text("Set your home location to see distance")
                .font(.subheadline)
            }
            .frame(minHeight: 44)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.tint)
          .padding(.top, 4)
          .accessibilityLabel(String(localized: "Set your home location to see distance to schools"))
          .accessibilityAddTraits(.isButton)

        case .noSchoolCoords:
          EmptyView()
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "map")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          Text("Location data not available")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("Use 'Lookup College Data' to fetch location")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Location data not available. Use Lookup College Data to fetch location"))
      }
    }
  }
}
```

Update the existing `#Preview` at the bottom of the file: keep it, and it needs no new args (the `onSetHomeLocation` default is `{}`). The old `@State private var distance` and `calculateDistance()` are removed — ensure no references remain.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolMapViewTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Components/SchoolMapView.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/SchoolMapViewTests.swift
git commit -m "feat: SchoolMapView distance/CTA states via DistanceCalculator

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

### Task 4: Wire `SchoolDetailView` — real home coord + Home Location sheet

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift:13-16,59-61,80-113`

**Interfaces:**
- Consumes: `SchoolDetailViewModel.homeCoordinate` + `.loadHomeLocation()` (Task 2); `SchoolMapView(school:homeLocation:onSetHomeLocation:)` (Task 3); `HomeLocationView(preferenceService:)`; `PreferenceServiceImpl`.
- Produces: no new public API.

- [ ] **Step 1: Add a home-location sheet state + preference service**

In `SchoolDetailView`, add state after line 11:

```swift
  @State private var showHomeLocationSheet = false
  private let preferenceService: any PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)
```

- [ ] **Step 2: Delete the dead `homeLocation` computed property**

Remove lines 80-86 (the `familyManager.familyUnit?.homeLatitude/homeLongitude` computed `homeLocation`). It is replaced by `viewModel.homeCoordinate`.

- [ ] **Step 3: Repoint `SchoolMapView` + add CTA callback**

Replace the map section (lines 108-113) with:

```swift
        // 2. Map
        SchoolMapView(
          school: school,
          homeLocation: viewModel.homeCoordinate,
          onSetHomeLocation: { showHomeLocationSheet = true }
        )
        .padding(.horizontal)
```

- [ ] **Step 4: Load home on appear + present the sheet**

Update the `.task` modifier (lines 59-61) to also load the home coordinate:

```swift
    .task {
      await viewModel.loadSchool()
      await viewModel.loadHomeLocation()
    }
```

Add a `.sheet` modifier (place alongside the existing `.alert`/`.confirmationDialog`, after line 77):

```swift
    .sheet(isPresented: $showHomeLocationSheet, onDismiss: {
      Task { await viewModel.loadHomeLocation() }
    }) {
      NavigationStack {
        HomeLocationView(preferenceService: preferenceService)
      }
    }
```

- [ ] **Step 5: Build to verify it compiles**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED, no new warnings referencing `SchoolDetailView` or `homeLocation`.

Manual check (optional but recommended): verify `HomeLocationView` renders acceptably inside a presented `NavigationStack` sheet (it is normally pushed via `navigationDestination`; confirm its own toolbar/title behaves). If it needs a Done button, that is acceptable to add here.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift
git commit -m "feat: SchoolDetailView shows real distance + set-home sheet

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

### Task 5: Schools list — drop dead `FamilyUnit` home branch

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolsListViewModel.swift:34-50,199-219`

**Interfaces:**
- Consumes: `homeLocationFromPreferences` (existing private), `preferenceService.fetchPreferences(category: .location)` (existing).
- Produces: no new public API. `homeLocation` getter now returns preferences-only.

- [ ] **Step 1: Simplify the `homeLocation` getter**

Replace the getter body (lines 35-42) so it returns preferences directly:

```swift
  var homeLocation: CLLocationCoordinate2D? {
    get { homeLocationFromPreferences }
    set {
      homeLocationFromPreferences = newValue
      recomputeFilteredSchools()
    }
  }
```

Update the doc comment on line 34 to: `/// Home location for distance filter and sort, from Settings (user_preferences).`

- [ ] **Step 2: Always load home from preferences in `loadSchools()`**

Replace the guarded block (lines 199-219) with an unconditional load:

```swift
      // Load home location from Settings (user_preferences).
      do {
        if let location: HomeLocation = try await preferenceService.fetchPreferences(category: .location),
           let lat = location.latitude, let lon = location.longitude {
          homeLocationFromPreferences = CLLocationCoordinate2D(latitude: lat, longitude: lon)
          logger.debug("Using home location from preferences")
        } else {
          homeLocationFromPreferences = nil
        }
      } catch {
        logger.debug("Could not load home location from preferences: \(error.localizedDescription)")
        homeLocationFromPreferences = nil
      }
```

- [ ] **Step 3: Check whether `familyManager` is still used**

Run: `cd TheRecruitingCompass && grep -n "familyManager" TheRecruitingCompass/Features/Schools/ViewModels/SchoolsListViewModel.swift`
- If other references remain (e.g. `familyUnitId`), leave the `familyManager` property and its init param as-is.
- If ZERO references remain, remove the `private let familyManager: FamilyManager` property and its init parameter — then update construction sites (grep `SchoolsListViewModel(`) and their tests accordingly.

Record which branch applied.

- [ ] **Step 4: Run Schools list tests**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SchoolsListViewModelTests`
Expected: PASS. If a test asserted the old FamilyUnit-first behavior, update it to assert preferences-only (distance sort/filter still works when preferences supply coords).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/SchoolsListViewModel.swift
git commit -m "refactor: Schools list reads home coord from preferences only

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

### Task 6: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Clean build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED, no new warnings/errors.

- [ ] **Step 2: Full unit suite**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
Expected: all pass (baseline ~3726 + new tests). Trust xcodebuild's exit code + passed/failed counts, not a grep for "TEST SUCCEEDED". If the run stalls on the known `RBSRequestErrorDomain` simulator flake, run `xcrun simctl shutdown all && killall -9 CoreSimulatorService` and retry.

- [ ] **Step 3: Manual smoke (simulator)**

Verify on a school with looked-up coords:
- Home set in Settings → "Distance from Home: N miles" shows, N matches web for the same pair.
- Home unset → CTA "Set your home location to see distance"; tapping opens the Home Location sheet; after saving + dismiss, distance appears without leaving the screen.
- School without coords → existing "Location data not available / Use Lookup College Data" empty state (unchanged).

- [ ] **Step 4: Final commit (if any test fixups were needed)**

```bash
git add -A
git commit -m "test: fixups for distance-from-home parity

Claude-Session: https://claude.ai/code/session_01UWGqxwV7d72BAphiujLGV8"
```

---

## Self-Review

**Spec coverage:**
- Data wiring (detail reads user_preferences) → Task 2 + Task 4. ✓
- Distance formula/format parity → Task 1, consumed in Task 3. ✓
- Guidance states (distance / CTA / no-school-coords) → Task 3 + Task 4. ✓
- CTA presents HomeLocationView sheet + reload on dismiss → Task 4. ✓
- Schools list dead-store cleanup → Task 5. ✓
- Dead FamilyUnit columns left in model (documented) → not removed (spec non-goal). ✓
- Tests: DistanceCalculator, SchoolDetailViewModel.loadHomeLocation, SchoolMapView states, list regression → Tasks 1,2,3,5. ✓

**Placeholder scan:** No TBD/TODO; all code blocks concrete. ✓

**Type consistency:** `homeCoordinate` (Task 2) consumed as `viewModel.homeCoordinate` (Task 4). `mapState`/`MapState`/`onSetHomeLocation` (Task 3) consumed in Task 4. `milesRounded`/`formatMiles` (Task 1) consumed in Task 3. `loadHomeLocation()` (Task 2) called in Task 4. Consistent. ✓

**Open risk:** `formatMiles` thousands-separator test depends on US locale; noted in Task 1 Step 4.
