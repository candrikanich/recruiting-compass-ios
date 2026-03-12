# Parent Login UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three bugs that degrade the login experience for parent users: a biometric enrollment alert that flashes and disappears, parent onboarding re-triggering on every fresh install, and duplicate family memberships caused by repeated onboarding.

**Architecture:**
- Bug 1 (biometric flash): The `shouldShowBiometricOptIn` alert is shown by `LoginView`, which is torn down mid-navigation when `isAuthenticated` flips to true. Fix by moving the enrollment offer to `AuthManager` as `pendingBiometricEnrollmentOffer: Bool`, shown as an app-level alert in `TheRecruitingCompassApp` — same pattern as `showBiometricLock`.
- Bug 2 (parent re-onboarding): `OnboardingManager.loadStatus()` reads a device-local `UserDefaults` flag for parents. Fix by checking `FamilyManaging.getFamilyUnit(forUserId:)` in the DB; if a family already exists the parent has done onboarding. Cache the result in UserDefaults for future fast-path.
- Bug 3 (multiple families): Caused entirely by Bug 2. No additional iOS fix needed; preventing re-onboarding prevents duplicate `createFamily` calls.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, XCTest, `@MainActor` ViewModels, protocol-based DI.

---

## Files to Create or Modify

| Action | Path | Why |
|--------|------|-----|
| Modify | `Core/Protocols/AuthManaging.swift` | Add `pendingBiometricEnrollmentOffer: Bool { get set }` |
| Modify | `Core/Services/AuthManager.swift` | Add stored property `pendingBiometricEnrollmentOffer` |
| Modify | `Features/Auth/ViewModels/LoginViewModel.swift` | Replace local flag with `authManager.pendingBiometricEnrollmentOffer = true`; remove `shouldShowBiometricOptIn` |
| Modify | `Features/Auth/Views/LoginView.swift` | Remove biometric opt-in alert |
| Modify | `TheRecruitingCompassApp.swift` | Add app-level biometric enrollment alert overlay |
| Modify | `Features/Onboarding/Services/OnboardingManager.swift` | Inject `FamilyManaging`; replace UserDefaults-only check with DB check |
| Modify | `TheRecruitingCompassTests/Mocks/MockAuthManager.swift` | Add `pendingBiometricEnrollmentOffer: Bool = false` |
| Modify | `TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift` | Update biometric tests: check `mockAuthManager.pendingBiometricEnrollmentOffer` |
| Create | `TheRecruitingCompassTests/Mocks/MockOnboardingService.swift` | Testable mock for `OnboardingManaging` |
| Create | `TheRecruitingCompassTests/Features/Onboarding/OnboardingManagerTests.swift` | Full test coverage for `OnboardingManager.loadStatus()` |

All paths are relative to:
`TheRecruitingCompass/TheRecruitingCompass/` (source)
`TheRecruitingCompass/TheRecruitingCompassTests/` (tests)

---

## Chunk 1: Bug 1 — Biometric Enrollment Alert Race Fix

### Task 1: Add `pendingBiometricEnrollmentOffer` to `AuthManaging` protocol and `AuthManager`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`

- [ ] **Step 1: Add the property to the protocol**

In `AuthManaging.swift`, add one line after `var biometricEnabled: Bool { get }`:

```swift
var pendingBiometricEnrollmentOffer: Bool { get set }
```

The full protocol body should look like:

```swift
@MainActor
protocol AuthManaging: AnyObject {
  var isAuthenticated: Bool { get }
  var isCheckingSession: Bool { get }
  var user: User? { get }
  var session: Session? { get }
  var biometricEnabled: Bool { get }
  var pendingBiometricEnrollmentOffer: Bool { get set }

  func login(email: String, password: String) async throws
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?) async throws
  func logout() async throws
  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
  func resetPasswordForEmail(email: String) async throws
  func updatePassword(newPassword: String) async throws
  func updateUser(_ user: User)
  func enableBiometrics() throws
  func disableBiometrics()
  func authenticateWithBiometrics() async throws
}
```

- [ ] **Step 2: Add the stored property to `AuthManager`**

In `AuthManager.swift`, find the block of `var` observable properties (near `biometricEnabled`). Add:

```swift
var pendingBiometricEnrollmentOffer: Bool = false
```

- [ ] **Step 3: Build to verify no compiler errors**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` (MockAuthManager will show an error until next task; that's OK — fix it next).

---

### Task 2: Update `MockAuthManager` to satisfy the protocol

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAuthManager.swift`

- [ ] **Step 1: Add the property to `MockAuthManager`**

In the `// MARK: - Biometric Mock State` section, add:

```swift
var pendingBiometricEnrollmentOffer: Bool = false
```

Also add it to the `reset()` function body:

```swift
pendingBiometricEnrollmentOffer = false
```

- [ ] **Step 2: Build to verify clean**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

---

### Task 3: Update `LoginViewModel` — replace local flag with `authManager` flag

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift`

The `login()` method currently sets `shouldShowBiometricOptIn = true`. Replace it with `authManager.pendingBiometricEnrollmentOffer = true`. Then remove the `shouldShowBiometricOptIn` property and its helper methods (`enableBiometrics()`, `dismissBiometricOptIn()`), since those responsibilities move to the app level.

- [ ] **Step 1: Update `login()` method**

Find this block inside `login()`:
```swift
if !authManager.biometricEnabled && biometricService.canEvaluateBiometrics() {
    shouldShowBiometricOptIn = true
}
```

Replace with:
```swift
if !authManager.biometricEnabled && biometricService.canEvaluateBiometrics() {
    authManager.pendingBiometricEnrollmentOffer = true
}
```

- [ ] **Step 2: Remove `shouldShowBiometricOptIn` property and biometric helper methods**

Remove:
```swift
var shouldShowBiometricOptIn = false
```

Remove the entire `// MARK: - Biometric Opt-In` section:
```swift
// MARK: - Biometric Opt-In

func enableBiometrics() {
    try? authManager.enableBiometrics()
    shouldShowBiometricOptIn = false
}

func dismissBiometricOptIn() {
    shouldShowBiometricOptIn = false
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` (LoginView.swift will error until next task)

---

### Task 4: Update `LoginView` — remove biometric alert, update `TheRecruitingCompassApp` — add app-level alert

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`

- [ ] **Step 1: Remove biometric opt-in alert from `LoginView`**

In `LoginView.swift`, find and remove:
```swift
.alert("Enable Face ID?", isPresented: $viewModel.shouldShowBiometricOptIn) {
    Button("Enable") { viewModel.enableBiometrics() }
    Button("Not Now", role: .cancel) { viewModel.dismissBiometricOptIn() }
}
```

- [ ] **Step 2: Add biometric enrollment alert to `TheRecruitingCompassApp`**

In `TheRecruitingCompassApp.swift`, after the existing `.overlay { if showBiometricLock { ... } }` block, add a new `.alert` modifier:

```swift
.alert("Enable Face ID?", isPresented: Binding(
    get: { authManager.pendingBiometricEnrollmentOffer },
    set: { authManager.pendingBiometricEnrollmentOffer = $0 }
)) {
    Button("Enable") {
        try? authManager.enableBiometrics()
        authManager.pendingBiometricEnrollmentOffer = false
    }
    Button("Not Now", role: .cancel) {
        authManager.pendingBiometricEnrollmentOffer = false
    }
}
```

- [ ] **Step 3: Build to verify clean**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

---

### Task 5: Update `LoginViewModelTests` for the new biometric behavior

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift`

The existing tests check `sut.shouldShowBiometricOptIn`. Replace those checks with `mockAuthManager.pendingBiometricEnrollmentOffer`. The `testEnableBiometrics*` and `testDismissBiometricOptIn*` tests must also be updated since those methods no longer exist on the view model.

- [ ] **Step 1: Update biometric opt-in test assertions**

Find and replace each biometric test in the `// MARK: - Biometric Opt-In Tests` section.

Replace:
```swift
func testShouldShowBiometricOptInAfterSuccessfulLoginWhenCapable() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.biometricEnabled = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertTrue(sut.shouldShowBiometricOptIn)
}
```
With:
```swift
func testShouldShowBiometricOptInAfterSuccessfulLoginWhenCapable() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.biometricEnabled = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertTrue(mockAuthManager.pendingBiometricEnrollmentOffer)
}
```

Replace:
```swift
func testShouldNotShowBiometricOptInWhenDeviceNotCapable() async {
    mockBiometricService.canEvaluateResult = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(sut.shouldShowBiometricOptIn)
}
```
With:
```swift
func testShouldNotShowBiometricOptInWhenDeviceNotCapable() async {
    mockBiometricService.canEvaluateResult = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(mockAuthManager.pendingBiometricEnrollmentOffer)
}
```

Replace:
```swift
func testShouldNotShowBiometricOptInWhenAlreadyEnabled() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.biometricEnabled = true
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(sut.shouldShowBiometricOptIn)
}
```
With:
```swift
func testShouldNotShowBiometricOptInWhenAlreadyEnabled() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.biometricEnabled = true
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(mockAuthManager.pendingBiometricEnrollmentOffer)
}
```

Replace:
```swift
func testShouldNotShowBiometricOptInOnFailedLogin() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(sut.shouldShowBiometricOptIn)
}
```
With:
```swift
func testShouldNotShowBiometricOptInOnFailedLogin() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.shouldThrowLoginError = true
    mockAuthManager.mockErrorToThrow = .invalidCredentials
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(mockAuthManager.pendingBiometricEnrollmentOffer)
}
```

- [ ] **Step 2: Replace `testEnableBiometrics*` and `testDismissBiometric*` tests**

The old tests called `sut.enableBiometrics()` / `sut.dismissBiometricOptIn()` — methods that no longer exist.
Replace both tests with tests that verify the `authManager` flag is set correctly after login:

```swift
func testBiometricEnrollmentOfferSetOnAuthManagerAfterSuccessfulLogin() async {
    mockBiometricService.canEvaluateResult = true
    mockAuthManager.biometricEnabled = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertTrue(mockAuthManager.pendingBiometricEnrollmentOffer,
        "Login should set pendingBiometricEnrollmentOffer on authManager so the app-level alert can show it")
}

func testBiometricEnrollmentOfferNotSetWhenBiometricsUnavailable() async {
    mockBiometricService.canEvaluateResult = false
    mockAuthManager.biometricEnabled = false
    sut.email = "user@example.com"
    sut.password = "ValidPassword123"

    await sut.login()

    XCTAssertFalse(mockAuthManager.pendingBiometricEnrollmentOffer)
}
```

- [ ] **Step 3: Run the unit tests to verify the tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/LoginViewModelTests 2>&1 | grep -E "Test Case|error:|FAILED|passed"
```

Expected: All `LoginViewModelTests` pass.

- [ ] **Step 4: Commit Bug 1 fix**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add \
  TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift \
  TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift \
  TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAuthManager.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift
git commit -m "fix(auth): move biometric enrollment alert to app level to prevent navigation tear-down flash"
```

---

## Chunk 2: Bug 2 — Parent Onboarding DB Check

### Task 6: Create `MockOnboardingService`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockOnboardingService.swift`

We need a mock for the `OnboardingManaging` service protocol (used by `OnboardingManager`). No mock existed before.

- [ ] **Step 1: Write the failing test to confirm no mock exists yet**

```bash
grep -r "MockOnboardingService" \
  /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompassTests/
```

Expected: no output (it doesn't exist yet).

- [ ] **Step 2: Create `MockOnboardingService.swift`**

```swift
import Foundation
@testable import TheRecruitingCompass

final class MockOnboardingService: OnboardingManaging, @unchecked Sendable {
  var isOnboardingCompleteResult = false
  var shouldThrowError = false
  var mockError: Error = NSError(domain: "MockOnboarding", code: 0)

  var isOnboardingCompleteCallCount = 0
  var completeOnboardingCallCount = 0
  var lastUserIdChecked: String?

  func isOnboardingComplete(userId: String) async throws -> Bool {
    isOnboardingCompleteCallCount += 1
    lastUserIdChecked = userId
    if shouldThrowError { throw mockError }
    return isOnboardingCompleteResult
  }

  func completeOnboarding(
    userId: String,
    assessment: OnboardingAssessment,
    startingPhase: String
  ) async throws {
    completeOnboardingCallCount += 1
    if shouldThrowError { throw mockError }
  }
}
```

- [ ] **Step 3: Build to verify it compiles**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

---

### Task 7: Add `FamilyManaging` dependency to `OnboardingManager` and fix the parent check

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Services/OnboardingManager.swift`

The fix: for parent users, instead of only reading a UserDefaults boolean, we first call `familyService.getFamilyUnit(forUserId: userId)`. If a family exists in the DB, the parent has already done onboarding — mark it complete and write the UserDefaults cache. If no family exists, onboarding is needed.

The UserDefaults fast-path is preserved: if the key is already `true` (cached from a previous check on this device), skip the DB call entirely.

- [ ] **Step 1: Write the tests FIRST (TDD — they will fail until Task 8)**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Features/Onboarding/OnboardingManagerTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OnboardingManagerTests: XCTestCase {
  var sut: OnboardingManager!
  var mockOnboardingService: MockOnboardingService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!

  private static let parentKey = "parent_onboarding_complete_test-parent-id"

  override func setUp() {
    super.setUp()
    mockOnboardingService = MockOnboardingService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    sut = OnboardingManager(
      onboardingService: mockOnboardingService,
      authManager: mockAuthManager,
      familyService: mockFamilyService
    )
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
    sut = nil
    mockOnboardingService = nil
    mockAuthManager = nil
    mockFamilyService = nil
    super.tearDown()
  }

  // MARK: - Unauthenticated

  func testNoUserDefaultsToNotNeedingOnboarding() async {
    mockAuthManager.user = nil

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - Player Tests

  func testPlayerWithCompletedOnboardingSkipsDashboard() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerWithIncompleteOnboardingNeedsOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testPlayerWithDBErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus()

    // Fail-safe: don't block user if DB is unreachable
    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerChecksOnboardingServiceNotFamilyService() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(mockOnboardingService.isOnboardingCompleteCallCount, 1)
    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 0,
      "Players should not trigger a family DB lookup")
  }

  // MARK: - Parent Tests (DB check)

  func testParentWithExistingFamilyInDBSkipsOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testParentWithExistingFamilyInDBCachesUserDefaultsFlag() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()

    await sut.loadStatus()

    let cached = UserDefaults.standard.bool(forKey: Self.parentKey)
    XCTAssertTrue(cached, "Should cache the result so future launches skip the DB call")
  }

  func testParentWithNoFamilyInDBNeedsOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = nil

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testParentWithLocalCacheSkipsDBLookup() async {
    mockAuthManager.user = makeUser(role: .parent)
    // Pre-set the cache as if a previous check already wrote it
    UserDefaults.standard.set(true, forKey: Self.parentKey)

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 0,
      "Should use UserDefaults fast-path and skip DB call")
  }

  func testParentWithFamilyDBErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.shouldSucceed = false

    await sut.loadStatus()

    // Fail-safe: don't block parent if DB lookup fails
    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - markParentOnboardingComplete

  func testMarkParentOnboardingCompleteSetsFlagAndNeedsOnboardingFalse() {
    mockAuthManager.user = makeUser(role: .parent)

    sut.markParentOnboardingComplete()

    XCTAssertEqual(sut.needsOnboarding, false)
    let cached = UserDefaults.standard.bool(forKey: Self.parentKey)
    XCTAssertTrue(cached)
  }

  // MARK: - Helpers

  private func makeUser(role: UserRole) -> User {
    User(
      id: "test-parent-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      fullName: "Test Parent",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role,
      dateOfBirth: nil
    )
  }

  private func makeFamilyUnit() -> FamilyUnit {
    FamilyUnit(
      id: "family-unit-1",
      createdByUserId: "test-parent-id",
      familyCode: "FAM-ABC123",
      familyName: "Test Family",
      codeGeneratedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      pendingPlayerDetails: nil
    )
  }
}
```

- [ ] **Step 2: Run tests to confirm they FAIL (RED)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/OnboardingManagerTests 2>&1 | grep -E "error:|FAILED|passed|BUILD"
```

Expected: Build error because `OnboardingManager.init` does not yet accept `familyService:`.

---

### Task 8: Implement the fix in `OnboardingManager`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Services/OnboardingManager.swift`

- [ ] **Step 1: Add `FamilyManaging` dependency**

Update the class properties and `init`:

```swift
private let onboardingService: any OnboardingManaging
private let authManager: any AuthManaging
private let familyService: any FamilyManaging
```

Update `init` to accept the optional `familyService` parameter:

```swift
init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil
) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
}
```

- [ ] **Step 2: Replace the parent check in `loadStatus()`**

Replace the current parent block:
```swift
if user.role == .parent {
    let key = Self.parentOnboardingCompleteKeyPrefix + user.id
    let complete = UserDefaults.standard.bool(forKey: key)
    needsOnboarding = !complete
    logger.debug("Parent onboarding status: needsOnboarding=\(self.needsOnboarding ?? false)")
    return
}
```

With the new DB-backed check:
```swift
if user.role == .parent {
    let key = Self.parentOnboardingCompleteKeyPrefix + user.id

    // Fast-path: if already cached on this device, skip the DB call
    if UserDefaults.standard.bool(forKey: key) {
        needsOnboarding = false
        logger.debug("Parent onboarding: cached complete on device")
        return
    }

    // DB check: if the parent already has a family, they've done onboarding
    do {
        let existingFamily = try await familyService.getFamilyUnit(forUserId: user.id)
        if existingFamily != nil {
            // Write cache so future launches skip this DB call
            UserDefaults.standard.set(true, forKey: key)
            needsOnboarding = false
            logger.debug("Parent onboarding: family found in DB, marking complete")
        } else {
            needsOnboarding = true
            logger.debug("Parent onboarding: no family found, showing onboarding")
        }
    } catch {
        // Fail-safe: don't block parent if DB is unreachable
        logger.error("Parent onboarding DB check failed: \(error.localizedDescription)")
        needsOnboarding = false
    }
    return
}
```

- [ ] **Step 3: Run tests to confirm they PASS (GREEN)**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/OnboardingManagerTests 2>&1 | grep -E "Test Case|error:|FAILED|passed"
```

Expected: All 11 `OnboardingManagerTests` pass.

- [ ] **Step 4: Run full test suite to check no regressions**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|error:|FAILED|passed"
```

Expected: All tests pass, no regressions.

- [ ] **Step 5: Commit Bug 2 fix**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add \
  TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Services/OnboardingManager.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockOnboardingService.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Onboarding/OnboardingManagerTests.swift
git commit -m "fix(onboarding): check DB for existing family before showing parent onboarding wizard"
```

---

## Unresolved Questions

None. The three bugs are clearly scoped and independently fixable. The DB data for the test account's 3 duplicate families is a Supabase concern (can be cleaned up manually in the Supabase dashboard by deleting the extra `family_members` and `family_units` rows for `test.parent@andrikanich.com`).
