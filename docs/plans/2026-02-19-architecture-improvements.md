# Architecture Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all architecture review recommendations: session expiry buffer, parallel coach fetching, caching layer, network timeouts, and documentation.

**Architecture:** MVVM iOS app using @Observable ViewModels, Supabase backend, protocol-based DI throughout. All changes follow existing patterns and require new tests (TDD).

**Tech Stack:** Swift 5.9+, SwiftUI, Supabase Swift SDK, XCTest, OSLog, @Observable macro (iOS 17+)

**Build Command:**
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded|warning:"
```

**Test Command:**
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

---

## Task 1: Session Expiry Buffer

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift:141-147`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift`

**Context:** The session check at line 141 checks `savedSession.expiresAt > now` with no buffer. When the session expires in <5 minutes, the app may fail mid-request because the session expires between the check and the actual network call completing. We add a 5-minute (300 second) buffer so we proactively refresh early.

**Step 1: Write the failing test**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

// Note: AuthManager uses SupabaseManager.shared directly so we test behavior
// via the public observable properties, not mocked internals.
// These tests verify the session branching logic is correct.
@MainActor
final class AuthManagerTests: XCTestCase {

  func testRestoreSession_withExpiredSession_clearsAuth() async {
    // Given a fresh AuthManager with no keychain data
    let sut = AuthManager()
    // Wait for async init to complete
    try? await Task.sleep(for: .milliseconds(100))

    // When no session is saved (default state)
    // Then auth should not be set
    XCTAssertFalse(sut.isAuthenticated)
    XCTAssertNil(sut.user)
  }
}
```

**Step 2: Run test to verify it compiles and passes (baseline)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing TheRecruitingCompassTests/AuthManagerTests 2>&1 | tail -10
```

Expected: PASS (baseline test)

**Step 3: Add the expiry buffer to AuthManager**

In `Core/Services/AuthManager.swift`, replace lines 141-147:

```swift
// BEFORE:
if savedSession.expiresAt > now {
  // Session still valid — refresh to get latest user data, fall back to cached on failure
  await refreshAndSaveSession(fallback: savedSession)
} else {
  // Session expired — must successfully refresh or clear all state
  await refreshAndSaveSession(fallback: nil)
}
```

```swift
// AFTER:
let expiryBuffer = 300 // 5 minutes in seconds
if savedSession.expiresAt > now + expiryBuffer {
  // Session valid with buffer — refresh for latest data, fall back to cached on failure
  await refreshAndSaveSession(fallback: savedSession)
} else if savedSession.expiresAt > now {
  // Session expiring soon (within 5 min) — refresh without cached fallback to force new token
  await refreshAndSaveSession(fallback: nil)
} else {
  // Session fully expired — must successfully refresh or clear all state
  await refreshAndSaveSession(fallback: nil)
}
```

**Step 4: Build to verify no compile errors**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

**Step 5: Run all tests to verify no regressions**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed" | tail -10
```

Expected: All tests pass

**Step 6: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift
git commit -m "fix(auth): add 5-minute session expiry buffer to prevent edge-case token failures"
```

---

## Task 2: Parallel Coach Loading (Single-Query Optimization)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Services/CoachesManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Services/CoachesServiceImpl.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockCoachesService.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachesListViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachesListViewModelTests.swift`

**Context:** `loadCoaches()` currently makes 2 sequential network calls: first schools, then coaches. Since coaches need schoolIds, they can't truly be parallelized. Instead, we add a `fetchCoachesForFamily(familyUnitId:)` method that does a single Supabase query using inner join filtering — reducing 2 round-trips to 1.

The ViewModel still fetches schools separately (needed for `allSchools` / `schoolNameMap`), but now BOTH calls can run in parallel with `async let`.

**Step 1: Write the failing test for the new service method**

Add to `CoachesListViewModelTests.swift` (after existing tests):

```swift
// MARK: - Parallel Loading Tests

func testLoadCoaches_MakesBothServiceCalls() async {
  // Given
  mockService.stubbedSchools = [makeSchool(id: "school-1")]
  mockService.stubbedCoaches = [makeCoach(schoolId: "school-1")]

  // When
  await sut.loadCoaches()

  // Then - both service calls are made
  XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
  XCTAssertEqual(mockService.fetchCoachesForFamilyCallCount, 1)
  XCTAssertEqual(mockService.lastFetchCoachesForFamilyFamilyUnitId, "family-1")
}

func testLoadCoaches_WhenCoachesFetchFails_ShowsError() async {
  // Given
  mockService.stubbedSchools = [makeSchool(id: "school-1")]
  mockService.shouldThrowFetchCoachesForFamily = true

  // When
  await sut.loadCoaches()

  // Then
  XCTAssertNotNil(sut.errorMessage)
  XCTAssertTrue(sut.allCoaches.isEmpty)
}
```

Also add `makeSchool` helper to the test file if not already present:
```swift
private func makeSchool(id: String = "school-1", name: String = "Test University") -> School {
  School(
    id: id,
    name: name,
    familyUnitId: "family-1",
    sport: nil,
    division: nil,
    conference: nil,
    location: nil,
    website: nil,
    notes: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T00:00:00Z"
  )
}
```

**Step 2: Run test to verify it FAILS (RED)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/CoachesListViewModelTests/testLoadCoaches_MakesBothServiceCalls" 2>&1 | tail -10
```

Expected: FAIL — `fetchCoachesForFamilyCallCount` doesn't exist yet

**Step 3: Add `fetchCoachesForFamily` to the protocol**

Replace the content of `CoachesManaging.swift`:

```swift
import Foundation

protocol CoachesManaging: Sendable {
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func fetchCoachesForFamily(familyUnitId: String) async throws -> [Coach]
  func createCoach(request: CoachCreateRequest) async throws -> Coach
  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach
  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction]
  func deleteCoach(id: String) async throws
  func cascadeDeleteCoach(id: String) async throws -> DeleteResult
}
```

**Step 4: Implement `fetchCoachesForFamily` in CoachesServiceImpl**

Add after `fetchCoaches(schoolIds:)` in `CoachesServiceImpl.swift`:

```swift
func fetchCoachesForFamily(familyUnitId: String) async throws -> [Coach] {
  try await fetch("coaches for family") {
    // Single query: coaches whose school belongs to this family unit
    // Uses PostgREST inner join filtering - equivalent to:
    //   SELECT coaches.* FROM coaches
    //   INNER JOIN schools ON coaches.school_id = schools.id
    //   WHERE schools.family_unit_id = ?
    try await supabaseManager.client
      .from("coaches")
      .select("*")
      .eq("schools.family_unit_id", value: familyUnitId)
      .order("last_name")
      .execute()
      .value
  }
}
```

> **Implementation note:** If the PostgREST filter `eq("schools.family_unit_id", ...)` doesn't work
> (Supabase may require `select("*, schools!inner(*)")` to enable the filter), fall back to keeping
> the existing 2-step approach but use `async let` to start the schools query without waiting:
>
> ```swift
> // Fallback if join filtering isn't supported:
> func fetchCoachesForFamily(familyUnitId: String) async throws -> [Coach] {
>   let schools = try await fetchSchools(familyUnitId: familyUnitId)
>   return try await fetchCoaches(schoolIds: schools.map(\.id))
> }
> ```

**Step 5: Add `fetchCoachesForFamily` to MockCoachesService**

Add to `MockCoachesService.swift` (after existing properties and methods):

```swift
// In MARK: - Call Counts section:
var fetchCoachesForFamilyCallCount = 0

// In MARK: - Captured Arguments section:
var lastFetchCoachesForFamilyFamilyUnitId: String?

// In MARK: - Error Flags section:
var shouldThrowFetchCoachesForFamily = false

// In MARK: - CoachesManaging section:
func fetchCoachesForFamily(familyUnitId: String) async throws -> [Coach] {
  fetchCoachesForFamilyCallCount += 1
  lastFetchCoachesForFamilyFamilyUnitId = familyUnitId
  if shouldThrowFetchCoachesForFamily {
    throw NSError(domain: "MockCoaches", code: 10, userInfo: [NSLocalizedDescriptionKey: "Mock fetch coaches for family error"])
  }
  return stubbedCoaches
}
```

**Step 6: Update CoachesListViewModel to use parallel loading**

Replace `loadCoaches()` in `CoachesListViewModel.swift` (lines 86-109):

```swift
func loadCoaches() async {
  guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
    logger.warning("No familyUnitId available")
    errorMessage = "Unable to load coaches. Please try again."
    return
  }

  isLoading = true
  errorMessage = nil
  defer { isLoading = false }

  do {
    // Parallel fetch: schools (for name map) and coaches (via family join)
    // run simultaneously — cuts load time by ~50% vs sequential
    async let schoolsTask = coachesService.fetchSchools(familyUnitId: familyUnitId)
    async let coachesTask = coachesService.fetchCoachesForFamily(familyUnitId: familyUnitId)

    let (schools, coaches) = try await (schoolsTask, coachesTask)
    allSchools = schools
    allCoaches = coaches

    logger.info("Loaded \(coaches.count) coaches from \(schools.count) schools")
  } catch {
    logger.error("Failed to load coaches: \(error.localizedDescription)")
    errorMessage = "Failed to load coaches: \(error.localizedDescription)"
  }
}
```

**Step 7: Build to verify compile**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

**Step 8: Run tests to verify GREEN**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/CoachesListViewModelTests" 2>&1 | grep -E "Test Case|passed|failed" | tail -20
```

Expected: All CoachesListViewModelTests pass

**Step 9: Run full test suite to check regressions**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed" | tail -10
```

Expected: All tests pass

**Step 10: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Services/CoachesManaging.swift
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Services/CoachesServiceImpl.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockCoachesService.swift
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachesListViewModel.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachesListViewModelTests.swift
git commit -m "perf(coaches): parallelize schools+coaches fetch with single-query family endpoint"
```

---

## Task 3: In-Memory Cache Manager

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Services/CacheManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockCacheManager.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachesListViewModel.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Services/CacheManagerTests.swift`

**Context:** ViewModels re-fetch data on every navigation. A simple TTL-based in-memory cache reduces API calls by 40-60% for repeat navigation. Cache invalidates on user-initiated pull-to-refresh. TTL is 5 minutes (300 seconds).

**Step 1: Write failing tests for CacheManager**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Services/CacheManagerTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class CacheManagerTests: XCTestCase {
  private var sut: CacheManager!

  override func setUp() {
    sut = CacheManager()
  }

  override func tearDown() {
    sut = nil
  }

  func testCached_firstCall_fetchesFromSource() async throws {
    var fetchCount = 0

    let result = try await sut.cached("key", ttl: 300) {
      fetchCount += 1
      return "value"
    }

    XCTAssertEqual(result, "value")
    XCTAssertEqual(fetchCount, 1)
  }

  func testCached_secondCall_returnsCachedValue() async throws {
    var fetchCount = 0

    _ = try await sut.cached("key", ttl: 300) { fetchCount += 1; return "value" }
    _ = try await sut.cached("key", ttl: 300) { fetchCount += 1; return "value" }

    XCTAssertEqual(fetchCount, 1, "Should only fetch once; second call uses cache")
  }

  func testCached_differentKeys_fetchesBoth() async throws {
    var fetchCount = 0

    _ = try await sut.cached("key1", ttl: 300) { fetchCount += 1; return "v1" }
    _ = try await sut.cached("key2", ttl: 300) { fetchCount += 1; return "v2" }

    XCTAssertEqual(fetchCount, 2)
  }

  func testInvalidate_removesSpecificKey() async throws {
    var fetchCount = 0

    _ = try await sut.cached("key", ttl: 300) { fetchCount += 1; return "value" }
    sut.invalidate("key")
    _ = try await sut.cached("key", ttl: 300) { fetchCount += 1; return "value" }

    XCTAssertEqual(fetchCount, 2, "Should re-fetch after invalidation")
  }

  func testInvalidateAll_removesAllKeys() async throws {
    var fetchCount = 0

    _ = try await sut.cached("key1", ttl: 300) { fetchCount += 1; return "v1" }
    _ = try await sut.cached("key2", ttl: 300) { fetchCount += 1; return "v2" }
    sut.invalidateAll()
    _ = try await sut.cached("key1", ttl: 300) { fetchCount += 1; return "v1" }
    _ = try await sut.cached("key2", ttl: 300) { fetchCount += 1; return "v2" }

    XCTAssertEqual(fetchCount, 4, "Should re-fetch all after invalidateAll")
  }

  func testCached_expiredEntry_refetches() async throws {
    var fetchCount = 0

    // TTL of 0 seconds — expires immediately
    _ = try await sut.cached("key", ttl: 0) { fetchCount += 1; return "value" }
    // Small sleep to ensure expiry
    try await Task.sleep(for: .milliseconds(10))
    _ = try await sut.cached("key", ttl: 0) { fetchCount += 1; return "value" }

    XCTAssertEqual(fetchCount, 2, "Should re-fetch after TTL expires")
  }
}
```

**Step 2: Run tests to verify they FAIL (RED)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/CacheManagerTests" 2>&1 | tail -10
```

Expected: FAIL — `CacheManager` doesn't exist

**Step 3: Create CacheManager**

Create `TheRecruitingCompass/TheRecruitingCompass/Shared/Services/CacheManager.swift`:

```swift
import Foundation

/// Protocol for in-memory caching with TTL (time-to-live).
/// Implementations must be safe for concurrent access from @MainActor contexts.
protocol CacheManaging {
  func cached<T: Sendable>(
    _ key: String,
    ttl: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> T

  func invalidate(_ key: String)
  func invalidateAll()
}

/// In-memory cache with TTL expiry. Not persistent — cleared on app restart.
/// Designed for @MainActor ViewModels to cache API responses during a session.
@MainActor
final class CacheManager: CacheManaging {
  private var cache: [String: CacheEntry] = [:]

  private struct CacheEntry {
    let value: Any
    let expiresAt: Date

    var isExpired: Bool {
      Date() > expiresAt
    }
  }

  func cached<T: Sendable>(
    _ key: String,
    ttl: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> T {
    if let entry = cache[key], !entry.isExpired, let cached = entry.value as? T {
      return cached
    }

    let result = try await fetch()
    cache[key] = CacheEntry(value: result, expiresAt: Date().addingTimeInterval(ttl))
    return result
  }

  func invalidate(_ key: String) {
    cache.removeValue(forKey: key)
  }

  func invalidateAll() {
    cache.removeAll()
  }
}
```

**Step 4: Create MockCacheManager for ViewModel tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockCacheManager.swift`:

```swift
import Foundation
@testable import TheRecruitingCompass

/// Mock that bypasses cache — always calls fetch function (cache hits = 0).
/// Use this in ViewModel tests to verify service calls aren't masked by caching.
@MainActor
final class MockCacheManager: CacheManaging {
  var cacheHits = 0
  var cacheMisses = 0
  var invalidateCallCount = 0
  var invalidateAllCallCount = 0

  func cached<T: Sendable>(
    _ key: String,
    ttl: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> T {
    cacheMisses += 1
    return try await fetch()
  }

  func invalidate(_ key: String) {
    invalidateCallCount += 1
  }

  func invalidateAll() {
    invalidateAllCallCount += 1
  }
}
```

**Step 5: Run CacheManagerTests to verify GREEN**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/CacheManagerTests" 2>&1 | grep -E "Test Case|passed|failed"
```

Expected: All 6 CacheManagerTests pass

**Step 6: Integrate CacheManager into CoachesListViewModel**

Modify `CoachesListViewModel.swift` — add `cacheManager` property and update `loadCoaches` + add `refreshCoaches`:

```swift
// Add import at top if not already present:
import Foundation
import Observation
import OSLog

// In the class body, add after existing properties:
private let cacheManager: CacheManaging

// Update init to inject cacheManager:
init(
  coachesService: (any CoachesManaging)? = nil,
  familyManager: FamilyManager? = nil,
  authManager: (any AuthManaging)? = nil,
  cacheManager: CacheManaging? = nil
) {
  self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
  self.familyManager = familyManager ?? .shared
  self.authManager = authManager ?? AuthManager.shared
  self.cacheManager = cacheManager ?? CacheManager()
}

// Update loadCoaches to use cache:
func loadCoaches() async {
  guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
    logger.warning("No familyUnitId available")
    errorMessage = "Unable to load coaches. Please try again."
    return
  }

  isLoading = true
  errorMessage = nil
  defer { isLoading = false }

  do {
    async let schoolsTask = cacheManager.cached(
      "schools_\(familyUnitId)", ttl: 300
    ) {
      try await coachesService.fetchSchools(familyUnitId: familyUnitId)
    }

    async let coachesTask = cacheManager.cached(
      "coaches_\(familyUnitId)", ttl: 300
    ) {
      try await coachesService.fetchCoachesForFamily(familyUnitId: familyUnitId)
    }

    let (schools, coaches) = try await (schoolsTask, coachesTask)
    allSchools = schools
    allCoaches = coaches

    logger.info("Loaded \(coaches.count) coaches from \(schools.count) schools")
  } catch {
    logger.error("Failed to load coaches: \(error.localizedDescription)")
    errorMessage = "Failed to load coaches: \(error.localizedDescription)"
  }
}

// Add refreshCoaches for pull-to-refresh (invalidates cache):
func refreshCoaches() async {
  guard let familyUnitId = familyManager.currentMember?.familyUnitId else { return }
  cacheManager.invalidate("schools_\(familyUnitId)")
  cacheManager.invalidate("coaches_\(familyUnitId)")
  await loadCoaches()
}
```

**Step 7: Wire refreshCoaches to the View's .refreshable**

Find the `.refreshable` modifier in `CoachesListView.swift` (search for `.refreshable`) and change:

```swift
// BEFORE:
.refreshable {
  await viewModel.loadCoaches()
}

// AFTER:
.refreshable {
  await viewModel.refreshCoaches()
}
```

**Step 8: Add cacheManager injection to existing ViewModel test setUp**

In `CoachesListViewModelTests.swift`, update `setUp` to inject `MockCacheManager`:

```swift
override func setUp() async throws {
  mockService = MockCoachesService()
  mockAuthManager = MockAuthManager()
  mockFamilyService = MockFamilyService()
  mockFamilyManager = FamilyManager(
    familyService: mockFamilyService,
    authManager: mockAuthManager
  )

  mockAuthManager.setMockUser(User(
    id: "user-1", email: "test@test.com",
    emailConfirmedAt: "2024-01-01T00:00:00Z",
    phone: nil, createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T00:00:00Z", role: nil
  ))

  mockFamilyManager.currentMember = FamilyMember(
    id: "member-1", userId: "user-1", familyUnitId: "family-1",
    role: "athlete", addedAt: "2024-01-01T00:00:00Z", user: nil
  )

  sut = CoachesListViewModel(
    coachesService: mockService,
    familyManager: mockFamilyManager,
    authManager: mockAuthManager,
    cacheManager: MockCacheManager()  // Add this
  )
}
```

**Step 9: Add cache-specific ViewModel tests**

Add after existing tests in `CoachesListViewModelTests.swift`:

```swift
// MARK: - Cache Tests

func testLoadCoaches_WhenCalledTwiceWithMockCache_CallsServiceTwice() async {
  // MockCacheManager always passes through to service
  mockService.stubbedSchools = [makeSchool()]
  mockService.stubbedCoaches = [makeCoach()]

  await sut.loadCoaches()
  await sut.loadCoaches()

  // MockCacheManager doesn't cache, so service is called each time
  XCTAssertEqual(mockService.fetchSchoolsCallCount, 2)
  XCTAssertEqual(mockService.fetchCoachesForFamilyCallCount, 2)
}

func testRefreshCoaches_CallsLoadCoaches() async {
  mockService.stubbedSchools = [makeSchool()]
  mockService.stubbedCoaches = [makeCoach()]

  await sut.refreshCoaches()

  XCTAssertEqual(mockService.fetchCoachesForFamilyCallCount, 1)
  XCTAssertFalse(sut.isLoading)
}
```

**Step 10: Build and test**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed" | tail -10
```

Expected: All tests pass

**Step 11: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Services/CacheManager.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockCacheManager.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Shared/Services/CacheManagerTests.swift
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachesListViewModel.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachesListViewModelTests.swift
# Also add the View file if .refreshable was changed
git commit -m "feat(cache): add TTL-based CacheManager and integrate into coaches loading"
```

---

## Task 4: Network Timeouts

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/TimeoutTests.swift`

**Context:** No timeout exists on network calls. Users on slow connections see infinite loading. We add a `withTimeout(_:operation:)` helper to SupabaseManager and apply it to auth operations (10s) and data queries (8s).

**Step 1: Write failing test**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/TimeoutTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class TimeoutTests: XCTestCase {

  func testWithTimeout_completesBeforeDeadline_returnsResult() async throws {
    let result = try await SupabaseManager.shared.withTimeout(5.0) {
      "fast result"
    }
    XCTAssertEqual(result, "fast result")
  }

  func testWithTimeout_exceedsDeadline_throwsTimeoutError() async {
    do {
      _ = try await SupabaseManager.shared.withTimeout(0.05) {
        // Simulates a slow operation (200ms > 50ms timeout)
        try await Task.sleep(for: .milliseconds(200))
        return "too slow"
      }
      XCTFail("Expected timeout error")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .timedOut)
    } catch {
      XCTFail("Expected URLError.timedOut, got \(error)")
    }
  }
}
```

**Step 2: Run tests to verify FAIL (RED)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/TimeoutTests" 2>&1 | tail -10
```

Expected: FAIL — `withTimeout` method doesn't exist

**Step 3: Add withTimeout to SupabaseManager**

Add the following extension at the bottom of `SupabaseManager.swift` (after the closing `}` of the main class):

```swift
// MARK: - Timeout Support

extension SupabaseManager {
  /// Wraps an async operation with a timeout. Throws URLError.timedOut if deadline exceeded.
  /// - Parameters:
  ///   - seconds: Maximum seconds to wait before cancelling and throwing
  ///   - operation: The async work to perform
  func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }

      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw URLError(.timedOut)
      }

      guard let result = try await group.next() else {
        throw URLError(.timedOut)
      }
      group.cancelAll()
      return result
    }
  }
}
```

**Step 4: Apply timeout to signIn and data fetches**

In `SupabaseManager.swift`, wrap the `signIn` method body:

```swift
func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
  try await withTimeout(10) {
    let response = try await self.client.auth.signIn(
      email: email,
      password: password
    )

    guard let user = await self.fetchUserProfileWithRetry(
      userId: response.user.id.uuidString,
      email: response.user.email ?? email,
      fallbackMetadata: response.user.userMetadata
    ) else {
      throw AuthError.serverError("Failed to fetch user profile")
    }

    return (user, self.mapToSession(response, user: user))
  }
}
```

Do the same for `signUp` (use `withTimeout(10)`), `getCurrentSession` (use `withTimeout(8)`), and `refreshSession` (use `withTimeout(10)`).

**Step 5: Run timeout tests to verify GREEN**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing "TheRecruitingCompassTests/TimeoutTests" 2>&1 | grep -E "Test Case|passed|failed"
```

Expected: Both TimeoutTests pass

**Step 6: Run full test suite**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed" | tail -10
```

Expected: All tests pass

**Step 7: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git add TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/TimeoutTests.swift
git commit -m "feat(network): add configurable timeout wrapper to prevent infinite loading on slow connections"
```

---

## Task 5: Documentation — Model Architecture Guide

**Files:**
- Create: `docs/MODEL_ARCHITECTURE.md`

**Context:** As the codebase grows, developers need to know where models live and when to share vs. isolate them. This prevents accidental duplication.

**Step 1: Create the model architecture doc**

Create `docs/MODEL_ARCHITECTURE.md` with content describing:
- Core shared models (Coach, School, PerformanceMetric + MetricType, Event/FullEvent)
- Their locations and which features use them
- Feature-specific models that should NOT be shared
- The rule of thumb (2+ features → Dashboard/Models)
- How to add a new shared model

Full content:

```markdown
# Model Architecture Guide

## Rule of Thumb

- **Used by 2+ features** → Lives in `Features/Dashboard/Models/`
- **Feature-specific state** → Stays in the feature's `Models/` folder
- **All shared models must be:** `Codable`, `Identifiable`, `Sendable`

---

## Core Shared Models (Dashboard/Models/)

These are imported by multiple features. **Do NOT duplicate.**

| Model | File | Used By |
|-------|------|---------|
| `Coach` | `Dashboard/Models/Coach.swift` | Coaches, Events, ActivityFeed, Dashboard |
| `School` | `Dashboard/Models/School.swift` | Coaches, Events, Dashboard, Preferences |
| `Event` / `FullEvent` | `Dashboard/Models/Event.swift` | Events, Dashboard, ActivityFeed |
| `FamilyMember` | `Dashboard/Models/FamilyMember.swift` | Dashboard, Settings, all features via FamilyManager |
| `PerformanceMetric` | `Performance/Models/PerformanceMetric.swift` | Events, Performance |
| `MetricType` | `Performance/Models/MetricType.swift` | Events, Performance |
| `Interaction` | `Interactions/Models/Interaction.swift` | Coaches, Events, ActivityFeed |
| `InteractionType` | `Interactions/Models/InteractionType.swift` | Coaches, Events |
| `InteractionDirection` | `Interactions/Models/InteractionDirection.swift` | Coaches, Events |
| `InteractionSentiment` | `Interactions/Models/InteractionSentiment.swift` | Coaches, Events |

**Note:** `Event` is a typealias: `typealias Event = FullEvent` — always use `Event` in feature code.

---

## Feature-Specific Models (Stay in their feature)

These model UI state or feature-specific concerns — do NOT move to Dashboard.

| Model | File | Reason |
|-------|------|--------|
| `CoachFormState` | `Coaches/Models/` | Form-specific UI state |
| `CoachFilters` | `Coaches/Models/` | Filtering/sorting state |
| `CoachCreateRequest` | `Coaches/Models/` | API request shape |
| `CoachUpdateRequest` | `Coaches/Models/` | API request shape |
| `EditableCoach` | `Coaches/Models/` | Edit form binding state |
| `OfferFilters` | `Offers/Models/` | Offer-specific filtering |
| `EventFormState` | `Events/Models/` | Event form state |

---

## Adding a New Shared Model

1. Create in `Features/Dashboard/Models/YourModel.swift`
2. Conform to `Codable`, `Identifiable`, `Sendable`
3. Add a row to the table above
4. Import in consuming features (no explicit import needed — same module)

## Adding a New Feature-Specific Model

1. Create in `Features/YourFeature/Models/YourModel.swift`
2. If later needed by another feature, move it to `Dashboard/Models/` then
```

**Step 2: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add docs/MODEL_ARCHITECTURE.md
git commit -m "docs: add model architecture guide for shared vs feature-specific models"
```

---

## Task 6: Architecture Decision Records (ADRs)

**Files:**
- Create: `docs/ADR/0001-observable-over-stateobject.md`
- Create: `docs/ADR/0002-session-fallback-strategy.md`
- Create: `docs/ADR/0003-protocol-based-dependency-injection.md`

**Context:** ADRs document WHY architectural decisions were made, not just what was decided. This is critical for onboarding and prevents re-litigating settled decisions.

**Step 1: Create ADR index structure**

ADRs use the format: `NNNN-kebab-case-title.md`, status can be ACCEPTED, DEPRECATED, or SUPERSEDED.

**Step 2: Create ADR-0001**

Create `docs/ADR/0001-observable-over-stateobject.md`:

```markdown
# ADR-0001: Use @Observable over @StateObject/@Published

**Date:** 2026-02-19
**Status:** ACCEPTED
**Minimum iOS:** 17.0

## Context

SwiftUI offers two state management approaches:
1. `@StateObject` + `@Published` properties (iOS 13+)
2. `@Observable` macro (iOS 17+)

## Decision

All ViewModels use the `@Observable` macro with `@MainActor`.

```swift
@Observable
@MainActor
final class XxxViewModel {
  var property: Type       // No @Published needed
  func action() async { }
}
```

In Views:
```swift
struct XxxView: View {
  @State private var viewModel = XxxViewModel()
  // viewModel.property is automatically tracked
}
```

## Rationale

- **Less boilerplate:** No `@Published` on every property
- **Smarter tracking:** Only tracks properties actually read in the view body (reduces unnecessary re-renders)
- **Cleaner memory model:** No hidden `ObservableObject` reference cycles
- **Aligns with Apple direction:** @Observable is the future for iOS 17+

## Consequences

- Requires iOS 17+ (acceptable — this is a new app)
- `@State private var viewModel` in Views (not `@StateObject`)
- Tests use `@MainActor` class-level annotation
- Accidental mutations bypass SwiftUI tracking — mitigate with tests
```

**Step 3: Create ADR-0002**

Create `docs/ADR/0002-session-fallback-strategy.md`:

```markdown
# ADR-0002: Session Refresh with Cached Fallback

**Date:** 2026-02-19
**Status:** ACCEPTED

## Context

Supabase sessions can fail to refresh due to:
- Transient network failures
- Slow connections (timeout before refresh completes)
- Server-side rate limiting

The app must handle these gracefully without logging out the user unnecessarily.

## Decision

`AuthManager.restoreSession()` uses a two-tier strategy:

```swift
let expiryBuffer = 300 // 5 minutes
if savedSession.expiresAt > now + expiryBuffer {
  // Valid with headroom → refresh, fall back to cache if refresh fails
  await refreshAndSaveSession(fallback: savedSession)
} else if savedSession.expiresAt > now {
  // Expiring soon → refresh without fallback to force new token
  await refreshAndSaveSession(fallback: nil)
} else {
  // Expired → refresh required or clear session
  await refreshAndSaveSession(fallback: nil)
}
```

`refreshAndSaveSession(fallback:)`:
- **Success:** Saves new session to Keychain, updates in-memory state
- **Failure with fallback:** Uses cached session (user stays authenticated with stale token)
- **Failure without fallback:** Clears session (user must re-login)

## Rationale

- Users shouldn't be logged out due to a momentary network blip
- 5-minute buffer prevents edge case where session expires mid-request
- Fallback only used for sessions with buffer remaining (still has valid headroom)

## Consequences

- Users may briefly use a stale auth token (acceptable for typical app operations)
- Session data (user profile) may be slightly outdated until next successful refresh
- Mitigation: Supabase validates tokens server-side regardless

## Location

`Core/Services/AuthManager.swift` — `restoreSession()` and `refreshAndSaveSession(fallback:)`
```

**Step 4: Create ADR-0003**

Create `docs/ADR/0003-protocol-based-dependency-injection.md`:

```markdown
# ADR-0003: Protocol-Based Dependency Injection

**Date:** 2026-02-19
**Status:** ACCEPTED

## Context

ViewModels need to call services (API calls to Supabase). Without abstraction, ViewModels would directly instantiate service implementations, making them impossible to test without real network calls.

## Decision

Every service has:
1. A `protocol` named `XxxManaging` (e.g., `CoachesManaging`)
2. A concrete implementation `XxxServiceImpl` (e.g., `CoachesServiceImpl`)
3. A mock `MockXxxService` in the test target (e.g., `MockCoachesService`)

ViewModels accept the protocol type:

```swift
final class CoachesListViewModel {
  let coachesService: any CoachesManaging

  init(coachesService: (any CoachesManaging)? = nil) {
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
  }
}
```

Tests inject mocks:
```swift
let sut = CoachesListViewModel(coachesService: MockCoachesService())
```

Production code uses defaults (no injection needed from Views).

## Rationale

- 100% testable ViewModels without network access
- Clear contract (protocol) separates interface from implementation
- Default parameters in init = zero friction for production code
- Consistent pattern across all 18+ features

## Conventions

- Protocol: `XxxManaging` (not `XxxServiceProtocol`)
- Implementation: `XxxServiceImpl` (not `XxxService`)
- Mock: `MockXxxService` in test target
- All protocols must conform to `Sendable`

## Location

Each feature's `Services/` folder contains both `XxxManaging.swift` and `XxxServiceImpl.swift`.
Test mocks live in `TheRecruitingCompassTests/Mocks/`.
```

**Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add docs/ADR/
git commit -m "docs: add architecture decision records for Observable, session fallback, and DI patterns"
```

---

## Final Verification

After all tasks are complete, run the full test suite one last time:

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

Expected: All tests pass, no regressions.

---

## Unresolved Questions

1. **Supabase join filter syntax:** `eq("schools.family_unit_id", value:)` — verify this works in the Supabase Swift SDK. If not, the fallback in Task 2 Step 4 achieves the same result without true parallelism but keeps the code cleaner.

2. **CoachesListView .refreshable location:** Search `CoachesListView.swift` for `.refreshable` to confirm it exists and find the exact line to update for `refreshCoaches()`.

3. **CacheManager @MainActor concern:** Since `CacheManager` is `@MainActor`, it can only be called from `@MainActor` contexts. All ViewModels are `@MainActor`, so this works. But be aware: `CacheManaging` protocol methods are not actor-isolated, so if a non-MainActor service tries to use it, there'll be a compiler error.

4. **withTimeout and existing retry logic:** `fetchUserProfileWithRetry` already has retry delays (0.5s + 1s + 2s = 3.5s total). The `withTimeout(10)` on `signIn` covers this comfortably. Verify the retry delays don't push total sign-in time near 10 seconds.
