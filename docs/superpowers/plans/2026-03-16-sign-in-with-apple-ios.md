# Sign in with Apple — iOS Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add native Sign in with Apple to the iOS app so both new and returning Apple users can authenticate, with new users completing role selection before reaching the Dashboard.

**Architecture:** `AppleSignInService` manages nonce state and parses credentials via `SignInWithAppleButton` callbacks (no `ASAuthorizationController`). `AuthManager.signInWithApple(credential:)` calls `SupabaseManager` to exchange the Apple JWT for a Supabase session. New users (no `public.users` row) are held at `AppleProfileSetupView` — `isAuthenticated` stays `false` — until they select a role and call `completeAppleSignIn`. Returning users go straight to Dashboard. `OnboardingManager` fires only after `isAuthenticated = true`, so it always has a populated role.

**Tech Stack:** Swift/SwiftUI, AuthenticationServices (iOS 14+), CryptoKit, Supabase Swift SDK v2.41.1, XCTest

**Spec:** `docs/superpowers/specs/2026-03-15-sign-in-with-apple-design.md`

---

## Chunk 1: Prerequisites, AuthError, AppleSignInService, Protocols, Mocks

### Task 0: Prerequisites (Manual — No Code)

These steps must be completed in Apple Developer Portal and Supabase before end-to-end testing. Code can be written in parallel.

**Apple Developer Portal (developer.apple.com → Certificates, Identifiers & Profiles):**

- [ ] Identifiers → select App ID `com.theRecruitingCompass.app` → Edit → enable **Sign In with Apple** → Save
- [ ] Identifiers → `+` → Service IDs → Identifier: `com.theRecruitingCompass.web`, Description: "Recruiting Compass Web" → Continue → Register
- [ ] Edit the new Service ID → enable **Sign In with Apple** → Configure → add Return URL: `https://xpxzhqghxecsjhvklsqg.supabase.co/auth/v1/callback` → Save
- [ ] Keys → `+` → enable **Sign In with Apple** → Configure → Primary App ID: `com.theRecruitingCompass.app` → Save → Download `.p8` file (one-time download — store securely) → note the **Key ID**
- [ ] Note your **Team ID** (shown top-right in Apple Developer portal)

**Supabase Dashboard (supabase.com → your project):**

- [ ] Authentication → Providers → Apple → Enable → fill: Client ID = `com.theRecruitingCompass.web`, Secret Key = full `.p8` file contents, Key ID, Team ID → Save
- [ ] Authentication → Settings → enable **"Allow automatic linking for same-email accounts"** → Save
- [ ] Authentication → URL Configuration → add `https://myrecruitingcompass.com/apple-callback` to Redirect URLs → Save

---

### Task 1: Add `appleSignInCanceled` to `AuthError`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Models/AuthError.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Models/AuthErrorAppleTests.swift`

- [ ] **Step 1.1 — Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Models/AuthErrorAppleTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class AuthErrorAppleTests: XCTestCase {
    func testAppleSignInCanceledHasNoErrorDescription() {
        XCTAssertNil(AuthError.appleSignInCanceled.errorDescription)
    }

    func testAppleSignInCanceledHasNoRecoverySuggestion() {
        XCTAssertNil(AuthError.appleSignInCanceled.recoverySuggestion)
    }
}
```

- [ ] **Step 1.2 — Run to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AuthErrorAppleTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `AuthError.appleSignInCanceled` does not exist yet.

- [ ] **Step 1.3 — Add the case**

In `AuthError.swift`, add `case appleSignInCanceled` before `case unknown(Error)`.

In the `errorDescription` switch, add before `case .unknown`:
```swift
case .appleSignInCanceled:
    return nil
```

In the `recoverySuggestion` switch, add before `case .unknown`:
```swift
case .appleSignInCanceled:
    return nil
```

- [ ] **Step 1.4 — Run to verify it passes**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AuthErrorAppleTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: 2 tests PASS.

- [ ] **Step 1.5 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Models/AuthError.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Models/AuthErrorAppleTests.swift
git commit -m "feat: add AuthError.appleSignInCanceled for silent Apple sheet cancel"
```

---

### Task 2: AppleSignInService

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppleSignInService.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AppleSignInServiceTests.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAppleSignInService.swift`

`AppleSignInService` manages nonce state and parses Apple credential results. It uses `SignInWithAppleButton`'s callbacks — no `ASAuthorizationController`. Note: testing the `.success` path requires a real `ASAuthorization` object (not constructable in unit tests). The cancel and error paths are fully testable; success is covered by integration/E2E testing.

- [ ] **Step 2.1 — Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AppleSignInServiceTests.swift`:

```swift
import XCTest
import AuthenticationServices
import CryptoKit
@testable import TheRecruitingCompass

@MainActor
final class AppleSignInServiceTests: XCTestCase {
    var sut: AppleSignInService!

    override func setUp() {
        super.setUp()
        sut = AppleSignInService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - prepareRequest

    func testPrepareRequestSetsHashedNonceOnRequest() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        sut.prepareRequest(request)
        XCTAssertNotNil(request.nonce, "hashed nonce should be set on request")
        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
    }

    func testPrepareRequestGeneratesUniqueNoncesAcrossCalls() {
        let r1 = ASAuthorizationAppleIDProvider().createRequest()
        let r2 = ASAuthorizationAppleIDProvider().createRequest()
        sut.prepareRequest(r1)
        sut.prepareRequest(r2)
        XCTAssertNotEqual(r1.nonce, r2.nonce, "each prepareRequest call must produce a unique nonce")
    }

    func testTwoServiceInstancesProduceDifferentNonces() {
        let r1 = ASAuthorizationAppleIDProvider().createRequest()
        let r2 = ASAuthorizationAppleIDProvider().createRequest()
        sut.prepareRequest(r1)
        AppleSignInService().prepareRequest(r2)
        XCTAssertNotEqual(r1.nonce, r2.nonce)
    }

    // MARK: - credential(from:) — failure paths

    func testCancelErrorThrowsAppleSignInCanceled() {
        let cancelError = ASAuthorizationError(.canceled)
        XCTAssertThrowsError(try sut.credential(from: .failure(cancelError))) { error in
            if case AuthError.appleSignInCanceled = error as? AuthError { /* expected */ }
            else { XCTFail("Expected appleSignInCanceled, got \(error)") }
        }
    }

    func testOtherErrorThrowsServerError() {
        let other = NSError(domain: "test", code: 42,
                            userInfo: [NSLocalizedDescriptionKey: "network fail"])
        XCTAssertThrowsError(try sut.credential(from: .failure(other))) { error in
            if case AuthError.serverError = error as? AuthError { /* expected */ }
            else { XCTFail("Expected serverError, got \(error)") }
        }
    }

    // Note: testing .success path requires a real ASAuthorization object which
    // cannot be constructed in unit tests. Covered by manual E2E test in Task 10.
}
```

- [ ] **Step 2.2 — Run to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppleSignInServiceTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `AppleSignInService` does not exist.

- [ ] **Step 2.3 — Implement `AppleSignInService`**

Create `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppleSignInService.swift`:

```swift
import AuthenticationServices
import CryptoKit
import Foundation

protocol AppleSignInServiceProtocol: AnyObject {
    @MainActor func prepareRequest(_ request: ASAuthorizationAppleIDRequest)
    @MainActor func credential(from result: Result<ASAuthorization, Error>) throws -> AppleCredential
}

struct AppleCredential: Sendable {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

@MainActor
final class AppleSignInService: AppleSignInServiceProtocol {
    private var pendingNonce: String?

    nonisolated deinit {}

    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        pendingNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func credential(from result: Result<ASAuthorization, Error>) throws -> AppleCredential {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                throw AuthError.appleSignInCanceled
            }
            throw AuthError.serverError(error.localizedDescription)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = pendingNonce else {
                throw AuthError.serverError("Invalid Apple credential")
            }
            pendingNonce = nil
            return AppleCredential(
                idToken: idToken,
                nonce: nonce,
                fullName: credential.fullName,
                email: credential.email
            )
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            (0..<16).map { _ in UInt8.random(in: 0...255) }.forEach { byte in
                guard remaining > 0, byte < charset.count else { return }
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
```

- [ ] **Step 2.4 — Run to verify tests pass**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppleSignInServiceTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: 5 tests PASS.

- [ ] **Step 2.5 — Create `MockAppleSignInService`**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAppleSignInService.swift`:

```swift
import AuthenticationServices
@testable import TheRecruitingCompass

@MainActor
final class MockAppleSignInService: AppleSignInServiceProtocol {
    var prepareRequestCallCount = 0
    var credentialCallCount = 0
    var credentialToReturn = AppleCredential(
        idToken: "mock-token", nonce: "mock-nonce", fullName: nil, email: nil
    )
    var errorToThrow: Error? = nil

    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        prepareRequestCallCount += 1
    }

    func credential(from result: Result<ASAuthorization, Error>) throws -> AppleCredential {
        credentialCallCount += 1
        if let error = errorToThrow { throw error }
        return credentialToReturn
    }
}
```

- [ ] **Step 2.6 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppleSignInService.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AppleSignInServiceTests.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAppleSignInService.swift
git commit -m "feat: add AppleSignInService with nonce management and credential parsing"
```

---

### Task 3: Protocol changes + Mock updates

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/SupabaseManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAuthManager.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift`

No new test file — a clean build is the verification.

- [ ] **Step 3.1 — Extend `AuthManaging`**

In `AuthManaging.swift`, add after `func authenticateWithBiometrics() async throws`:

```swift
  // MARK: - Apple Sign In
  var needsAppleProfileSetup: Bool { get }
  var pendingAppleName: PersonNameComponents? { get }
  func signInWithApple(credential: AppleCredential) async throws
  func completeAppleSignIn(role: UserRole, fullName: String?) async throws
```

Add `import AuthenticationServices` at the top (needed for `PersonNameComponents` — it's actually from Foundation, but `AppleCredential` type needs the import chain to resolve).

Actually `PersonNameComponents` is from Foundation, not AuthenticationServices. Add `import Foundation` if not already present. `AppleCredential` is defined in `AppleSignInService.swift` so no import needed for it in the protocol — just ensure the module compiles together.

- [ ] **Step 3.2 — Extend `SupabaseManaging`**

In `SupabaseManaging.swift`, add after `func updatePassword(newPassword: String) async throws`:

```swift
  func signInWithApple(
    idToken: String,
    nonce: String
  ) async throws -> (session: Session, user: User?, isNewUser: Bool)
  func createAppleUser(
    userId: String,
    email: String,
    fullName: PersonNameComponents?,
    role: UserRole
  ) async throws -> User
```

- [ ] **Step 3.3 — Add Apple stubs to `MockAuthManager`**

In `MockAuthManager.swift`, add after the existing mock state block:

```swift
  // MARK: - Apple Sign In Mock State
  var needsAppleProfileSetup: Bool = false
  var pendingAppleName: PersonNameComponents? = nil
  var signInWithAppleCallCount = 0
  var completeAppleSignInCallCount = 0
  var lastAppleCredential: AppleCredential? = nil
  var lastAppleRole: UserRole? = nil
  var shouldThrowAppleSignInError = false
  var shouldThrowCompleteAppleSignInError = false
  /// Set to true to simulate the new-user path (needsAppleProfileSetup = true, isAuthenticated = false)
  var mockSignInWithAppleIsNewUser = false
```

And add the method implementations at the bottom of the class:

```swift
  func signInWithApple(credential: AppleCredential) async throws {
    signInWithAppleCallCount += 1
    lastAppleCredential = credential
    if shouldThrowAppleSignInError { throw mockErrorToThrow }
    if mockSignInWithAppleIsNewUser {
      needsAppleProfileSetup = true
      // isAuthenticated stays false — new user must complete profile setup
    } else {
      isAuthenticated = true
    }
  }

  func completeAppleSignIn(role: UserRole, fullName: String?) async throws {
    completeAppleSignInCallCount += 1
    lastAppleRole = role
    if shouldThrowCompleteAppleSignInError { throw mockErrorToThrow }
    let now = ISO8601DateFormatter().string(from: Date())
    user = User(
      id: "apple-test-user", email: "test@privaterelay.appleid.com",
      emailConfirmedAt: nil, phone: nil, fullName: fullName,
      createdAt: now, updatedAt: now, role: role
    )
    isAuthenticated = true
    needsAppleProfileSetup = false
  }
```

- [ ] **Step 3.4 — Add Apple stubs to `MockSupabaseManager`**

In `MockSupabaseManager.swift`, add:

```swift
  var signInWithAppleResult: Result<(session: Session, user: User?, isNewUser: Bool), Error> =
    .failure(AuthError.networkError("Mock: not configured"))
  var createAppleUserResult: Result<User, Error> =
    .failure(AuthError.networkError("Mock: not configured"))

  func signInWithApple(
    idToken: String,
    nonce: String
  ) async throws -> (session: Session, user: User?, isNewUser: Bool) {
    try signInWithAppleResult.get()
  }

  func createAppleUser(
    userId: String,
    email: String,
    fullName: PersonNameComponents?,
    role: UserRole
  ) async throws -> User {
    try createAppleUserResult.get()
  }
```

- [ ] **Step 3.5 — Build to verify**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 3.6 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift \
        TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/SupabaseManaging.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockAuthManager.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift
git commit -m "feat: extend AuthManaging and SupabaseManaging protocols for Apple sign-in"
```

---

## Chunk 2: SupabaseManager, AuthManager, AppleProfileSetup

### Task 4: SupabaseManager — Apple methods

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/SupabaseManagerAppleTests.swift`

The `signInWithIdToken` call is an integration point (requires real Apple credentials). Unit tests cover the helper logic — name resolution and the `isNewUser` detection — rather than the Supabase network call.

- [ ] **Step 4.1 — Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/SupabaseManagerAppleTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class SupabaseManagerAppleTests: XCTestCase {

    // Tests for name resolution logic used in createAppleUser.
    // These test pure Swift logic, not the Supabase API call.

    func testFullNameConcatenatesGivenAndFamily() {
        var name = PersonNameComponents()
        name.givenName = "Chris"
        name.familyName = "Andrikanich"
        let resolved = [name.givenName, name.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(resolved, "Chris Andrikanich")
    }

    func testFullNameWithOnlyGivenName() {
        var name = PersonNameComponents()
        name.givenName = "Chris"
        name.familyName = nil
        let resolved = [name.givenName, name.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(resolved, "Chris")
    }

    func testFullNameWithNilComponents() {
        let name: PersonNameComponents? = nil
        let resolved = [name?.givenName, name?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(resolved.isEmpty)
    }

    func testSupabaseManagerConformsToProtocol() {
        // Verifies signInWithApple and createAppleUser satisfy the protocol.
        let _: any SupabaseManaging = SupabaseManager.shared
    }
}
```

- [ ] **Step 4.2 — Run to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SupabaseManagerAppleTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `signInWithApple` not implemented on `SupabaseManager`.

- [ ] **Step 4.3 — Implement both methods in `SupabaseManager`**

In `SupabaseManager.swift`, add after the `updatePassword` method:

```swift
    func signInWithApple(
        idToken: String,
        nonce: String
    ) async throws -> (session: Session, user: User?, isNewUser: Bool) {
        let authSession = try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        ))
        let userId = authSession.user.id.uuidString
        let email = authSession.user.email ?? ""
        let user = try await fetchUserProfileWithRetry(
            userId: userId,
            email: email,
            fallbackMetadata: authSession.user.userMetadata
        )
        let isNewUser = user == nil
        let session: Session
        if let user {
            session = mapToSession(authSession, user: user)
        } else {
            let placeholder = User(
                id: userId, email: email,
                emailConfirmedAt: nil, phone: nil, fullName: nil,
                createdAt: Self.isoFormatter.string(from: Date.now),
                updatedAt: Self.isoFormatter.string(from: Date.now),
                role: nil
            )
            session = mapToSession(authSession, user: placeholder)
        }
        return (session, user, isNewUser)
    }

    func createAppleUser(
        userId: String,
        email: String,
        fullName: PersonNameComponents?,
        role: UserRole
    ) async throws -> User {
        let resolvedName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let displayName: String? = resolvedName.isEmpty ? nil : resolvedName
        try await client
            .from("users")
            .upsert(
                UsersUpsertPayload(
                    id: userId,
                    email: email,
                    fullName: displayName ?? "",
                    role: role.rawValue
                ),
                onConflict: "id"
            )
            .execute()
        try await client.auth.update(user: .init(data: [
            "role": .string(role.rawValue),
            "full_name": .string(displayName ?? "")
        ]))
        return User(
            id: userId, email: email,
            emailConfirmedAt: nil, phone: nil, fullName: displayName,
            createdAt: Self.isoFormatter.string(from: Date.now),
            updatedAt: Self.isoFormatter.string(from: Date.now),
            role: role
        )
    }
```

- [ ] **Step 4.4 — Run to verify tests pass**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SupabaseManagerAppleTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: 4 tests PASS.

- [ ] **Step 4.5 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/SupabaseManagerAppleTests.swift
git commit -m "feat: add signInWithApple and createAppleUser to SupabaseManager"
```

---

### Task 5: AuthManager — Apple methods

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerAppleTests.swift`

- [ ] **Step 5.1 — Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerAppleTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerAppleTests: XCTestCase {
    var sut: AuthManager!
    var mockSupabase: MockSupabaseManager!
    private let sessionKey = "savedSession"

    override func setUp() {
        super.setUp()
        mockSupabase = MockSupabaseManager()
        sut = AuthManager(supabaseManager: mockSupabase)
        try? KeychainHelper.shared.delete(forKey: sessionKey)
    }

    override func tearDown() {
        try? KeychainHelper.shared.delete(forKey: sessionKey)
        sut = nil
        mockSupabase = nil
        super.tearDown()
    }

    private func makeUser(id: String = "u1", role: UserRole? = .parent) -> User {
        User(id: id, email: "test@apple.com", emailConfirmedAt: nil, phone: nil,
             createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: role)
    }

    private func makeSession(role: UserRole? = .parent) -> Session {
        let user = makeUser(role: role)
        return Session(accessToken: "access", tokenType: "bearer",
                       expiresIn: 3600, expiresAt: Int(Date().timeIntervalSince1970) + 3600,
                       refreshToken: "refresh", user: user)
    }

    private func makeCredential(fullName: PersonNameComponents? = nil) -> AppleCredential {
        AppleCredential(idToken: "token", nonce: "nonce", fullName: fullName, email: nil)
    }

    // MARK: - Returning user

    func testSignInWithAppleReturningUserSetsAuthenticated() async throws {
        let session = makeSession()
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: session.user, isNewUser: false)
        )
        try await sut.signInWithApple(credential: makeCredential())
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.user?.id, "u1")
        XCTAssertFalse(sut.needsAppleProfileSetup)
        XCTAssertNil(sut.errorMessage)
    }

    func testSignInWithAppleReturningUserSavesSession() async throws {
        let session = makeSession()
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: session.user, isNewUser: false)
        )
        try await sut.signInWithApple(credential: makeCredential())
        let saved = try? KeychainHelper.shared.load(Session.self, forKey: sessionKey)
        XCTAssertNotNil(saved)
    }

    // MARK: - New user

    func testSignInWithAppleNewUserSetsProfileSetupFlag() async throws {
        let session = makeSession(role: nil)
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: nil, isNewUser: true)
        )
        var name = PersonNameComponents()
        name.givenName = "Chris"
        name.familyName = "A"
        try await sut.signInWithApple(credential: makeCredential(fullName: name))
        XCTAssertFalse(sut.isAuthenticated, "New user must not be authenticated before profile setup")
        XCTAssertTrue(sut.needsAppleProfileSetup)
        XCTAssertEqual(sut.pendingAppleName?.givenName, "Chris")
    }

    func testSignInWithAppleNewUserDoesNotSaveToKeychain() async throws {
        let session = makeSession(role: nil)
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: nil, isNewUser: true)
        )
        try await sut.signInWithApple(credential: makeCredential())
        let saved = try? KeychainHelper.shared.load(Session.self, forKey: sessionKey)
        XCTAssertNil(saved, "Session must not be saved to Keychain until completeAppleSignIn is called")
    }

    // MARK: - Error

    func testSignInWithAppleErrorSetsErrorMessage() async {
        mockSupabase.signInWithAppleResult = .failure(AuthError.networkError("No connection"))
        do {
            try await sut.signInWithApple(credential: makeCredential())
            XCTFail("Expected error")
        } catch {
            XCTAssertFalse(sut.isAuthenticated)
            XCTAssertNotNil(sut.errorMessage)
        }
    }

    // MARK: - completeAppleSignIn

    func testCompleteAppleSignInSetsAuthenticated() async throws {
        let session = makeSession(role: nil)
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: nil, isNewUser: true)
        )
        try await sut.signInWithApple(credential: makeCredential())

        mockSupabase.createAppleUserResult = .success(makeUser(role: .parent))
        try await sut.completeAppleSignIn(role: .parent, fullName: nil)

        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertFalse(sut.needsAppleProfileSetup)
        XCTAssertNil(sut.pendingAppleName)
        XCTAssertEqual(sut.user?.role, .parent)
    }

    func testCompleteAppleSignInSavesSession() async throws {
        let session = makeSession(role: nil)
        mockSupabase.signInWithAppleResult = .success(
            (session: session, user: nil, isNewUser: true)
        )
        try await sut.signInWithApple(credential: makeCredential())
        mockSupabase.createAppleUserResult = .success(makeUser(role: .coach))
        try await sut.completeAppleSignIn(role: .coach, fullName: nil)
        let saved = try? KeychainHelper.shared.load(Session.self, forKey: sessionKey)
        XCTAssertNotNil(saved)
    }

    func testCompleteAppleSignInWithoutPendingSessionThrows() async {
        do {
            try await sut.completeAppleSignIn(role: .parent, fullName: nil)
            XCTFail("Expected error — no pending session")
        } catch {
            XCTAssertFalse(sut.isAuthenticated)
        }
    }
}
```

- [ ] **Step 5.2 — Run to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AuthManagerAppleTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `signInWithApple(credential:)` not implemented on `AuthManager`.

- [ ] **Step 5.3 — Implement in `AuthManager`**

Add to `AuthManager.swift` after the `restoreSession()` method:

```swift
    // MARK: - Apple Sign In

    var needsAppleProfileSetup = false
    var pendingAppleName: PersonNameComponents? = nil

    func signInWithApple(credential: AppleCredential) async throws {
        logger.debug("Attempting Sign in with Apple")
        do {
            let result = try await supabaseManager.signInWithApple(
                idToken: credential.idToken,
                nonce: credential.nonce
            )
            self.session = result.session
            self.errorMessage = nil
            if result.isNewUser {
                self.pendingAppleName = credential.fullName
                self.needsAppleProfileSetup = true
                logger.info("New Apple user — showing profile setup")
            } else {
                guard let user = result.user else {
                    throw AuthError.serverError("Failed to load user profile")
                }
                self.user = user
                self.isAuthenticated = true
                try keychain.save(result.session, forKey: sessionKey)
                logger.info("Apple sign-in complete for user: \(user.id, privacy: .private)")
            }
        } catch {
            self.errorMessage = (error as? AuthError)?.errorDescription
                ?? "Sign in with Apple failed. Please try again."
            logger.error("Apple sign-in failed: \(error.localizedDescription)")
            throw error
        }
    }

    func completeAppleSignIn(role: UserRole, fullName: String?) async throws {
        guard let session else {
            throw AuthError.serverError("No pending Apple session")
        }
        logger.debug("Completing Apple sign-in for role: \(role.rawValue)")
        do {
            let user = try await supabaseManager.createAppleUser(
                userId: session.user.id,
                email: session.user.email,
                fullName: pendingAppleName,
                role: role
            )
            self.user = user
            self.isAuthenticated = true
            self.needsAppleProfileSetup = false
            self.pendingAppleName = nil
            try keychain.save(session, forKey: sessionKey)
            logger.info("Apple profile setup complete for user: \(user.id, privacy: .private)")
        } catch {
            self.errorMessage = (error as? AuthError)?.errorDescription
                ?? "Profile setup failed. Please try again."
            logger.error("Apple profile setup failed: \(error.localizedDescription)")
            throw error
        }
    }
```

- [ ] **Step 5.4 — Run to verify tests pass**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AuthManagerAppleTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: 8 tests PASS.

- [ ] **Step 5.5 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/AuthManagerAppleTests.swift
git commit -m "feat: implement signInWithApple and completeAppleSignIn on AuthManager"
```

---

### Task 6: AppleProfileSetupViewModel + AppleProfileSetupView

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/AppleProfileSetupViewModel.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/AppleProfileSetupView.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/AppleProfileSetupViewModelTests.swift`

- [ ] **Step 6.1 — Write the failing tests**

Create `TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/AppleProfileSetupViewModelTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AppleProfileSetupViewModelTests: XCTestCase {
    var sut: AppleProfileSetupViewModel!
    var mockAuth: MockAuthManager!

    override func setUp() {
        super.setUp()
        mockAuth = MockAuthManager()
        sut = AppleProfileSetupViewModel(authManager: mockAuth)
    }

    override func tearDown() {
        sut = nil
        mockAuth = nil
        super.tearDown()
    }

    func testInitialStateHasNoRole() {
        XCTAssertNil(sut.selectedRole)
    }

    func testContinueDisabledWithNoRole() {
        XCTAssertTrue(sut.isContinueDisabled)
    }

    func testSelectingRoleEnablesContinue() {
        sut.selectedRole = .parent
        XCTAssertFalse(sut.isContinueDisabled)
    }

    func testDisplayNameFromPendingAppleName() {
        var name = PersonNameComponents()
        name.givenName = "Chris"
        name.familyName = "A"
        mockAuth.pendingAppleName = name
        sut = AppleProfileSetupViewModel(authManager: mockAuth)
        XCTAssertEqual(sut.displayName, "Chris A")
    }

    func testDisplayNameEmptyWhenNoPendingName() {
        mockAuth.pendingAppleName = nil
        sut = AppleProfileSetupViewModel(authManager: mockAuth)
        XCTAssertEqual(sut.displayName, "")
    }

    func testSubmitCallsCompleteAppleSignIn() async throws {
        sut.selectedRole = .parent
        try await sut.submit()
        XCTAssertEqual(mockAuth.completeAppleSignInCallCount, 1)
        XCTAssertEqual(mockAuth.lastAppleRole, .parent)
    }

    func testSubmitResetsIsLoadingOnSuccess() async throws {
        sut.selectedRole = .coach
        try await sut.submit()
        XCTAssertFalse(sut.isLoading)
    }

    func testSubmitSetsErrorMessageOnFailure() async {
        sut.selectedRole = .parent
        mockAuth.shouldThrowCompleteAppleSignInError = true
        do { try await sut.submit() } catch { }
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testSubmitWithNoRoleDoesNotCallManager() async throws {
        sut.selectedRole = nil
        try await sut.submit()
        XCTAssertEqual(mockAuth.completeAppleSignInCallCount, 0)
    }
}
```

- [ ] **Step 6.2 — Run to verify it fails**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppleProfileSetupViewModelTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `AppleProfileSetupViewModel` does not exist.

- [ ] **Step 6.3 — Implement `AppleProfileSetupViewModel`**

Create `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/AppleProfileSetupViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
@MainActor
final class AppleProfileSetupViewModel {
    var selectedRole: UserRole? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var displayName: String

    var isContinueDisabled: Bool { selectedRole == nil || isLoading }

    private let authManager: any AuthManaging

    nonisolated deinit {}

    init(authManager: (any AuthManaging)? = nil) {
        let manager = authManager ?? AuthManager.shared
        self.authManager = manager
        if let name = manager.pendingAppleName {
            let parts = [name.givenName, name.familyName].compactMap { $0 }
            displayName = parts.joined(separator: " ")
        } else {
            displayName = ""
        }
    }

    func submit() async throws {
        guard let role = selectedRole else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authManager.completeAppleSignIn(
                role: role,
                fullName: displayName.isEmpty ? nil : displayName
            )
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription
                ?? "Profile setup failed. Please try again."
            throw error
        }
    }
}
```

- [ ] **Step 6.4 — Run to verify tests pass**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppleProfileSetupViewModelTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: 8 tests PASS.

- [ ] **Step 6.5 — Implement `AppleProfileSetupView`**

Create `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/AppleProfileSetupView.swift`:

```swift
import SwiftUI

struct AppleProfileSetupView: View {
    @State private var viewModel = AppleProfileSetupViewModel()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 44))
                        .accessibilityHidden(true)
                    Text("Welcome\(viewModel.displayName.isEmpty ? "" : ", \(viewModel.displayName.components(separatedBy: " ").first ?? "")")")
                        .font(.title2.bold())
                    Text("How will you be using The Recruiting Compass?")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    ForEach([UserRole.parent, UserRole.coach], id: \.self) { role in
                        RoleSelectionCard(
                            role: role,
                            isSelected: viewModel.selectedRole == role,
                            action: { viewModel.selectedRole = role }
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        do { try await viewModel.submit() } catch { }
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isContinueDisabled)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("Select Your Role")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel = AppleProfileSetupViewModel(authManager: authManager)
        }
    }
}
```

- [ ] **Step 6.6 — Build to verify**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6.7 — Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/AppleProfileSetupViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/AppleProfileSetupView.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/AppleProfileSetupViewModelTests.swift
git commit -m "feat: add AppleProfileSetupViewModel and View for new Apple users"
```

---

## Chunk 3: ViewModel Wiring, Views, Entitlements, Navigation

### Task 7: LoginViewModel + SignupViewModel — Apple methods

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/SignupViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/SignupViewModelTests.swift`

- [ ] **Step 7.1 — Write the failing tests**

Add to `LoginViewModelTests.swift` (add `import AuthenticationServices` at the top if not present):

```swift
    // MARK: - Apple Sign In

    func testPrepareAppleRequestCallsService() {
        let mockApple = MockAppleSignInService()
        let sut = LoginViewModel(authManager: mockAuthManager,
                                 biometricService: mockBiometricService,
                                 appleSignInService: mockApple)
        sut.prepareAppleRequest(ASAuthorizationAppleIDProvider().createRequest())
        XCTAssertEqual(mockApple.prepareRequestCallCount, 1)
    }

    func testHandleAppleCompletionSuccessCallsAuthManager() async {
        let mockApple = MockAppleSignInService()
        let sut = LoginViewModel(authManager: mockAuthManager,
                                 biometricService: mockBiometricService,
                                 appleSignInService: mockApple)
        mockApple.credentialToReturn = AppleCredential(
            idToken: "tok", nonce: "n", fullName: nil, email: nil
        )
        // Pass a failure result — the mock ignores the ASAuthorization value and
        // returns credentialToReturn directly (nil errorToThrow = success path).
        sut.handleAppleCompletion(.failure(NSError(domain: "test", code: 0)))
        // `handleAppleCompletion` fires an internal unstructured Task. Yield the
        // current actor turn repeatedly until the call registers or timeout.
        for _ in 0..<20 {
            if mockAuthManager.signInWithAppleCallCount > 0 { break }
            await Task.yield()
        }
        XCTAssertEqual(mockAuthManager.signInWithAppleCallCount, 1)
    }

    func testHandleAppleCompletionCancelIsIgnoredSilently() {
        let mockApple = MockAppleSignInService()
        mockApple.errorToThrow = AuthError.appleSignInCanceled
        let sut = LoginViewModel(authManager: mockAuthManager,
                                 biometricService: mockBiometricService,
                                 appleSignInService: mockApple)
        sut.handleAppleCompletion(.failure(ASAuthorizationError(.canceled)))
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockAuthManager.signInWithAppleCallCount, 0)
    }
```

Add the same three tests to `SignupViewModelTests.swift` using a `SignupViewModel` init.

- [ ] **Step 7.2 — Run to verify they fail**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/LoginViewModelTests 2>&1 | grep -E "error:|FAIL|PASS|BUILD"
```

Expected: build error — `LoginViewModel` has no `appleSignInService` parameter.

- [ ] **Step 7.3 — Implement Apple methods in `LoginViewModel`**

1. Add `import AuthenticationServices` at the top.
2. Add stored property: `private let appleSignInService: any AppleSignInServiceProtocol`
3. Extend `init` with optional parameter (add before the existing `timeoutReason` parameter):
   `appleSignInService: (any AppleSignInServiceProtocol)? = nil,`
   And in the body: `self.appleSignInService = appleSignInService ?? AppleSignInService()`
4. Add methods at the bottom of the class:

```swift
    // MARK: - Apple Sign In

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appleSignInService.prepareRequest(request)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        do {
            let credential = try appleSignInService.credential(from: result)
            Task {
                do {
                    try await authManager.signInWithApple(credential: credential)
                } catch {
                    errorMessage = (error as? AuthError)?.errorDescription
                        ?? "Sign in with Apple failed. Please try again."
                }
            }
        } catch AuthError.appleSignInCanceled {
            // Silent — user tapped Cancel, no error shown
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription
                ?? "Sign in with Apple failed. Please try again."
        }
    }
```

Repeat the exact same changes for `SignupViewModel.swift`. The only difference: `SignupViewModel.init` may have different parameters — read the file first and add `appleSignInService` alongside the existing optional parameters.

- [ ] **Step 7.4 — Run to verify tests pass**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/LoginViewModelTests \
  -only-testing:TheRecruitingCompassTests/SignupViewModelTests 2>&1 | grep -E "error:|FAIL|PASS"
```

Expected: all PASS.

- [ ] **Step 7.5 — Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/SignupViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift \
  TheRecruitingCompass/TheRecruitingCompassTests/Features/Auth/ViewModels/SignupViewModelTests.swift
git commit -m "feat: add Apple sign-in methods to LoginViewModel and SignupViewModel"
```

---

### Task 8: LoginView + SignupView — Apple button

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/SignupView.swift`

- [ ] **Step 8.1 — Read both view files**

Read both files fully before editing:
- `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift`
- `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/SignupView.swift`

Locate the primary action button in each and the VStack that contains it.

- [ ] **Step 8.2 — Add Apple button to `LoginView`**

1. Add `import AuthenticationServices` at the top.
2. After the primary "Sign In" button, add:

```swift
HStack(spacing: 12) {
    Rectangle().frame(height: 0.5).foregroundStyle(Color.secondary.opacity(0.4))
    Text("or").font(.caption).foregroundStyle(.secondary)
    Rectangle().frame(height: 0.5).foregroundStyle(Color.secondary.opacity(0.4))
}
.accessibilityHidden(true)

SignInWithAppleButton(.signIn,
    onRequest: { viewModel.prepareAppleRequest($0) },
    onCompletion: { viewModel.handleAppleCompletion($0) }
)
.frame(height: 50)
.cornerRadius(10)
.accessibilityLabel("Sign in with Apple")
```

- [ ] **Step 8.3 — Add Apple button to `SignupView`**

Same pattern, use `.signUp` label:

```swift
SignInWithAppleButton(.signUp,
    onRequest: { viewModel.prepareAppleRequest($0) },
    onCompletion: { viewModel.handleAppleCompletion($0) }
)
.frame(height: 50)
.cornerRadius(10)
.accessibilityLabel("Sign up with Apple")
```

- [ ] **Step 8.4 — Build to verify**

```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8.5 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LoginView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/SignupView.swift
git commit -m "feat: add SignInWithAppleButton to LoginView and SignupView"
```

---

### Task 9: Entitlements + App Navigation

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass.entitlements`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`

- [ ] **Step 9.1 — Update entitlements file**

Read `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompass.entitlements` first (triple-nested path — both outer dirs share the same name).

Make two targeted edits — do NOT replace the whole file:

**Edit 1:** Add the `applesignin` key before the existing `associated-domains` key:
```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
```

**Edit 2:** Add `webcredentials:myrecruitingcompass.com` as a new entry inside the existing `associated-domains` array, keeping the two existing `applinks:` entries intact:
```xml
<string>webcredentials:myrecruitingcompass.com</string>
```

The final entitlements file should contain all three entries in `associated-domains` (two `applinks:` + one `webcredentials:`) plus the new `applesignin` key.

- [ ] **Step 9.2 — Enable capability in Xcode** *(manual — required for provisioning)*

Open `TheRecruitingCompass.xcodeproj` in Xcode → Target `TheRecruitingCompass` → **Signing & Capabilities** → `+` → search "Sign in with Apple" → double-click to add. This links the entitlement to the provisioning profile. Without this step the app will build but fail to sign for device.

- [ ] **Step 9.3 — Add `fullScreenCover` to `TheRecruitingCompassApp`**

Read `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift` first.

In `TheRecruitingCompassApp.swift`:

1. Add `@State private var appleSignInService = AppleSignInService()` after the existing `@State private var networkMonitor` line.

2. After the `.sheet(item: $pendingInvite) { ... }` modifier and before `.environment(authManager)`, add:

```swift
.fullScreenCover(
    isPresented: Binding(
        get: { authManager.needsAppleProfileSetup },
        set: { _ in }
    )
) {
    NavigationStack {
        AppleProfileSetupView()
    }
    .environment(authManager)
}
```

Note: `LoginViewModel` and `SignupViewModel` already default-construct their own `AppleSignInService()` in their `init`, so no additional injection is needed from the App level.

- [ ] **Step 9.4 — Build and run full test suite**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: all tests PASS, `BUILD SUCCEEDED`.

- [ ] **Step 9.5 — Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompass.entitlements \
        TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift
git commit -m "feat: add Sign in with Apple entitlement and profile setup navigation"
```

---

### Task 10: Manual Smoke Tests *(requires Apple Developer config from Task 0)*

Run these on a device or simulator with an Apple ID signed in. Requires Supabase Apple provider configured.

- [ ] New user: tap "Sign in with Apple" → Apple sheet appears → authenticate → role selection screen appears → select Parent → Continue → Dashboard ✓
- [ ] Returning user: tap "Sign in with Apple" → no role selection → Dashboard directly ✓
- [ ] Cancel: tap Apple button → Cancel on sheet → no error shown, stays on login screen ✓
- [ ] Cross-platform: sign in with Apple on iOS → open web app → sign in with Apple → same data visible ✓
- [ ] Email/password account same email: sign in with Apple → auto-linked → same account ✓
- [ ] Run full test suite one final time: `make test-unit` (or `make test`) — all green ✓

- [ ] **Final commit if any smoke-test fixes needed**

```bash
git add -A
git commit -m "fix: address smoke test issues from manual Apple sign-in testing"
```
