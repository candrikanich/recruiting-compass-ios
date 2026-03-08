# Face ID Authentication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Face ID as an app-unlock gate that sits in front of the existing session restore flow, with an opt-in prompt shown after first successful login.

**Architecture:** A new `BiometricService` (protocol-backed for testability) wraps `LAContext`. `AuthManager` gains a Keychain-backed `biometricEnabled` flag and delegates to `BiometricService`. On app launch, `TheRecruitingCompassApp` shows a `BiometricLockView` overlay if the flag is set; success lets `restoreSession()` complete normally, failure triggers logout (→ login screen).

**Tech Stack:** `LocalAuthentication` framework, existing `KeychainHelper`, `LAContext`, `@Observable`, SwiftUI `.alert`

---

## Task 1: Add NSFaceIDUsageDescription

**Files:**
- Modify: Xcode target build settings (no source file — this is a build setting)

**Step 1: Add the usage string in Xcode**

This project has no physical `Info.plist` — it uses generated Info.plist via build settings.

In Xcode:
1. Select the **TheRecruitingCompass** target → **Build Settings** tab
2. Search for `NSFaceIDUsageDescription`
3. If it doesn't appear, click **+** → **Add User-Defined Setting**
4. Key: `INFOPLIST_KEY_NSFaceIDUsageDescription`
5. Value: `Sign in quickly and securely with Face ID`

**Step 2: Verify it appears**

Build the project. If `LAContext.evaluatePolicy` is ever called without this key, the app crashes immediately. This setting prevents that.

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass.xcodeproj/project.pbxproj
git commit -m "chore: add NSFaceIDUsageDescription to build settings"
```

---

## Task 2: Create BiometricServiceProtocol and BiometricService

**Files:**
- Create: `TheRecruitingCompass/Core/Protocols/BiometricServiceProtocol.swift`
- Create: `TheRecruitingCompass/Core/Services/BiometricService.swift`

**Step 1: Write `BiometricServiceProtocol.swift`**

```swift
protocol BiometricServiceProtocol: AnyObject {
  func canEvaluateBiometrics() -> Bool
  func authenticate(reason: String) async throws
}
```

**Step 2: Write `BiometricService.swift`**

```swift
import LocalAuthentication

enum BiometricError: LocalizedError {
  case notAvailable
  case lockout
  case cancelled
  case failed

  var errorDescription: String? {
    switch self {
    case .notAvailable: return "Biometric authentication is not available on this device"
    case .lockout:      return "Too many failed attempts. Please sign in with your password."
    case .cancelled:    return nil
    case .failed:       return "Biometric authentication failed"
    }
  }
}

final class BiometricService: BiometricServiceProtocol {
  func canEvaluateBiometrics() -> Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  func authenticate(reason: String) async throws {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      throw BiometricError.notAvailable
    }
    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: reason
      )
      if !success { throw BiometricError.failed }
    } catch let laError as LAError {
      switch laError.code {
      case .biometryLockout:
        throw BiometricError.lockout
      case .userCancel, .appCancel, .systemCancel:
        throw BiometricError.cancelled
      case .biometryNotAvailable, .biometryNotEnrolled:
        throw BiometricError.notAvailable
      default:
        throw BiometricError.failed
      }
    }
  }
}
```

**Step 3: Build to confirm no compile errors**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TheRecruitingCompass/Core/Protocols/BiometricServiceProtocol.swift \
        TheRecruitingCompass/Core/Services/BiometricService.swift
git commit -m "feat(biometric): add BiometricService and BiometricServiceProtocol"
```

---

## Task 3: Create MockBiometricService

**Files:**
- Create: `TheRecruitingCompassTests/Mocks/MockBiometricService.swift`

**Step 1: Write `MockBiometricService.swift`**

```swift
@testable import TheRecruitingCompass

@MainActor
final class MockBiometricService: BiometricServiceProtocol {
  var canEvaluateResult = true
  var authenticateResult: Result<Void, Error> = .success(())
  var authenticateCallCount = 0

  func canEvaluateBiometrics() -> Bool {
    canEvaluateResult
  }

  func authenticate(reason: String) async throws {
    authenticateCallCount += 1
    try authenticateResult.get()
  }
}
```

**Step 2: Build tests to confirm no compile errors**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompassTests/Mocks/MockBiometricService.swift
git commit -m "test(biometric): add MockBiometricService"
```

---

## Task 4: Add Biometric Methods to AuthManaging Protocol

**Files:**
- Modify: `TheRecruitingCompass/Core/Protocols/AuthManaging.swift`
- Modify: `TheRecruitingCompassTests/Mocks/MockAuthManager.swift`

**Step 1: Add methods to `AuthManaging`**

Add these three lines to the protocol body (after the existing `updatePassword` line):

```swift
var biometricEnabled: Bool { get }
func enableBiometrics() throws
func disableBiometrics()
func authenticateWithBiometrics() async throws
```

Full updated file:
```swift
import Foundation

@MainActor
protocol AuthManaging: AnyObject {
  var isAuthenticated: Bool { get }
  var isCheckingSession: Bool { get }
  var user: User? { get }
  var session: Session? { get }
  var biometricEnabled: Bool { get }

  func login(email: String, password: String) async throws
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?) async throws
  func logout() async throws
  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
  func resetPasswordForEmail(email: String) async throws
  func updatePassword(newPassword: String) async throws
  func enableBiometrics() throws
  func disableBiometrics()
  func authenticateWithBiometrics() async throws
}
```

**Step 2: Add stub implementations to `MockAuthManager`**

Add these properties and methods to `MockAuthManager`:

```swift
// MARK: - Biometric Mock State
var biometricEnabled: Bool = false
var enableBiometricsCallCount = 0
var disableBiometricsCallCount = 0
var authenticateWithBiometricsCallCount = 0
var shouldThrowEnableBiometricsError = false
var shouldThrowBiometricAuthError = false
var mockBiometricError: Error = BiometricError.failed

func enableBiometrics() throws {
  enableBiometricsCallCount += 1
  if shouldThrowEnableBiometricsError { throw mockBiometricError }
  biometricEnabled = true
}

func disableBiometrics() {
  disableBiometricsCallCount += 1
  biometricEnabled = false
}

func authenticateWithBiometrics() async throws {
  authenticateWithBiometricsCallCount += 1
  if shouldThrowBiometricAuthError { throw mockBiometricError }
}
```

Also add these to the existing `reset()` method body:
```swift
biometricEnabled = false
enableBiometricsCallCount = 0
disableBiometricsCallCount = 0
authenticateWithBiometricsCallCount = 0
shouldThrowEnableBiometricsError = false
shouldThrowBiometricAuthError = false
```

**Step 3: Build to confirm no compile errors**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED — `AuthManager` doesn't conform yet, but the protocol addition compiles.

**Note:** Build will fail with "Type 'AuthManager' does not conform to protocol 'AuthManaging'" until Task 5 is complete. That's expected — fix it in Task 5.

**Step 4: Commit**

```bash
git add TheRecruitingCompass/Core/Protocols/AuthManaging.swift \
        TheRecruitingCompassTests/Mocks/MockAuthManager.swift
git commit -m "feat(biometric): extend AuthManaging protocol with biometric methods"
```

---

## Task 5: Implement Biometric Support in AuthManager

**Files:**
- Modify: `TheRecruitingCompass/Core/Services/AuthManager.swift`

**Step 1: Add biometric properties and inject BiometricService**

Update `AuthManager` to add the `biometricService` dependency. Modify the `init` signature and add the biometric properties:

```swift
// Add to imports (already has Foundation, OSLog, SwiftUI, Observation — no new imports needed)

// Add inside AuthManager class body, after the existing private properties:
private let biometricEnabledKey = "biometricEnabled"
private let biometricService: any BiometricServiceProtocol

var biometricEnabled: Bool {
  (try? keychain.load(Bool.self, forKey: biometricEnabledKey)) ?? false
}
```

Update `init` to accept an optional `BiometricServiceProtocol`:

```swift
init(
  supabaseManager: (any SupabaseManaging)? = nil,
  biometricService: (any BiometricServiceProtocol)? = nil
) {
  self.supabaseManager = supabaseManager ?? SupabaseManager.shared
  self.biometricService = biometricService ?? BiometricService()
  Task {
    await restoreSession()
  }
}
```

**Step 2: Add biometric methods**

Add after the existing `updatePassword` method:

```swift
func enableBiometrics() throws {
  try keychain.save(true, forKey: biometricEnabledKey)
}

func disableBiometrics() {
  try? keychain.delete(forKey: biometricEnabledKey)
}

func authenticateWithBiometrics() async throws {
  try await biometricService.authenticate(reason: "Sign in to The Recruiting Compass")
}
```

**Step 3: Update `logout()` to clear biometric flag**

At the end of `logout()`, after the `keychain.delete(forKey: sessionKey)` line, add:

```swift
disableBiometrics()
```

**Step 4: Build to confirm conformance is satisfied**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add TheRecruitingCompass/Core/Services/AuthManager.swift
git commit -m "feat(biometric): implement biometric support in AuthManager"
```

---

## Task 6: Write AuthManager Biometric Tests

**Files:**
- Create: `TheRecruitingCompassTests/Core/Services/AuthManagerBiometricTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerBiometricTests: XCTestCase {
  var sut: AuthManager!
  var mockSupabase: MockSupabaseManager!
  var mockBiometricService: MockBiometricService!
  private let biometricEnabledKey = "biometricEnabled"

  override func setUp() {
    super.setUp()
    mockSupabase = MockSupabaseManager()
    mockBiometricService = MockBiometricService()
    sut = AuthManager(supabaseManager: mockSupabase, biometricService: mockBiometricService)
    try? KeychainHelper.shared.delete(forKey: biometricEnabledKey)
  }

  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: biometricEnabledKey)
    sut = nil
    mockSupabase = nil
    mockBiometricService = nil
    super.tearDown()
  }

  // MARK: - biometricEnabled

  func testBiometricEnabledDefaultsFalse() {
    XCTAssertFalse(sut.biometricEnabled)
  }

  func testEnableBiometricsSetsFlag() throws {
    try sut.enableBiometrics()
    XCTAssertTrue(sut.biometricEnabled)
  }

  func testDisableBiometricsClearsFlag() throws {
    try sut.enableBiometrics()
    sut.disableBiometrics()
    XCTAssertFalse(sut.biometricEnabled)
  }

  // MARK: - logout clears biometric

  func testLogoutClearsBiometricFlag() async throws {
    try sut.enableBiometrics()
    XCTAssertTrue(sut.biometricEnabled)

    try await sut.logout()

    XCTAssertFalse(sut.biometricEnabled)
  }

  // MARK: - authenticateWithBiometrics

  func testAuthenticateWithBiometricsCallsService() async throws {
    try await sut.authenticateWithBiometrics()
    XCTAssertEqual(mockBiometricService.authenticateCallCount, 1)
  }

  func testAuthenticateWithBiometricsThrowsOnFailure() async {
    mockBiometricService.authenticateResult = .failure(BiometricError.failed)

    do {
      try await sut.authenticateWithBiometrics()
      XCTFail("Expected throw")
    } catch {
      XCTAssertTrue(error is BiometricError)
    }
  }

  func testAuthenticateWithBiometricsThrowsOnLockout() async {
    mockBiometricService.authenticateResult = .failure(BiometricError.lockout)

    do {
      try await sut.authenticateWithBiometrics()
      XCTFail("Expected throw")
    } catch let error as BiometricError {
      XCTAssertEqual(error, BiometricError.lockout)
    } catch {
      XCTFail("Wrong error type")
    }
  }
}
```

**Note:** `BiometricError` needs to be `Equatable` for the last test. Add `extension BiometricError: Equatable {}` to `BiometricService.swift`.

**Step 2: Run tests to confirm they fail (or pass — some may pass immediately)**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AuthManagerBiometricTests
```
Expected: Tests compile and run. Some may pass immediately after Task 5.

**Step 3: Fix any failures**

If `MockSupabaseManager` doesn't exist in the test target, check `TheRecruitingCompassTests/Mocks/` — there should be a mock supabase manager. If the init requires it, use whatever mock is available.

**Step 4: Run full test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: All tests pass.

**Step 5: Commit**

```bash
git add TheRecruitingCompassTests/Core/Services/AuthManagerBiometricTests.swift \
        TheRecruitingCompass/Core/Services/BiometricService.swift
git commit -m "test(biometric): add AuthManager biometric tests"
```

---

## Task 7: Update LoginViewModel with Biometric Opt-In

**Files:**
- Modify: `TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift`

**Step 1: Add biometric opt-in state and dependencies**

Add to the class body (after the existing `showTimeoutBanner` property):

```swift
var shouldShowBiometricOptIn = false
private let biometricService: any BiometricServiceProtocol
```

Update `init` signature:

```swift
init(
  authManager: (any AuthManaging)? = nil,
  biometricService: (any BiometricServiceProtocol)? = nil,
  timeoutReason: String? = nil
) {
  self.authManager = authManager ?? AuthManager.shared
  self.biometricService = biometricService ?? BiometricService()
  checkTimeoutReason(timeoutReason)
  loadCachedEmail()
}
```

**Step 2: Trigger opt-in after successful login**

In the `login()` method, replace the `do` block's success path. After `try await authManager.login(email: email, password: password)`, add:

```swift
if !authManager.biometricEnabled && biometricService.canEvaluateBiometrics() {
  shouldShowBiometricOptIn = true
}
```

**Step 3: Add opt-in action methods**

Add after the existing `dismissError()` method:

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

**Step 4: Build to confirm no compile errors**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift
git commit -m "feat(biometric): add biometric opt-in logic to LoginViewModel"
```

---

## Task 8: Write LoginViewModel Biometric Tests

**Files:**
- Modify: `TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift`

**Step 1: Update setUp to inject MockBiometricService**

Update `setUp()` to create a `MockBiometricService` and inject it:

```swift
var mockBiometricService: MockBiometricService!

override func setUp() {
  super.setUp()
  clearUserDefaults()
  mockAuthManager = MockAuthManager()
  mockBiometricService = MockBiometricService()
  sut = LoginViewModel(authManager: mockAuthManager, biometricService: mockBiometricService)
}

override func tearDown() {
  sut = nil
  mockAuthManager = nil
  mockBiometricService = nil
  clearUserDefaults()
  super.tearDown()
}
```

**Step 2: Add biometric opt-in tests at the end of the file (before the closing `}`)**

```swift
// MARK: - Biometric Opt-In Tests

func testShouldShowBiometricOptInAfterSuccessfulLoginWhenCapable() async {
  mockBiometricService.canEvaluateResult = true
  mockAuthManager.biometricEnabled = false
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"

  await sut.login()

  XCTAssertTrue(sut.shouldShowBiometricOptIn)
}

func testShouldNotShowBiometricOptInWhenDeviceNotCapable() async {
  mockBiometricService.canEvaluateResult = false
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"

  await sut.login()

  XCTAssertFalse(sut.shouldShowBiometricOptIn)
}

func testShouldNotShowBiometricOptInWhenAlreadyEnabled() async {
  mockBiometricService.canEvaluateResult = true
  mockAuthManager.biometricEnabled = true
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"

  await sut.login()

  XCTAssertFalse(sut.shouldShowBiometricOptIn)
}

func testShouldNotShowBiometricOptInOnFailedLogin() async {
  mockBiometricService.canEvaluateResult = true
  mockAuthManager.shouldThrowLoginError = true
  mockAuthManager.mockErrorToThrow = .invalidCredentials
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"

  await sut.login()

  XCTAssertFalse(sut.shouldShowBiometricOptIn)
}

func testEnableBiometricsCallsAuthManagerAndDismisses() async {
  mockBiometricService.canEvaluateResult = true
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"
  await sut.login()
  XCTAssertTrue(sut.shouldShowBiometricOptIn)

  sut.enableBiometrics()

  XCTAssertEqual(mockAuthManager.enableBiometricsCallCount, 1)
  XCTAssertFalse(sut.shouldShowBiometricOptIn)
}

func testDismissBiometricOptInClearsFlag() async {
  mockBiometricService.canEvaluateResult = true
  sut.email = "user@example.com"
  sut.password = "ValidPassword123"
  await sut.login()
  XCTAssertTrue(sut.shouldShowBiometricOptIn)

  sut.dismissBiometricOptIn()

  XCTAssertFalse(sut.shouldShowBiometricOptIn)
  XCTAssertEqual(mockAuthManager.enableBiometricsCallCount, 0)
}
```

**Step 3: Run the new tests**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/LoginViewModelTests
```
Expected: All tests pass including the new biometric ones.

**Step 4: Run full test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: All tests pass.

**Step 5: Commit**

```bash
git add TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift
git commit -m "test(biometric): add LoginViewModel biometric opt-in tests"
```

---

## Task 9: Update LoginView with Opt-In Alert

**Files:**
- Modify: `TheRecruitingCompass/Features/Auth/Views/LoginView.swift`

**Step 1: Add the opt-in alert to the view's `body`**

Add a `.alert` modifier to the outermost `ZStack` in `body`. Append it after `.navigationBarBackButtonHidden(true)`:

```swift
.alert("Enable Face ID?", isPresented: $viewModel.shouldShowBiometricOptIn) {
  Button("Enable") { viewModel.enableBiometrics() }
  Button("Not Now", role: .cancel) { viewModel.dismissBiometricOptIn() }
} message: {
  Text("Sign in quickly and securely with Face ID on future visits.")
}
```

**Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/Features/Auth/Views/LoginView.swift
git commit -m "feat(biometric): add Face ID opt-in alert to LoginView"
```

---

## Task 10: Create BiometricLockView

**Files:**
- Create: `TheRecruitingCompass/Features/Auth/Views/BiometricLockView.swift`

**Step 1: Write `BiometricLockView.swift`**

```swift
import SwiftUI

struct BiometricLockView: View {
  let authManager: AuthManager
  let onSuccess: () -> Void
  let onFailure: () -> Void

  var body: some View {
    ZStack {
      LinearGradient.landingBackground
        .ignoresSafeArea()

      VStack(spacing: 32) {
        Image("AppLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 160)
          .accessibilityHidden(true)

        VStack(spacing: 16) {
          Image(systemName: "faceid")
            .font(.system(size: 56))
            .foregroundColor(.white)
            .accessibilityHidden(true)

          Text("Sign in with Face ID")
            .font(.title3.weight(.semibold))
            .foregroundColor(.white)
        }

        VStack(spacing: 12) {
          Button(action: { Task { await authenticate() } }) {
            Text("Use Face ID")
              .font(.callout.weight(.semibold))
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .foregroundColor(.white)
              .background(Color.white.opacity(0.25))
              .cornerRadius(8)
          }
          .accessibilityLabel("Sign in with Face ID")

          Button(action: onFailure) {
            Text("Use Password Instead")
              .font(.footnote)
              .foregroundColor(.white.opacity(0.8))
              .frame(minHeight: 44)
          }
          .accessibilityLabel("Sign in with password")
          .accessibilityHint("Returns to the login form")
        }
        .padding(.horizontal, 40)
      }
    }
    .task { await authenticate() }
  }

  private func authenticate() async {
    do {
      try await authManager.authenticateWithBiometrics()
      onSuccess()
    } catch BiometricError.cancelled {
      // User cancelled — stay on lock screen so they can retry
    } catch {
      onFailure()
    }
  }
}
```

**Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/Features/Auth/Views/BiometricLockView.swift
git commit -m "feat(biometric): add BiometricLockView"
```

---

## Task 11: Wire BiometricLockView into TheRecruitingCompassApp

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompassApp.swift`

**Step 1: Add biometric lock state**

Add after the existing `@State private var pendingInvite: PendingInvite?` line:

```swift
@State private var showBiometricLock = false
```

**Step 2: Add biometric lock overlay**

In the `body` computed property, chain a `.overlay` modifier on the outermost `Group`. Add it between `.animation(... value: authManager.isCheckingSession)` and `.onOpenURL`:

```swift
.overlay {
  if showBiometricLock {
    BiometricLockView(
      authManager: authManager,
      onSuccess: { showBiometricLock = false },
      onFailure: {
        showBiometricLock = false
        Task { try? await authManager.logout() }
      }
    )
    .transition(.opacity)
  }
}
```

**Step 3: Trigger the lock on launch**

Add a `.task` modifier after the `.overlay`:

```swift
.task {
  if authManager.biometricEnabled {
    showBiometricLock = true
  }
}
```

**Step 4: Build to confirm no compile errors**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED

**Step 5: Run the full test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: All existing tests pass. New tests pass.

**Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompassApp.swift
git commit -m "feat(biometric): wire BiometricLockView into app launch flow"
```

---

## Task 12: Final Verification

**Step 1: Run full build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED, 0 warnings about LocalAuthentication usage

**Step 2: Run full test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: All tests pass (126+ existing + new biometric tests)

**Step 3: Manual smoke test in Simulator**

1. Launch app in Simulator (iPhone 17)
2. Log in with email/password → should see "Enable Face ID?" alert
3. Tap "Enable" → biometric flag stored
4. Force-quit and relaunch app → should see `BiometricLockView`
5. In Simulator: **Features → Face ID → Enrolled** then **Features → Face ID → Matching Face**
6. Confirm app unlocks and navigates to dashboard
7. Test "Use Password Instead" → confirm returns to login

**Step 4: Final commit summary**

```bash
git log --oneline -8
```

---

## Unresolved Questions

- **`KeychainHelper.save(Bool, forKey:)` support:** Verify `KeychainHelper` encodes `Bool` via `Codable`. If not, store as `"1"` / `""` string instead.
- **`MockSupabaseManager` in tests:** `AuthManagerBiometricTests` injects `mockSupabase`. Confirm the correct mock class name in `TheRecruitingCompassTests/Mocks/`.
- **Simulator Face ID:** Face ID in Simulator requires manual enrollment via **Features → Face ID → Enrolled**. CI tests won't cover `BiometricLockView` UI — this is expected.
