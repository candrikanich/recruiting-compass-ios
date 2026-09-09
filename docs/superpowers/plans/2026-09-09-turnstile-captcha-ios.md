# iOS Turnstile Captcha Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iOS `login`, `signup`, and `resetPasswordForEmail` all pass a valid Cloudflare Turnstile `captchaToken` to Supabase Auth, so the app stops failing with `"captcha protection: request disallowed (no captcha_token found)"`.

**Architecture:** A singleton `TurnstileTokenProvider` owns one hidden `WKWebView` (mounted once in the app's view hierarchy so it stays attached to a live window, which Turnstile's bot-detection requires) running an invisible-mode Turnstile widget. Each auth call site (`LoginViewModel`, `SignupViewModel`, `ForgotPasswordViewModel`) fetches a fresh single-use token from it immediately before calling `AuthManager`, which threads `captchaToken` straight through `SupabaseManager` into the supabase-swift SDK's existing (currently unused) `captchaToken` parameter on `signIn`/`signUp`/`resetPasswordForEmail`.

**Tech Stack:** Swift, SwiftUI, WebKit (`WKWebView`/`WKScriptMessageHandler` — first use in this app), supabase-swift 2.41.1, Cloudflare Turnstile JS API, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-09-turnstile-captcha-ios-design.md`

## Global Constraints

- Site key `0x4AAAAAAEc9xAHjjO-Jv5pg` is the same public key web's signup already uses — Turnstile site keys are not secret, safe to commit (same trust class as the already-committed `PostHogConfigEmbedded.swift` API key).
- Widget UX is invisible/managed (`size: 'invisible'`) — no visible checkbox in the normal path.
- `captchaToken` is a **required, non-optional `String`** on `AuthManaging`/`SupabaseManaging` — callers always fetch a real token before calling; the SDK's own parameter is optional (`String? = nil`) but we always supply a value.
- Tokens are single-use with a ~5 minute TTL — `TurnstileTokenProvider.getToken()` never caches; every call triggers a fresh reset+execute.
- Every new/modified `@MainActor` class needs `nonisolated deinit {}` (macOS 26.x test-teardown double-free rule — see project `CLAUDE.md`).
- TDD: failing test → implement → passing test → commit, per task, wherever the layer is unit-testable. `TurnstileWidgetView`/`TurnstileTokenProvider`'s live Cloudflare interaction is not unit-testable (real network + real JS challenge) — its acceptance bar is the manual simulator spike in Task 2, matching the spec's Testing section.
- Config flows through `Release.xcconfig` → the existing "Generate Supabase config" build-phase pipeline, mirroring the `POSTHOG_API_KEY` precedent exactly.
- The Cloudflare Turnstile `<script>` tag in Task 2's HTML deliberately has no `integrity`/`crossorigin` SRI attributes — Cloudflare documents that Turnstile's script content rotates and is incompatible with SRI pinning; adding a hash would break the widget. This is a deliberate exception to the general SRI rule, not an oversight.

---

### Task 1: Config plumbing — `TURNSTILE_SITE_KEY`

**Files:**
- Modify: `TheRecruitingCompass.xcodeproj/project.pbxproj` (the `shellScript` string of the `98B3C4D22F3A5101009C60F5 /* Generate Supabase config */` `PBXShellScriptBuildPhase`, and its `outputPaths` array)
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift` (committed default, overwritten by the build phase — same status as `PostHogConfigEmbedded.swift`)

**Interfaces:**
- Produces: `TurnstileConfigEmbedded.siteKey: String`, consumed by Task 2's `TurnstileTokenProvider`.

- [ ] **Step 1: Add the committed default generated file**

Create `TheRecruitingCompass/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift`:

```swift
import Foundation

/// Auto-generated at build time from Release.xcconfig. Do not edit manually.
enum TurnstileConfigEmbedded {
  static let siteKey = "0x4AAAAAAEc9xAHjjO-Jv5pg"
}
```

- [ ] **Step 2: Add the build-phase script block**

In `TheRecruitingCompass.xcodeproj/project.pbxproj`, find the `98B3C4D22F3A5101009C60F5 /* Generate Supabase config */` build phase. Its `outputPaths` array currently reads:

```
outputPaths = (
    "$(SRCROOT)/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift",
    "$(SRCROOT)/TheRecruitingCompass/Core/Services/PostHogConfigEmbedded.swift",
);
```

Add a third line:

```
outputPaths = (
    "$(SRCROOT)/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift",
    "$(SRCROOT)/TheRecruitingCompass/Core/Services/PostHogConfigEmbedded.swift",
    "$(SRCROOT)/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift",
);
```

Then extend the `shellScript` value. The current unescaped script ends with:

```bash
# PostHog embedded config
PH_OUT="${SRCROOT}/TheRecruitingCompass/Core/Services/PostHogConfigEmbedded.swift"
PH_KEY_ESC=$(printf '%s' "${POSTHOG_API_KEY:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf 'import Foundation\n\n/// Auto-generated at build time from Release.xcconfig. Do not edit manually.\nenum PostHogConfigEmbedded {\n  static let apiKey = "%s"\n}\n' "$PH_KEY_ESC" > "$PH_OUT"
echo "Generated PostHog config: key length=${#POSTHOG_API_KEY}"
```

Append this block (same style, same escaping pattern). Note the `:-0x4AAAAAAEc9xAHjjO-Jv5pg` default — since the key is public, an unset local `Release.xcconfig` var falls back to the real value instead of emitting an empty string:

```bash
# Turnstile embedded config
TW_OUT="${SRCROOT}/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift"
TW_KEY_ESC=$(printf '%s' "${TURNSTILE_SITE_KEY:-0x4AAAAAAEc9xAHjjO-Jv5pg}" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf 'import Foundation\n\n/// Auto-generated at build time from Release.xcconfig. Do not edit manually.\nenum TurnstileConfigEmbedded {\n  static let siteKey = "%s"\n}\n' "$TW_KEY_ESC" > "$TW_OUT"
echo "Generated Turnstile config: key length=${#TURNSTILE_SITE_KEY}"
```

Since `project.pbxproj` stores `shellScript` as one escaped string on a single line, insert this as additional `\n`-joined, backslash/quote-escaped content immediately after the existing PostHog `echo` line and before the closing `";`. Follow the exact escaping already present for the PostHog block (each literal `\n` → `\\n`, each `"` inside the printf format string → `\"`, each `$` that must reach the shell unescaped stays as `$`).

- [ ] **Step 3: Verify the build**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```
Expected: `BUILD SUCCEEDED`, and `Core/Services/TurnstileConfig.generated.swift` now contains the real site key (build phase ran and overwrote the committed default — confirm via `cat` if `TURNSTILE_SITE_KEY` isn't set locally, it still resolves to `0x4AAAAAAEc9xAHjjO-Jv5pg` via the script's own default).

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass.xcodeproj/project.pbxproj TheRecruitingCompass/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift
git commit -m "chore(config): add TURNSTILE_SITE_KEY to generated-config build phase"
```

---

### Task 2: `TurnstileTokenProviding` protocol, `TurnstileWidgetView`, `TurnstileTokenProvider` (spike)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/Turnstile/TurnstileTokenProviding.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/Turnstile/TurnstileWidgetView.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/Turnstile/TurnstileTokenProvider.swift`
- Create: `TheRecruitingCompassTests/Mocks/MockTurnstileTokenProvider.swift`
- Modify (temporary, removed in Task 9's cleanup step — see note below): `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/Views/LandingView.swift` (add a `.task` that prints a fetched token, for manual spike verification only)

**Interfaces:**
- Consumes: `AuthError.captchaFailed` (added in Task 3 — this task can use a placeholder `AuthError.serverError("captcha failed")` throw and Task 3 will replace it, OR do Task 3 first. **Do Task 3 before this task's Step 4** so `AuthError.captchaFailed` already exists when `TurnstileTokenProvider` is written; the task order below reflects doing Task 3 first in execution even though it's numbered later — reorder Task 3 ahead of Task 2 when executing, or read Task 3 now and use its result. To keep this plan's numbering stable, Task 3 is written next but must run **before** Task 2 Step 4.)
- Produces: `protocol TurnstileTokenProviding { func getToken() async throws -> String }`, `final class TurnstileTokenProvider: NSObject, TurnstileTokenProviding` with `static let shared`, consumed by Tasks 6–8.

> **Execution order note:** Run Task 3 (AuthError case) before this task's Step 4, so the real `AuthError.captchaFailed` exists. Tasks are numbered for readability, not strict sequence, on this one dependency.

- [ ] **Step 1: `TurnstileTokenProviding` protocol**

Create `Core/Services/Turnstile/TurnstileTokenProviding.swift`:

```swift
import Foundation

/// Supplies single-use Cloudflare Turnstile tokens for Supabase Auth calls that require
/// captcha verification (login, signup, password reset). Conform for testability.
@MainActor
protocol TurnstileTokenProviding: AnyObject {
  /// Executes a fresh Turnstile challenge and returns its token. Never caches or reuses
  /// a token across calls — each Supabase auth call needs its own, tokens are single-use.
  func getToken() async throws -> String
}
```

- [ ] **Step 2: `MockTurnstileTokenProvider` test double**

Create `TheRecruitingCompassTests/Mocks/MockTurnstileTokenProvider.swift`:

```swift
import Foundation
@testable import TheRecruitingCompass

@MainActor
final class MockTurnstileTokenProvider: TurnstileTokenProviding {
  var tokenToReturn = "mock-turnstile-token"
  var shouldThrowError = false
  var errorToThrow: Error = AuthError.captchaFailed
  var getTokenCallCount = 0

  func getToken() async throws -> String {
    getTokenCallCount += 1
    if shouldThrowError { throw errorToThrow }
    return tokenToReturn
  }
}
```

- [ ] **Step 3: `TurnstileWidgetView`**

Create `Core/Services/Turnstile/TurnstileWidgetView.swift`:

```swift
import SwiftUI
import WebKit

/// Hosts the shared, hidden WKWebView that runs the Cloudflare Turnstile challenge.
/// Mount exactly once (see `TheRecruitingCompassApp`) so the web view stays attached
/// to a live window — Turnstile's bot-detection heuristics require that; a WKWebView
/// never added to any window's hierarchy can be flagged as headless/suspicious.
struct TurnstileWidgetView: UIViewRepresentable {
  func makeUIView(context: Context) -> WKWebView {
    TurnstileTokenProvider.shared.webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}
}
```

- [ ] **Step 4: `TurnstileTokenProvider`**

Create `Core/Services/Turnstile/TurnstileTokenProvider.swift`:

```swift
import Foundation
import WebKit
import Observation

/// Owns the single WKWebView that runs an invisible Cloudflare Turnstile widget and
/// bridges its JS callbacks back to Swift. One shared instance backs every auth flow
/// that needs a captcha token (login, signup, password reset).
///
/// The page is loaded via `loadHTMLString(_:baseURL:)` with `baseURL` set to the prod
/// web domain so `document.location.hostname` resolves to a hostname already
/// allow-listed for this site key in the Cloudflare Turnstile dashboard (the HTML
/// content itself is still local, never fetched over the network).
@MainActor
@Observable
final class TurnstileTokenProvider: NSObject, TurnstileTokenProviding {
  nonisolated deinit {}

  static let shared = TurnstileTokenProvider()

  /// The WKWebView `TurnstileWidgetView` mounts. Created once, lives for the app's lifetime.
  let webView: WKWebView

  @ObservationIgnored private var isWidgetReady = false
  @ObservationIgnored private var pendingContinuation: CheckedContinuation<String, Error>?
  @ObservationIgnored private var readyContinuations: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var hasRetriedAfterExpiry = false

  private override init() {
    let configuration = WKWebViewConfiguration()
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()
    configuration.userContentController.add(self, name: "turnstile")
    webView.loadHTMLString(Self.html, baseURL: URL(string: "https://myrecruitingcompass.com"))
  }

  func getToken() async throws -> String {
    hasRetriedAfterExpiry = false
    await waitUntilReady()
    return try await executeChallenge()
  }

  private func waitUntilReady() async {
    if isWidgetReady { return }
    await withCheckedContinuation { continuation in
      readyContinuations.append(continuation)
    }
  }

  private func executeChallenge() async throws -> String {
    webView.evaluateJavaScript("window.twReset(); window.twExecute();")
    do {
      return try await withThrowingTaskGroup(of: String.self) { group in
        group.addTask { [weak self] in
          try await withCheckedThrowingContinuation { continuation in
            self?.pendingContinuation = continuation
          }
        }
        group.addTask {
          try await Task.sleep(for: .seconds(10))
          throw AuthError.captchaFailed
        }
        defer { group.cancelAll() }
        return try await group.next()!
      }
    } catch {
      // The losing task's continuation (if any) is still unresumed at this point —
      // resume it so it doesn't leak, then propagate the original error.
      pendingContinuation?.resume(throwing: AuthError.captchaFailed)
      pendingContinuation = nil
      throw error
    }
  }

  fileprivate func handleReady() {
    isWidgetReady = true
    readyContinuations.forEach { $0.resume() }
    readyContinuations.removeAll()
  }

  fileprivate func handleToken(_ token: String) {
    pendingContinuation?.resume(returning: token)
    pendingContinuation = nil
  }

  fileprivate func handleError() {
    pendingContinuation?.resume(throwing: AuthError.captchaFailed)
    pendingContinuation = nil
  }

  fileprivate func handleExpired() {
    guard !hasRetriedAfterExpiry else {
      pendingContinuation?.resume(throwing: AuthError.captchaFailed)
      pendingContinuation = nil
      return
    }
    hasRetriedAfterExpiry = true
    webView.evaluateJavaScript("window.twReset(); window.twExecute();")
  }

  private static let html = """
  <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad" async defer></script>
  <script>
    var widgetId;
    function onTurnstileLoad() {
      widgetId = turnstile.render('#widget', {
        sitekey: '\(TurnstileConfigEmbedded.siteKey)',
        size: 'invisible',
        callback: function(token) {
          webkit.messageHandlers.turnstile.postMessage({type: 'token', token: token});
        },
        'error-callback': function() {
          webkit.messageHandlers.turnstile.postMessage({type: 'error'});
        },
        'expired-callback': function() {
          webkit.messageHandlers.turnstile.postMessage({type: 'expired'});
        }
      });
      webkit.messageHandlers.turnstile.postMessage({type: 'ready'});
    }
    window.twExecute = function() { if (widgetId) { turnstile.execute(widgetId); } };
    window.twReset = function() { if (widgetId) { turnstile.reset(widgetId); } };
  </script>
  </head><body><div id="widget"></div></body></html>
  """
}

extension TurnstileTokenProvider: WKScriptMessageHandler {
  nonisolated func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
    Task { @MainActor [weak self] in
      guard let self else { return }
      switch type {
      case "ready":
        self.handleReady()
      case "token":
        if let token = body["token"] as? String {
          self.handleToken(token)
        } else {
          self.handleError()
        }
      case "expired":
        self.handleExpired()
      default:
        self.handleError()
      }
    }
  }
}
```

- [ ] **Step 5: Manual spike — temporary verification hook**

Add a temporary `.task` to `Features/Auth/Views/LandingView.swift`'s body (find its root view modifier chain and append; exact insertion point depends on current file content — add it as the last modifier on the top-level view):

```swift
.task {
  do {
    let token = try await TurnstileTokenProvider.shared.getToken()
    print("🟢 TURNSTILE SPIKE: got token, length=\(token.count)")
  } catch {
    print("🔴 TURNSTILE SPIKE FAILED: \(error)")
  }
}
```

- [ ] **Step 6: Run and manually verify in the simulator**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```
Launch the app in the iPhone 17 simulator (Xcode run, or `xcrun simctl launch`), land on `LandingView`, and check the Xcode console output.

**Expected:** `🟢 TURNSTILE SPIKE: got token, length=NNN` (a few hundred characters). **If instead you see `🔴 TURNSTILE SPIKE FAILED`**, this is the spec's flagged risk materializing — the `baseURL` hostname trick didn't satisfy Turnstile's allow-list check. **Stop here and report back** rather than continuing to Task 4+; the fix is either a different `baseURL` value or a Cloudflare-dashboard allow-list change, both of which need a decision before wiring this further into the auth flow.

- [ ] **Step 7: Remove the temporary spike hook**

Once verified, remove the `.task` block added in Step 5 from `LandingView.swift` (Task 9 will add the *real* mount point in `TheRecruitingCompassApp.swift` instead).

- [ ] **Step 8: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/Turnstile/ TheRecruitingCompassTests/Mocks/MockTurnstileTokenProvider.swift
git commit -m "feat(auth): add TurnstileTokenProvider widget bridge (spike-verified)"
```

---

### Task 3: `AuthError.captchaFailed`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Models/AuthError.swift`

**Interfaces:**
- Produces: `AuthError.captchaFailed` case, consumed by Task 2 (`TurnstileTokenProvider`) and Tasks 6–8 (ViewModels' error mapping — no code change needed there since `mapError`/`mapAuthError` both fall through to the `AuthError.errorDescription` for any case not special-cased).

**Run this task before Task 2 Step 4** (see note in Task 2).

- [ ] **Step 1: Add the case**

In `Core/Models/AuthError.swift`, add a new case after `case coppaUnderAge:` (line 44) and before `case unknown(Error)`:

```swift
  /// The Cloudflare Turnstile captcha challenge failed, timed out, or could not be
  /// completed (e.g. no network reaching Cloudflare, widget error, expired token).
  case captchaFailed
```

- [ ] **Step 2: Add `errorDescription`**

In the `errorDescription` switch, add a case after `.coppaUnderAge` (after line 88's return) and before `.unknown(let err):`:

```swift
    case .captchaFailed:
      return "Couldn't verify you're human. Please try again."
```

- [ ] **Step 3: Add `recoverySuggestion`**

In the `recoverySuggestion` switch, add a case after `.coppaUnderAge` (after line 131's return) and before `.unknown:`:

```swift
    case .captchaFailed:
      return "Check your internet connection and try again."
```

- [ ] **Step 4: Verify the build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```
Expected: `BUILD SUCCEEDED` (no exhaustive-switch warnings/errors — both switches in `AuthError.swift` are exhaustive over all cases with no `default:`, so the compiler forces both new cases to exist, which is the correctness check here).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Models/AuthError.swift
git commit -m "feat(auth): add AuthError.captchaFailed case"
```

---

### Task 4: Thread `captchaToken` through `SupabaseManaging`/`SupabaseManager`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/SupabaseManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`
- Modify: `TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift`

**Interfaces:**
- Consumes: nothing new from earlier tasks (this task only reshapes an existing interface).
- Produces: `SupabaseManaging.signIn(email:password:captchaToken:)`, `.signUp(email:password:fullName:role:familyCode:dateOfBirth:captchaToken:)`, `.resetPasswordForEmail(email:captchaToken:)` — consumed by Task 5 (`AuthManager`).

This layer has no dedicated unit tests today (`SupabaseManager` wraps the real, non-mockable `SupabaseClient`; it's tested only indirectly through `AuthManager` via `MockSupabaseManager` substitution). This task's correctness check is the build plus Task 5's `AuthManagerTests` (which exercise `MockSupabaseManager`'s captured values) plus Task 10's manual end-to-end run.

- [ ] **Step 1: Update `SupabaseManaging` protocol**

In `Core/Protocols/SupabaseManaging.swift`, change:

```swift
  func signIn(email: String, password: String) async throws -> (user: User, session: Session)
```
to:
```swift
  func signIn(email: String, password: String, captchaToken: String) async throws -> (user: User, session: Session)
```

Change:
```swift
  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String?
  ) async throws -> (user: User, session: Session?)
```
to:
```swift
  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String?,
    captchaToken: String
  ) async throws -> (user: User, session: Session?)
```

Change:
```swift
  func resetPasswordForEmail(email: String) async throws
```
to:
```swift
  func resetPasswordForEmail(email: String, captchaToken: String) async throws
```

- [ ] **Step 2: Update `SupabaseManager` implementation**

In `Core/Services/SupabaseManager.swift`, change the `signIn` signature and body:

```swift
  func signIn(email: String, password: String, captchaToken: String) async throws -> (user: User, session: Session) {
    let response = try await client.auth.signIn(
      email: email,
      password: password,
      captchaToken: captchaToken
    )
```
(rest of the method body unchanged).

Change the `signUp` signature and its `client.auth.signUp` call:

```swift
  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String? = nil,
    captchaToken: String
  ) async throws -> (user: User, session: Session?) {
```
and inside the body:
```swift
      let response = try await client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
        captchaToken: captchaToken
      )
```
(everything else in the method body unchanged).

Change `resetPasswordForEmail`:

```swift
  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    do {
      try await client.auth.resetPasswordForEmail(email, captchaToken: captchaToken)
    } catch {
      guard SupabaseAuthErrors.isUserNotFound(error) else {
        throw AuthError.serverError("Failed to send password reset email")
      }
      throw AuthError.resetEmailNotFound
    }
  }
```

- [ ] **Step 3: Update `MockSupabaseManager`**

In `TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift`, add captured-value properties and update signatures:

```swift
  private(set) var capturedSignInCaptchaToken: String?
  private(set) var capturedSignUpCaptchaToken: String?
  private(set) var capturedResetPasswordCaptchaToken: String?

  func signIn(email: String, password: String, captchaToken: String) async throws -> (user: User, session: Session) {
    capturedSignInCaptchaToken = captchaToken
    return try signInResult.get()
  }

  private(set) var capturedSignUpDateOfBirth: String?

  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String?,
    captchaToken: String
  ) async throws -> (user: User, session: Session?) {
    capturedSignUpDateOfBirth = dateOfBirth
    capturedSignUpCaptchaToken = captchaToken
    return try signUpResult.get()
  }

  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    capturedResetPasswordCaptchaToken = captchaToken
    if let error = resetPasswordError { throw error }
  }
```
(Remove the old `signIn`/`signUp`/`resetPasswordForEmail` bodies they replace; leave `setSession`, `signOut`, `getCurrentSession`, `refreshSession`, `resendVerificationEmail`, `updatePassword` untouched.)

- [ ] **Step 4: Verify the build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -40
```
Expected: build fails at this point with errors in `AuthManager.swift` (it still calls the old 2-arg `signIn`/6-arg `signUp`/1-arg `resetPasswordForEmail`) — **that's expected and correct**; Task 5 fixes those call sites next. Confirm the *only* errors are in `AuthManager.swift` at the three call sites (lines ~53, ~85-92, ~146) — if errors appear anywhere else, something in this task's edit is wrong.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/SupabaseManaging.swift TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift
git commit -m "feat(auth): thread captchaToken through SupabaseManaging/SupabaseManager"
```
(Committing a build-broken intermediate state is intentional and fine here — Task 5 is the very next task and fixes it. If your workflow prefers a single clean commit spanning Tasks 4+5, squash after Task 5 instead of committing here.)

---

### Task 5: Thread `captchaToken` through `AuthManaging`/`AuthManager` + new `AuthManagerTests`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`
- Modify: `TheRecruitingCompassTests/Mocks/MockAuthManager.swift`
- Create: `TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift`

**Interfaces:**
- Consumes: `SupabaseManaging.signIn/signUp/resetPasswordForEmail(...,captchaToken:)` (Task 4), `MockSupabaseManager.capturedSignInCaptchaToken` etc. (Task 4).
- Produces: `AuthManaging.login(email:password:captchaToken:)`, `.signup(...,captchaToken:)`, `.resetPasswordForEmail(email:captchaToken:)` — consumed by Tasks 6–8.

- [ ] **Step 1: Write the failing tests first**

Create `TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockSupabaseManager: MockSupabaseManager!

  override func setUp() {
    super.setUp()
    mockSupabaseManager = MockSupabaseManager()
    sut = AuthManager(supabaseManager: mockSupabaseManager)
  }

  override func tearDown() {
    sut = nil
    mockSupabaseManager = nil
    super.tearDown()
  }

  func testLoginForwardsCaptchaToken() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil, phone: nil,
      fullName: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: nil, dateOfBirth: nil
    )
    let session = Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh", user: user
    )
    mockSupabaseManager.signInResult = .success((user: user, session: session))

    try await sut.login(email: "user@example.com", password: "password123", captchaToken: "test-captcha-token")

    XCTAssertEqual(mockSupabaseManager.capturedSignInCaptchaToken, "test-captcha-token")
  }

  func testSignupForwardsCaptchaToken() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil, phone: nil,
      fullName: "Jane Doe", createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: .player, dateOfBirth: nil
    )
    mockSupabaseManager.signUpResult = .success((user: user, session: nil))

    try await sut.signup(
      email: "user@example.com",
      password: "password123",
      fullName: "Jane Doe",
      role: .player,
      familyCode: nil,
      dateOfBirth: "2005-01-01",
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockSupabaseManager.capturedSignUpCaptchaToken, "test-captcha-token")
  }

  func testResetPasswordForEmailForwardsCaptchaToken() async throws {
    try await sut.resetPasswordForEmail(email: "user@example.com", captchaToken: "test-captcha-token")

    XCTAssertEqual(mockSupabaseManager.capturedResetPasswordCaptchaToken, "test-captcha-token")
  }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/AuthManagerTests 2>&1 | tail -50
```
Expected: **compile failure** — `AuthManager.login`/`.signup`/`.resetPasswordForEmail` don't accept a `captchaToken` argument yet (matches the intentional broken state left at the end of Task 4).

- [ ] **Step 3: Update `AuthManaging` protocol**

In `Core/Protocols/AuthManaging.swift`, change:
```swift
  func login(email: String, password: String) async throws
```
to:
```swift
  func login(email: String, password: String, captchaToken: String) async throws
```

Change:
```swift
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?) async throws
```
to:
```swift
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?, captchaToken: String) async throws
```

Change:
```swift
  func resetPasswordForEmail(email: String) async throws
```
to:
```swift
  func resetPasswordForEmail(email: String, captchaToken: String) async throws
```

- [ ] **Step 4: Update `AuthManager` implementation**

In `Core/Services/AuthManager.swift`, change `login`:
```swift
  func login(email: String, password: String, captchaToken: String) async throws {
    logger.debug("Attempting login for: \(email.prefix(3))***")
    do {
      let (user, session) = try await supabaseManager.signIn(email: email, password: password, captchaToken: captchaToken)
```
(rest of the method body unchanged).

Change `signup`:
```swift
  func signup(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String? = nil,
    captchaToken: String
  ) async throws {
```
and inside the body:
```swift
      let (user, session) = try await supabaseManager.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: familyCode,
        dateOfBirth: dateOfBirth,
        captchaToken: captchaToken
      )
```
(everything else unchanged).

Change `resetPasswordForEmail`:
```swift
  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    logger.debug("Requesting password reset for: \(email.prefix(3))***")
    do {
      try await supabaseManager.resetPasswordForEmail(email: email, captchaToken: captchaToken)
```
(rest unchanged).

- [ ] **Step 5: Update `MockAuthManager`**

In `TheRecruitingCompassTests/Mocks/MockAuthManager.swift`, add captured-value properties near the other mock state (after `mockErrorToThrow`, line ~37):

```swift
  private(set) var capturedLoginCaptchaToken: String?
  private(set) var capturedSignupCaptchaToken: String?
  private(set) var capturedResetEmailCaptchaToken: String?
```

Update `login`:
```swift
  func login(email: String, password: String, captchaToken: String) async throws {
    loginCallCount += 1
    capturedLoginCaptchaToken = captchaToken

    if shouldThrowLoginError {
      throw mockErrorToThrow
    }
```
(rest of the method unchanged).

Update `signup`:
```swift
  func signup(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String? = nil,
    captchaToken: String
  ) async throws {
    signupCallCount += 1
    capturedSignupCaptchaToken = captchaToken

    if shouldThrowSignupError {
      throw mockErrorToThrow
    }
```
(rest unchanged).

Update `resetPasswordForEmail`:
```swift
  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    resetEmailCallCount += 1
    capturedResetEmailCaptchaToken = captchaToken
    if shouldThrowResetEmailError {
      throw mockErrorToThrow
    }
  }
```

In `reset()`, add clearing the new properties alongside the existing resets:
```swift
    capturedLoginCaptchaToken = nil
    capturedSignupCaptchaToken = nil
    capturedResetEmailCaptchaToken = nil
```

- [ ] **Step 6: Run to verify tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/AuthManagerTests 2>&1 | tail -50
```
Expected: `** TEST SUCCEEDED **`, all 3 new tests pass. Full build will still fail here — `LoginViewModel`/`SignupViewModel`/`ForgotPasswordViewModel` call sites aren't updated yet (Tasks 6–8). That's expected.

- [ ] **Step 7: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AuthManaging.swift TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift TheRecruitingCompassTests/Mocks/MockAuthManager.swift TheRecruitingCompassTests/Core/Services/AuthManagerTests.swift
git commit -m "feat(auth): thread captchaToken through AuthManaging/AuthManager, add AuthManagerTests"
```

---

### Task 6: Wire `LoginViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift`
- Modify: `TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift`

**Interfaces:**
- Consumes: `TurnstileTokenProviding.getToken()` (Task 2), `MockTurnstileTokenProvider` (Task 2), `AuthManaging.login(email:password:captchaToken:)` (Task 5), `MockAuthManager.capturedLoginCaptchaToken` (Task 5).

- [ ] **Step 1: Write the failing test first**

Add to `LoginViewModelTests.swift` (find the existing `setUp()`/`tearDown()` and login-success test to place this near them):

```swift
  func testLoginFetchesAndForwardsCaptchaToken() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.tokenToReturn = "captcha-abc-123"
    sut = LoginViewModel(authManager: mockAuthManager, turnstileTokenProvider: mockTurnstile)
    sut.email = "user@example.com"
    sut.password = "password123"

    await sut.login()

    XCTAssertEqual(mockTurnstile.getTokenCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedLoginCaptchaToken, "captcha-abc-123")
  }

  func testLoginSurfacesCaptchaFailure() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.shouldThrowError = true
    sut = LoginViewModel(authManager: mockAuthManager, turnstileTokenProvider: mockTurnstile)
    sut.email = "user@example.com"
    sut.password = "password123"

    await sut.login()

    XCTAssertEqual(mockAuthManager.loginCallCount, 0)
    XCTAssertEqual(sut.errorMessage, "Couldn't verify you're human. Please try again.")
  }
```
(Check `LoginViewModelTests.swift`'s existing `sut`/`mockAuthManager` declaration names match `sut`/`mockAuthManager` used above — the research confirmed these exact names are used throughout the file.)

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/LoginViewModelTests 2>&1 | tail -50
```
Expected: compile failure — `LoginViewModel.init` doesn't accept `turnstileTokenProvider:` yet, and `authManager.login` doesn't take 3 args from `LoginViewModel`'s call site yet.

- [ ] **Step 3: Implement**

In `LoginViewModel.swift`, add the field (after `private let authManager: any AuthManaging`, line 20):
```swift
  private let turnstileTokenProvider: any TurnstileTokenProviding
```

Update `init`:
```swift
  init(
    authManager: (any AuthManaging)? = nil,
    biometricService: (any BiometricServiceProtocol)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil,
    timeoutReason: String? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.biometricService = biometricService ?? BiometricService()
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
    checkTimeoutReason(timeoutReason)
    loadCachedEmail()
  }
```

Update `login()`:
```swift
    do {
      let captchaToken = try await turnstileTokenProvider.getToken()
      try await authManager.login(email: email, password: password, captchaToken: captchaToken)
      if !authManager.biometricEnabled && biometricService.canEvaluateBiometrics() {
        authManager.pendingBiometricEnrollmentOffer = true
      }
    } catch {
      errorMessage = mapError(error)
    }
```

`mapError(_:)` already handles this correctly with no change: `AuthError.captchaFailed` is not in `errorPatterns`, so it falls through to `authError.errorDescription`, which is `"Couldn't verify you're human. Please try again."` — matching the test assertion above.

- [ ] **Step 4: Run to verify tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/LoginViewModelTests 2>&1 | tail -80
```
Expected: `** TEST SUCCEEDED **`, all `LoginViewModelTests` (existing + 2 new) pass.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/LoginViewModel.swift TheRecruitingCompassTests/Features/Auth/ViewModels/LoginViewModelTests.swift
git commit -m "feat(auth): wire Turnstile captcha token into LoginViewModel"
```

---

### Task 7: Wire `SignupViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/SignupViewModel.swift`
- Modify: `TheRecruitingCompassTests/Features/Auth/ViewModels/SignupViewModelTests.swift`

**Interfaces:**
- Consumes: same as Task 6, plus `SignupViewModel`'s existing `mapAuthError(_:).userMessage` (unchanged — `.captchaFailed` falls into its `default:` branch, `userMessage` = `errorDescription`).

- [ ] **Step 1: Write the failing test first**

Add to `SignupViewModelTests.swift` (use the file's existing `fillValidForm(role:)` helper found during research):

```swift
  func testSignupFetchesAndForwardsCaptchaToken() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.tokenToReturn = "captcha-signup-456"
    sut = SignupViewModel(authManager: mockAuthManager, familyService: mockFamilyService, turnstileTokenProvider: mockTurnstile)
    fillValidForm()

    await sut.signup()

    XCTAssertEqual(mockTurnstile.getTokenCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupCaptchaToken, "captcha-signup-456")
  }

  func testSignupSurfacesCaptchaFailure() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.shouldThrowError = true
    sut = SignupViewModel(authManager: mockAuthManager, familyService: mockFamilyService, turnstileTokenProvider: mockTurnstile)
    fillValidForm()

    await sut.signup()

    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
    XCTAssertEqual(sut.errorMessage, "Couldn't verify you're human. Please try again.")
  }
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SignupViewModelTests 2>&1 | tail -50
```
Expected: compile failure — `SignupViewModel.init` doesn't accept `turnstileTokenProvider:` yet.

- [ ] **Step 3: Implement**

In `SignupViewModel.swift`, add the field (after `private let familyService: any FamilyManaging`, line 37):
```swift
  private let turnstileTokenProvider: any TurnstileTokenProviding
```

Update `init`:
```swift
  init(
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
  }
```

Update `signup()`'s call site:
```swift
    do {
      let captchaToken = try await turnstileTokenProvider.getToken()
      try await authManager.signup(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil,
        captchaToken: captchaToken
      )
```
(the rest of the `do` block and its `catch { errorMessage = mapAuthError(error).userMessage }` are unchanged).

- [ ] **Step 4: Run to verify tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SignupViewModelTests 2>&1 | tail -80
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/SignupViewModel.swift TheRecruitingCompassTests/Features/Auth/ViewModels/SignupViewModelTests.swift
git commit -m "feat(auth): wire Turnstile captcha token into SignupViewModel"
```

---

### Task 8: Wire `ForgotPasswordViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/ForgotPasswordViewModel.swift`
- Modify: `TheRecruitingCompassTests/Features/Auth/ViewModels/ForgotPasswordViewModelTests.swift`

**Interfaces:**
- Consumes: same as Task 6, plus `AuthManaging.resetPasswordForEmail(email:captchaToken:)` (Task 5), `MockAuthManager.capturedResetEmailCaptchaToken` (Task 5).

- [ ] **Step 1: Write the failing test first**

Add to `ForgotPasswordViewModelTests.swift`, near `testSendResetLinkSuccess`:

```swift
  func testSendResetLinkFetchesAndForwardsCaptchaToken() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.tokenToReturn = "captcha-reset-789"
    sut = ForgotPasswordViewModel(authManager: mockAuthManager, turnstileTokenProvider: mockTurnstile)
    sut.email = "user@example.com"

    await sut.sendResetLink()

    XCTAssertEqual(mockTurnstile.getTokenCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedResetEmailCaptchaToken, "captcha-reset-789")
  }

  func testSendResetLinkSurfacesCaptchaFailure() async {
    let mockTurnstile = MockTurnstileTokenProvider()
    mockTurnstile.shouldThrowError = true
    sut = ForgotPasswordViewModel(authManager: mockAuthManager, turnstileTokenProvider: mockTurnstile)
    sut.email = "user@example.com"

    await sut.sendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 0)
    XCTAssertEqual(sut.errorMessage, "Couldn't verify you're human. Please try again.")
  }
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ForgotPasswordViewModelTests 2>&1 | tail -50
```
Expected: compile failure — `ForgotPasswordViewModel.init` doesn't accept `turnstileTokenProvider:` yet.

- [ ] **Step 3: Implement**

In `ForgotPasswordViewModel.swift`, add the field (after `private let config: PasswordResetConfig`, line 17):
```swift
  private let turnstileTokenProvider: any TurnstileTokenProviding
```

Update `init`:
```swift
  init(
    authManager: (any AuthManaging)? = nil,
    config: PasswordResetConfig? = nil,
    turnstileTokenProvider: (any TurnstileTokenProviding)? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.config = config ?? .default
    self.turnstileTokenProvider = turnstileTokenProvider ?? TurnstileTokenProvider.shared
  }
```

Update the single choke-point `executeSendReset(for:)` (used by both `sendResetLink()` and `resendResetLink()`):
```swift
  private func executeSendReset(for email: String) async throws {
    let captchaToken = try await turnstileTokenProvider.getToken()
    try await authManager.resetPasswordForEmail(email: email, captchaToken: captchaToken)
  }
```

- [ ] **Step 4: Run to verify tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ForgotPasswordViewModelTests 2>&1 | tail -80
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth/ViewModels/ForgotPasswordViewModel.swift TheRecruitingCompassTests/Features/Auth/ViewModels/ForgotPasswordViewModelTests.swift
git commit -m "feat(auth): wire Turnstile captcha token into ForgotPasswordViewModel"
```

---

### Task 9: Mount the widget for real in `TheRecruitingCompassApp`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`

**Interfaces:**
- Consumes: `TurnstileWidgetView` (Task 2).

- [ ] **Step 1: Confirm the Task 2 spike hook was removed**

Verify `Features/Auth/Views/LandingView.swift` no longer contains the temporary `.task` block from Task 2 Step 5 (`git log -p` or `git diff` on that file across Task 2's commits should show it added then removed within Task 2 itself — if it's still present, remove it now).

- [ ] **Step 2: Add the real mount point**

In `TheRecruitingCompassApp.swift`, the root `Group` (lines 37-73) branches on `authManager.isAuthenticated`; the widget only needs to exist during the unauthenticated branch (login/signup/password-reset all live there). Add it as an `.overlay` on the whole `Group`, gated on `!authManager.isAuthenticated`, alongside the existing `.overlay { if showBiometricLock { ... } }` block (lines 82-100) — add a second `.overlay` modifier right after that one:

```swift
      .overlay {
        if !authManager.isAuthenticated {
          TurnstileWidgetView()
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
```

(This sits alongside, not inside, the existing biometric-lock `.overlay` — SwiftUI supports multiple `.overlay` modifiers chained on the same view; each stacks independently.)

- [ ] **Step 3: Verify the build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift
git commit -m "feat(auth): mount hidden TurnstileWidgetView for unauthenticated flows"
```

---

### Task 10: Full test suite + manual end-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full unit test suite**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/.claude/worktrees/turnstile-captcha-spec/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -60
```
Expected: `** TEST SUCCEEDED **` (or check the exit code directly — per this project's `CLAUDE.md`, trust `xcodebuild`'s exit code over a text grep for the full ~3700-test target if it runs long; the affected-feature subset from Tasks 5–8 above is the fast path if this exceeds the 10-minute window).

- [ ] **Step 2: Manual simulator verification — login**

Launch the app in the iPhone 17 simulator, attempt login with real prod credentials. Expected: no more `"captcha protection: request disallowed"` error; login either succeeds or fails with a *different*, legitimate error (wrong password, etc.) — the captcha rejection specifically must be gone.

- [ ] **Step 3: Manual simulator verification — signup**

Attempt a fresh signup (throwaway test account/email). Expected: no captcha rejection; signup proceeds to its normal next step (email verification screen or authenticated dashboard).

- [ ] **Step 4: Manual simulator verification — password reset**

From the login screen, tap "Forgot password?", submit a real account's email. Expected: no captcha rejection; the app shows its normal "email sent" confirmation state.

- [ ] **Step 5: Report findings**

If any of Steps 2-4 still show the captcha error, stop and report which flow(s) still fail — do not proceed to Task 11-equivalent follow-up work (there is none in this plan) until this is resolved, since it would mean either the SDK call isn't actually reaching Supabase with a token, or the Turnstile challenge itself isn't validating server-side despite returning a token client-side (possible if the site key's secret-key pairing in the Supabase dashboard doesn't match, which is a dashboard configuration issue outside this plan's scope — flag back rather than debug further in code).

---

## Explicitly not covered by this plan

- Web's matching login/password-reset captcha gap (flagged in the spec; separate work, separate repo).
- Any Cloudflare/Supabase dashboard configuration change (only needed if Task 2's spike fails).
