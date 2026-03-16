# Sign in with Apple — Cross-Platform Design Spec

**Date:** 2026-03-15
**Status:** Approved by user 2026-03-16
**Scope:** iOS (native) + Web (Nuxt 3)

---

## 1. Overview & Goals

### What We're Building
Native Sign in with Apple for the iOS app and OAuth-based Sign in with Apple for the web app, both backed by the shared Supabase project. A user who authenticates with Apple on either platform lands on the same Supabase user record.

### Goals
- Reduce friction at login/signup (no email/password required for Apple users)
- Offer a privacy-respecting sign-in option (Apple ID email, or private relay)
- Cross-platform account identity: one Apple ID = one Recruiting Compass account
- Apple App Store compliance (Sign in with Apple is required if any third-party social login is offered)

### Non-Goals
- Google, Facebook, or other OAuth providers (out of scope for this spec)
- Manual link-accounts confirmation UI (Supabase auto-link handles same-email merging)
- Migrating existing users to Apple sign-in (email/password continues to work; Apple is additive)

---

## 2. Current State

| Layer | Status |
|-------|--------|
| iOS auth | Email/password only via Supabase |
| Web auth | Email/password only via Supabase |
| Supabase Apple provider | Not configured |
| iOS entitlements | Universal links only — Sign in with Apple capability missing |
| `AuthenticationServices` import | Absent from all files |
| `AuthManaging` protocol | Extensible — add `signInWithApple()` |
| `SupabaseManaging` protocol | Extensible — add `signInWithApple(idToken:nonce:)` |
| `OnboardingManager` | Already handles post-auth role gates — Apple flow must integrate cleanly |

---

## 3. Architecture

### How Cross-Platform Identity Works

Both apps share one Supabase project. Supabase validates the Apple-issued JWT and uses the `sub` (subject) claim — Apple's stable, per-app user identifier — to find or create the Supabase auth user. This means:

- Same Apple ID on iOS and web → same `auth.users` row → same `public.users` row → same app data
- No manual identity-linking code required; Supabase handles it natively

### iOS Flow (Native)

```
User taps "Sign in with Apple"
    ↓
AppleSignInService generates random hex nonce
    ↓
SHA256-hashes nonce → sends hashed nonce to Apple with the request
    ↓
ASAuthorizationController presents Apple system sheet
    ↓
Apple returns: identityToken (JWT signed by Apple), name/email (first sign-in only)
    ↓
AuthManager.signInWithApple(credential) — @MainActor context
    ↓
SupabaseManager.signInWithApple(idToken:nonce:) → client.auth.signInWithIdToken(...)
    ↓
Supabase validates JWT, returns Session
    ↓
SupabaseManager.fetchUserProfileWithRetry(userId:email:fallbackMetadata:)
    → DB row found + has role → returning user (role is in public.users)
    → DB row missing OR no role in metadata → new Apple user
    ↓
Returning user:
  AuthManager sets user, session, isAuthenticated = true → Keychain save → Dashboard
New user:
  AuthManager sets session (not isAuthenticated) + needsAppleProfileSetup = true
  → AppleProfileSetupView (role selection)
  → completeAppleSignIn(role:) → upsert public.users → isAuthenticated = true → Dashboard
  → OnboardingManager.loadStatus() triggers as normal for the given role
```

**Why the nonce?** Prevents replay attacks. Apple embeds the SHA256-hashed nonce in the JWT; Supabase verifies it matches the raw nonce passed to `signInWithIdToken`.

### New User Detection

The existing `fetchUserProfileWithRetry` already has the right semantics:
- It checks `public.users` in the database first
- Falls back to `userMetadata` (checking for a `role` key)
- Returns `nil` if neither has a role

A new Apple user has no `public.users` row and no role in their `userMetadata` → `fetchUserProfileWithRetry` returns `nil` → `isNewUser = true`. This is a reliable signal that does not false-positive on a returning user whose DB row temporarily failed to load (that user would have metadata with their role from signup).

### OnboardingManager Integration

`OnboardingManager.loadStatus()` runs when `isAuthenticated` becomes `true`. The Apple flow delays setting `isAuthenticated = true` until after role selection — so `OnboardingManager` is not triggered until the new user has a role. This means:

- **New Apple user** → `AppleProfileSetupView` first → selects role → `completeAppleSignIn(role:)` sets `isAuthenticated = true` → `OnboardingManager.loadStatus()` fires with `user.role` populated → normal onboarding gate per role
- **Returning Apple user** → normal auth path → `OnboardingManager.loadStatus()` fires immediately (role already in DB)

There is no conflict with `OnboardingWrapperView` because Apple profile setup is gated on `needsAppleProfileSetup`, not `needsOnboarding`. By the time `needsOnboarding` is evaluated, the role is set.

### Web Flow (OAuth PKCE)

```
User clicks "Sign in with Apple"
    ↓
supabase.auth.signInWithOAuth({ provider: 'apple', options: { redirectTo: '/auth/callback' } })
    ↓
Browser redirects → Apple OAuth → user authenticates
    ↓
Apple redirects to: https://myrecruitingcompass.com/auth/callback?code=...
    ↓
@nuxtjs/supabase handles code exchange automatically via its confirmRoute (/auth/callback by default)
Session stored in cookie
    ↓
Middleware or callback handler checks user.user_metadata.role
    → role present → redirect to /dashboard
    → role absent → redirect to /auth/apple-setup (new user role selection)
```

### Account Linking Strategy

**Decision: Supabase Automatic Identity Linking (enabled in dashboard)**

When a user signs in with Apple but already has a Supabase account with the same email:
- Supabase detects the email match and links the Apple identity to the existing account automatically
- User lands in their existing account — no prompt, no friction

**Apple "Hide My Email" caveat:** If the user chose Apple's private relay address, that relay address won't match their existing real-email account. Auto-linking won't fire; they get a separate account. Mitigation: show an informational note on first Apple login stating that if they previously used email/password with a different address, their accounts may appear separate.

---

## 4. Apple Developer Configuration (Prerequisites)

One-time setup before any code can be tested end-to-end.

### Apple Developer Portal

**For iOS (App ID):**
- Enable "Sign in with Apple" capability on app ID `com.theRecruitingCompass.app`

**For Web (Service ID):**
- Create a Service ID: e.g. `com.theRecruitingCompass.web`
- Enable "Sign in with Apple" on the Service ID
- Add authorized return URL: `https://xpxzhqghxecsjhvklsqg.supabase.co/auth/v1/callback`

**Generate a Private Key:**
- New key with "Sign in with Apple" enabled
- Download the `.p8` file (one-time — store securely)
- Note the Key ID and your Team ID

### Supabase Dashboard

**Authentication → Providers → Apple:**

| Field | Value |
|-------|-------|
| Enabled | On |
| Client ID (Service ID) | `com.theRecruitingCompass.web` |
| Secret Key | Contents of `.p8` file |
| Key ID | From Apple Developer Portal |
| Team ID | Your Apple Developer Team ID |

**Authentication → Settings:**
- Enable "Allow automatic linking for same-email accounts"

---

## 5. iOS Implementation

### 5.1 Entitlements

Add Sign in with Apple capability to `TheRecruitingCompass.entitlements`:

```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:myrecruitingcompass.com</string>
  <string>applinks:www.myrecruitingcompass.com</string>
  <string>webcredentials:myrecruitingcompass.com</string>
</array>
```

The `webcredentials` entry is required for cross-platform Apple credential association.

### 5.2 New File: `AppleSignInService.swift`

Location: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AppleSignInService.swift`

**Responsibility:** Manages nonce state and parses the Apple credential result. Works with `SignInWithAppleButton`'s `onRequest`/`onCompletion` callbacks. No Supabase knowledge; no UI state; no `ASAuthorizationController` (the system button handles that).

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
    let nonce: String              // raw (unhashed) nonce for Supabase
    let fullName: PersonNameComponents?  // non-nil only on first sign-in
    let email: String?             // non-nil only on first sign-in
}

@MainActor
final class AppleSignInService: AppleSignInServiceProtocol {

    private var pendingNonce: String?

    nonisolated deinit {}  // required — macOS 26.x @MainActor deinit crash prevention

    /// Called from `SignInWithAppleButton.onRequest`. Generates a nonce and stamps it onto the request.
    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        pendingNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    /// Called from `SignInWithAppleButton.onCompletion`. Parses the system-provided result.
    /// Throws `AuthError.appleSignInCanceled` for user-initiated cancels (caller should handle silently).
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

    // MARK: - Nonce Helpers

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { byte in
                if remainingLength == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

**Key design notes:**
- `SignInWithAppleButton` (not `ASAuthorizationController`) presents the Apple sheet. This avoids a common double-trigger bug where calling `performRequests()` inside `onCompletion` fires a second sheet.
- `prepareRequest` is called by `onRequest` before the sheet appears — the nonce is stamped into the request at that moment.
- `credential(from:)` is called by `onCompletion` after the sheet completes — the service parses and returns the `AppleCredential` value, or throws on cancel/error.
- `@MainActor` ensures nonce state is accessed on the main actor (both callbacks arrive on the main thread in practice, but the annotation makes it explicit and safe).
- `nonisolated deinit {}` required per project-wide macOS 26.x rule for all `@MainActor` classes.

### 5.3 Protocol Changes

**`AuthManaging.swift`** — add the following. The protocol is already declared `@MainActor` at the protocol level, so per-method `@MainActor` annotations are redundant but acceptable:

```swift
// New observable properties — must be declared as { get } requirements so
// MockAuthManager exposes them through the protocol type. Without this,
// TheRecruitingCompassApp.swift's binding to authManager.needsAppleProfileSetup
// won't compile when authManager is typed as `any AuthManaging`.
var needsAppleProfileSetup: Bool { get }
var pendingAppleName: PersonNameComponents? { get }

// New methods
func signInWithApple(credential: AppleCredential) async throws
func completeAppleSignIn(role: UserRole, fullName: String?) async throws
```

**`SupabaseManaging.swift`** — add:

```swift
func signInWithApple(
    idToken: String,
    nonce: String
) async throws -> (session: Session, user: User?, isNewUser: Bool)
```

### 5.4 `AuthManager.swift` Changes

Inject `AppleSignInService` alongside `supabaseManager`. Add two new observable properties and two new methods. Both new properties are plain `var` — this codebase uses `@Observable`, not `ObservableObject`:

```swift
var needsAppleProfileSetup = false
var pendingAppleName: PersonNameComponents? = nil

// In init, add appleSignInService parameter:
// init(supabaseManager: ..., biometricService: ..., appleSignInService: (any AppleSignInServiceProtocol)? = nil) {
//     self.appleSignInService = appleSignInService ?? AppleSignInService()

// `signInWithApple(credential:)` is called by the ViewModel after AppleSignInService parses the result.
// The cancel case is handled at the View level — this method never sees `appleSignInCanceled`.
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
            // Apple only provides name on the very first sign-in — cache immediately
            self.pendingAppleName = credential.fullName
            self.needsAppleProfileSetup = true
            // isAuthenticated stays false until profile setup completes
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
        self.errorMessage = (error as? AuthError)?.errorDescription ?? "Sign in with Apple failed. Please try again."
        logger.error("Apple sign-in failed: \(error.localizedDescription)")
        throw error
    }
}

func completeAppleSignIn(role: UserRole, fullName: String?) async throws {
    guard let session = session else {
        throw AuthError.serverError("No pending Apple session")
    }
    logger.debug("Completing Apple sign-in for role: \(role.rawValue)")
    do {
        let user = try await supabaseManager.createAppleUser(
            userId: session.user.id,
            email: session.user.email,
            fullName: fullName,
            role: role
        )
        self.user = user
        self.isAuthenticated = true
        self.needsAppleProfileSetup = false
        self.pendingAppleName = nil
        try keychain.save(session, forKey: sessionKey)
        logger.info("Apple profile setup complete for user: \(user.id, privacy: .private)")
    } catch {
        self.errorMessage = (error as? AuthError)?.errorDescription ?? "Profile setup failed. Please try again."
        logger.error("Apple profile setup failed: \(error.localizedDescription)")
        throw error
    }
}
```

### 5.5 `SupabaseManager.swift` Changes

**Add `signInWithApple`:**

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
        // New user: create a placeholder session with minimal user info
        // (no role yet — role set in completeAppleSignIn)
        let placeholderUser = User(
            id: userId,
            email: email,
            emailConfirmedAt: nil,
            phone: nil,
            fullName: nil,
            createdAt: Self.isoFormatter.string(from: Date.now),
            updatedAt: Self.isoFormatter.string(from: Date.now),
            role: nil
        )
        session = mapToSession(authSession, user: placeholderUser)
    }

    return (session, user, isNewUser)
}
```

**Add `createAppleUser`:**

```swift
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
    let displayName = resolvedName.isEmpty ? nil : resolvedName

    // Upsert into public.users and update Apple user_metadata with role
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

    // Store role in user_metadata so future sign-ins via fetchUserProfileWithRetry
    // fallback can detect returning users correctly
    try await client.auth.update(user: .init(data: [
        "role": .string(role.rawValue),
        "full_name": .string(displayName ?? "")
    ]))

    return User(
        id: userId,
        email: email,
        emailConfirmedAt: nil,
        phone: nil,
        fullName: displayName,
        createdAt: Self.isoFormatter.string(from: Date.now),
        updatedAt: Self.isoFormatter.string(from: Date.now),
        role: role
    )
}
```

**Add `SupabaseManaging` protocol entries:**

```swift
func signInWithApple(idToken: String, nonce: String) async throws -> (session: Session, user: User?, isNewUser: Bool)
func createAppleUser(userId: String, email: String, fullName: PersonNameComponents?, role: UserRole) async throws -> User
```

**Note on `UsersUpsertPayload`:** This struct is already defined as `private struct UsersUpsertPayload` inside `SupabaseManager`. Since `createAppleUser` lives in the same file, it can reuse it directly — no new struct needed.

**Note on `User` initializer:** The `User` struct has `dateOfBirth: String? = nil` and `profilePhotoUrl: String? = nil` as defaulted parameters. The placeholder and returned `User` instances in this spec omit them intentionally; they default to `nil`.

### 5.6 `AuthError.swift` Changes

Add one new case (no-op cancel, no user-visible message):

```swift
case appleSignInCanceled
```

In the `errorDescription` switch **and** the `recoverySuggestion` switch (both are exhaustive and will produce a compile error if the new case is omitted from either), add:

```swift
case .appleSignInCanceled:
    return nil  // silent — View handles cancel without showing an error banner
```

This case is never displayed to the user — it exists only so `AppleSignInService.credential(from:)` can throw a typed error that callers can pattern-match.

### 5.7 `MockAuthManager.swift` (Tests)

Add stubs matching the new protocol requirements. `MockAuthManager` must also declare the new properties since they are now protocol requirements:

```swift
// Protocol property requirements
var needsAppleProfileSetup = false
var pendingAppleName: PersonNameComponents? = nil

// Tracking flags
var signInWithAppleCalled = false
var completeAppleSignInCalled = false
var lastAppleCredential: AppleCredential? = nil

func signInWithApple(credential: AppleCredential) async throws {
    signInWithAppleCalled = true
    lastAppleCredential = credential
    if shouldThrow { throw mockError }
    isAuthenticated = true  // or set needsAppleProfileSetup for new-user path tests
}

func completeAppleSignIn(role: UserRole, fullName: String?) async throws {
    completeAppleSignInCalled = true
    if shouldThrow { throw mockError }
    let now = ISO8601DateFormatter().string(from: Date.now)
    user = User(id: "apple-user", email: "test@appleid.com",
                emailConfirmedAt: nil, phone: nil, fullName: fullName,
                createdAt: now, updatedAt: now, role: role)
    isAuthenticated = true
    needsAppleProfileSetup = false
}
```

### 5.8 UI Changes

#### `LoginViewModel.swift` and `SignupViewModel.swift`

Both ViewModels hold a reference to an `AppleSignInService` (injected alongside `AuthManager`). They expose two methods that the View calls from `SignInWithAppleButton` callbacks:

```swift
private let appleSignInService: any AppleSignInServiceProtocol

func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
    appleSignInService.prepareRequest(request)
}

func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
    do {
        let credential = try appleSignInService.credential(from: result)
        Task {
            try await authManager.signInWithApple(credential: credential)
        }
    } catch AuthError.appleSignInCanceled {
        // Silent — user tapped cancel on the Apple sheet. No error shown.
    } catch {
        errorMessage = (error as? AuthError)?.errorDescription ?? "Sign in with Apple failed."
    }
}
```

#### `LoginView.swift` and `SignupView.swift`

`SignInWithAppleButton` is a native SwiftUI view available via `import AuthenticationServices` (iOS 14+, no `UIViewRepresentable` wrapper needed). Add it below the existing primary button, separated by an "or" divider.

The button's `onRequest` stamps the nonce onto the Apple request; `onCompletion` delivers the result to the ViewModel. The system button handles presenting the Apple authentication sheet — there is no second `ASAuthorizationController` call.

```swift
import AuthenticationServices

// Inside the form VStack, after the primary Sign In / Create Account button:

HStack {
    Rectangle().frame(height: 0.5).foregroundColor(.secondary)
    Text("or").font(.caption).foregroundColor(.secondary)
    Rectangle().frame(height: 0.5).foregroundColor(.secondary)
}
.padding(.vertical, 8)

SignInWithAppleButton(.signIn,   // use .signUp on SignupView
    onRequest: { request in
        viewModel.prepareAppleRequest(request)
    },
    onCompletion: { result in
        viewModel.handleAppleCompletion(result)
    }
)
.frame(height: 44)
.signInWithAppleButtonStyle(.whiteOutline)  // adjust to match background
```

The button type (`.signIn` / `.signUp`) changes the button label. Apple requires the system button — do not substitute a custom button with Apple branding.

### 5.9 New File: `AppleProfileSetupView.swift`

Location: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/AppleProfileSetupView.swift`

Shown when `authManager.needsAppleProfileSetup == true`. This is a modal presented from `TheRecruitingCompassApp.swift` watching that flag. When dismissed (via cancel or completion), sets `needsAppleProfileSetup = false`.

**Contents:**
- Welcome text (uses `authManager.pendingAppleName` if available)
- Role selection cards: Parent / Coach (same visual pattern as `SignupView`)
  - **No family code field** — family code is not required at signup for any role
- "Continue" button → calls `authManager.completeAppleSignIn(role: selectedRole, fullName: resolvedName)`
- Error display if setup fails

**`AppleProfileSetupViewModel.swift`** (if needed) must be:
```swift
@Observable
@MainActor
final class AppleProfileSetupViewModel {
    // ...
    nonisolated deinit {}  // required — macOS 26.x @MainActor deinit crash prevention
}
```

### 5.10 `TheRecruitingCompassApp.swift` Navigation

When `needsAppleProfileSetup == true`, `isAuthenticated` is still `false`, so the `else { NavigationStack { LandingView() } }` branch is active. The `.fullScreenCover` must be applied to the root `Group` (same level as the existing `.sheet` modifiers) so it fires regardless of which branch is showing.

Add after `.sheet(item: $pendingInvite)` and before `.environment(authManager)`:

```swift
// In TheRecruitingCompassApp, add this @State property:
// @State private var appleSignInService = AppleSignInService()

// After .sheet(item: $pendingInvite) { ... }:
.fullScreenCover(isPresented: Binding(
    get: { authManager.needsAppleProfileSetup },
    set: { if !$0 { authManager.needsAppleProfileSetup = false } }
)) {
    NavigationStack {
        AppleProfileSetupView()
    }
    .environment(authManager)
}
```

Use `.fullScreenCover` (not `.sheet`) to prevent swipe-to-dismiss, which would leave a new user stuck with a half-created Apple account and no way to reach the dashboard.

`appleSignInService` should also be injected into the environment or passed to ViewModels at the point where `LoginView` and `SignupView` are initialized in `LandingView`.

---

## 6. Web Implementation (Nuxt 3)

### 6.0 Web Auth Context

The web app uses a **raw Supabase JS client** (not `@nuxtjs/supabase` module). Key facts:
- Client configured in `composables/useSupabase.ts` with `detectSessionInUrl: true`
- Session stored in `localStorage` via Supabase client auto-storage
- Auth state synced to Pinia store via `plugins/auth.client.ts` (listens for `SIGNED_IN` / `SIGNED_OUT` events)
- Page structure is flat: `pages/login.vue`, `pages/signup.vue` — no `/auth/` prefix convention
- No `@nuxtjs/supabase` confirm route in use — `detectSessionInUrl: true` handles URL-based session detection

### 6.1 Sign In with Apple Button

Add a Sign In with Apple button to both `components/Auth/LoginForm.vue` and `components/Auth/SignupForm.vue`. Use the official Apple button markup (black background, white logo+text, min 44px height per HIG).

Add a `signInWithApple()` function to `composables/useAuth.ts` alongside the existing `login()` and `signup()` methods:

```typescript
async function signInWithApple() {
    const supabase = useSupabaseClient()
    const { error } = await supabase.auth.signInWithOAuth({
        provider: 'apple',
        options: {
            redirectTo: `${window.location.origin}/apple-callback`,
            scopes: 'name email',
        }
    })
    if (error) throw error
    // Browser redirects to Apple — no further code runs here
}
```

### 6.2 Auth Callback Page (`/apple-callback`)

Create `pages/apple-callback.vue`. The app uses `detectSessionInUrl: true`, so Supabase automatically exchanges the code for a session when this page loads — no manual `exchangeCodeForSession` call needed.

The page's `onMounted` logic:

```typescript
// pages/apple-callback.vue
onMounted(async () => {
    // detectSessionInUrl handles the code exchange automatically.
    // Wait for the SIGNED_IN event via the auth plugin, then check user state.
    await waitForSession()  // polls userStore.isAuthenticated or listens to supabase.auth.onAuthStateChange

    const user = userStore.user
    if (!user?.role) {
        // New Apple user — no role yet
        await navigateTo('/apple-setup')
    } else {
        await navigateTo('/dashboard')
    }
})
```

The page shows a loading spinner while the exchange completes. Handle error state if no session is established within a timeout.

**Set the callback URL in Supabase Dashboard:** Authentication → URL Configuration → Add `https://myrecruitingcompass.com/apple-callback` to the Redirect URLs allowlist.

### 6.3 New User Role Selection (`/apple-setup`)

Create `pages/apple-setup.vue`. Shown only for new Apple users who have no role in their profile.

**Contents:**
- Role selection: Parent / Coach (match the `UserTypeSelector.vue` pattern from signup)
- "Continue" button → calls `supabase.auth.updateUser({ data: { role, full_name } })` + upserts into `public.users`
- Then navigates to `/dashboard`

**Guard:** Add a route check — if the user already has a role, redirect to `/dashboard` immediately (prevents direct URL access).

### 6.4 Apple Domain Verification

Apple requires a publicly accessible verification file at:

```
https://myrecruitingcompass.com/.well-known/apple-developer-domain-association.txt
```

Place this file in the Nuxt `public/.well-known/` directory. Content is generated in Apple Developer Portal when configuring the Service ID. Must be served as plain text (no auth, no redirects).

---

## 7. Error Handling

| Scenario | iOS Behavior | Web Behavior |
|----------|-------------|--------------|
| User cancels Apple sheet | Silent — no error, stays on login screen (`appleSignInCanceled` case) | N/A |
| Apple servers unreachable | Show "Sign in with Apple failed. Please try again." banner | Toast error |
| Supabase rejects token | Show "Sign in with Apple failed. Please try again." banner | Error on callback page |
| Same email auto-linked | Transparent — user lands in their existing account | Transparent |
| Hide My Email (separate account) | Informational note on first Apple login | Same |
| Profile setup fails (new user) | Error in `AppleProfileSetupView`, retry available | Error on `/auth/apple-setup`, retry available |

**Note:** Supabase does not return a distinct error code for "Apple ID already linked to a different account" — this surfaces as a generic auth error. Do not display a specific message for this case; the generic retry message is appropriate.

---

## 8. Testing Strategy

### Unit Tests (iOS)

**`AppleSignInServiceTests.swift`**
- Nonce generation: verify 32-char hex string, uniqueness across calls
- SHA256: verify known input → expected hash output
- Credential parsing: inject mock `ASAuthorizationAppleIDCredential`, verify `AppleCredential` fields
- Cancel path: inject `ASAuthorizationError.canceled`, verify `appleSignInCanceled` thrown

**`AuthManagerAppleTests.swift`**
- Inject `MockAppleSignInService` + `MockSupabaseManager`
- New user path: verify `needsAppleProfileSetup = true`, `isAuthenticated = false`
- Returning user path: verify `isAuthenticated = true`, `user` set, Keychain saved
- `completeAppleSignIn`: verify `isAuthenticated = true`, `needsAppleProfileSetup = false`
- Cancel path: verify no error shown, state unchanged

**`SupabaseManagerAppleTests.swift`**
- Mock Supabase client, verify `signInWithIdToken` called with correct credentials
- New user (nil DB row): verify `isNewUser = true`, placeholder session returned
- Returning user (DB row exists): verify `isNewUser = false`, user returned

**`MockAuthManager.swift`**
- `signInWithAppleCalled` + `completeAppleSignInCalled` flags for use in ViewModel tests

### Integration Tests (iOS)

**`AppleSignInIntegrationTests.swift`**
- End-to-end with `MockAppleSignInService` + `MockSupabaseManager`
- New user flow: Apple credential → needsAppleProfileSetup → completeAppleSignIn → isAuthenticated
- Returning user flow: Apple credential → isAuthenticated directly

### UI Tests (iOS)

**`AuthAppleUITests.swift`**
- `SignInWithAppleButton` visible on `LoginView`
- `SignInWithAppleButton` visible on `SignupView`
- `AppleProfileSetupView` shows role selection options
- Note: Apple's system authentication sheet cannot be automated in XCTest

### Web Tests (Nuxt/Vitest)

- Auth composable: mock `supabase.auth.signInWithOAuth`, verify called with `provider: 'apple'`
- `/auth/apple-setup`: verify role selection updates `user_metadata` and redirects

### Manual Test Scenarios

1. **New iOS user**: Tap Apple sign-in → Apple sheet → select role → land on dashboard
2. **New web user**: Click Apple button → Apple OAuth → select role → land on dashboard
3. **Returning iOS user**: Apple sign-in → land directly on dashboard (no role prompt)
4. **Cross-platform continuity**: Sign in with Apple on iOS → open web app → sign in with Apple → same data visible
5. **Email/password account + same Apple ID email**: Sign in with Apple → auto-linked, same account and data
6. **Cancel on Apple sheet**: No error shown, stays on login screen
7. **Hide My Email selected**: New separate account created — informational note displayed

---

## 9. `nonisolated deinit` Requirement

Per project memory: all `@MainActor` classes must include `nonisolated deinit {}` to prevent a macOS 26.x test crash in `swift_task_deinitOnExecutorMainActorBackDeploy`.

New types requiring this:
- `AppleSignInService` — `@MainActor final class`
- `AppleProfileSetupViewModel` — `@Observable @MainActor final class`

`AppleCredential` is a `struct` — no deinit required.
`AuthManager` already handles this if existing. Verify when adding new properties.

---

## 10. Out of Scope

- Google, Facebook, or any other OAuth provider
- Manual "link accounts" confirmation flow
- Biometric fallback for returning Apple users (existing biometric flow handles this post-first-sign-in)
- Player role in Apple profile setup — spec uses Parent / Coach matching signup (Player role is for athletes invited into a family, not self-signup)

---

## 11. Resolved Questions

All open questions answered 2026-03-16:

1. **Implementation order:** Web auth already exists — this adds Apple to both iOS and web simultaneously.
2. **Apple Developer Portal:** Access confirmed.
3. **Supabase dashboard:** Access confirmed.
4. **Web auth callback:** App uses raw Supabase client with `detectSessionInUrl: true` (not `@nuxtjs/supabase` module). Requires a custom `/apple-callback` page — see Section 6.2.
5. **`AppleProfileSetupView`:** Full-screen cover confirmed.
