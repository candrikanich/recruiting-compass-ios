# iOS Turnstile Captcha Support — Design Spec

**Date:** 2026-09-09
**Status:** Approved (pending spec self-review)
**Author:** Claude (session `chore/local-main-prod-swap-catchup` follow-up work, on `main`)

## Problem

Supabase Auth's Attack Protection (Cloudflare Turnstile) is enabled server-side
for the prod project (`lrzsenidegcqhwzwncve`). The iOS app's `SupabaseManager`
sends no `captchaToken` on any auth call, so `signIn`, `signUp`, and
`resetPasswordForEmail` all fail with:

```
Login failed: captcha protection: request disallowed (no captcha_token found)
```

This currently blocks all login on iOS. Decision (Chris, 2026-09-09): **keep
captcha protection on**, make the iOS client satisfy it, across all three
Supabase auth calls it covers (login, signup, password reset) — not just
login.

### Web parity note

The web app only wires Turnstile into `signup.vue` / `useAuth.ts`'s
`signup()` → `supabase.auth.signUp()`. Web's `login()` (`signInWithPassword`)
and password-reset flows (`forgot-password.vue`, `reset-password.vue`) have
**no** captcha wiring. Since Supabase's Attack Protection covers signup,
signin, and password-recovery uniformly once enabled, **web login is very
likely also currently broken in prod** — this was not reproduced or fixed as
part of this spec (out of scope: iOS repo, iOS work), but should be flagged
and fixed on the web side separately. Not blocking this iOS work.

## Goals

- iOS `login`, `signup`, and `resetPasswordForEmail` all successfully pass a
  valid `captchaToken` to Supabase Auth.
- Widget UX is invisible/managed — no visible "I am not a robot" checkbox in
  the normal case.
- Reuses the existing web Turnstile site key (`0x4AAAAAAEc9xAHjjO-Jv5pg`) —
  it's a public key, safe client-side, already allow-listed for the prod
  domain in the Cloudflare dashboard.
- Config value flows through the existing `Release.xcconfig` →
  build-phase-generated-Swift pipeline (same pattern as `POSTHOG_API_KEY`),
  not hardcoded in source.

## Non-goals

- Fixing web's login/password-reset captcha gap (flag only, tracked
  separately).
- A visible/checkbox captcha UX.
- Supporting hCaptcha or any provider other than Turnstile.
- Any change to the fact that captcha protection is enabled server-side —
  that decision (keep it) is settled; this spec is purely "make the client
  satisfy it."

## Architecture

### 1. Config: `TURNSTILE_SITE_KEY`

Follows the exact precedent set by `POSTHOG_API_KEY`:

- `TheRecruitingCompass/Release.xcconfig` gets a new line:
  `TURNSTILE_SITE_KEY = 0x4AAAAAAEc9xAHjjO-Jv5pg`
- The "Generate Supabase config" build phase in `project.pbxproj` (the inline
  `shellScript`, currently ~line 333) gets one more escape+printf block,
  identical in shape to the existing `POSTHOG_API_KEY` block, emitting a new
  generated file:
  `TheRecruitingCompass/TheRecruitingCompass/Core/Services/TurnstileConfig.generated.swift`
  ```swift
  enum TurnstileConfigEmbedded {
    static let siteKey = "0x4AAAAAAEc9xAHjjO-Jv5pg"
  }
  ```
- The **committed** version of this file (checked into git, like
  `SupabaseConfig.generated.swift`) holds a placeholder value
  (`"placeholder-site-key"`), overwritten locally/in CI by the build phase.
  This matches the existing generated-config convention documented in
  `CLAUDE.md` — do not hand-edit the generated file.

### 2. Widget: `TurnstileWidgetView`

New file: `Core/Services/Turnstile/TurnstileWidgetView.swift`

A `UIViewRepresentable` wrapping a `WKWebView` (first WebKit usage in the
app — no existing pattern to extend). Responsibilities:

- `makeUIView` creates a `WKWebView`, registers a `WKScriptMessageHandler`
  (`"turnstile"`) on its user content controller, and loads a small inline
  HTML string via `loadHTMLString(_:baseURL:)`.
- **`baseURL` must be `https://myrecruitingcompass.com`** (the prod
  `API_BASE_URL` domain) — see Risk section below. This makes
  `document.location.hostname` resolve to a domain already allow-listed for
  the site key in the Cloudflare Turnstile dashboard, even though the HTML
  itself is loaded locally, not fetched over the network.
- The HTML page loads `https://challenges.cloudflare.com/turnstile/v0/api.js`
  and renders the widget explicitly:
  ```js
  turnstile.render('#widget', {
    sitekey: '<TurnstileConfigEmbedded.siteKey>',
    size: 'invisible',
    callback: (token) => webkit.messageHandlers.turnstile.postMessage({type: 'token', token}),
    'error-callback': (code) => webkit.messageHandlers.turnstile.postMessage({type: 'error', code}),
    'expired-callback': () => webkit.messageHandlers.turnstile.postMessage({type: 'expired'}),
  });
  ```
- The Coordinator (`WKScriptMessageHandler` conformer) forwards these three
  message types to closures owned by `TurnstileTokenProvider`.
- Exposes two JS-invoking methods to Swift via `evaluateJavaScript`:
  `execute()` (calls `turnstile.execute()`) and `reset()` (calls
  `turnstile.reset()`).

### 3. Token lifecycle: `TurnstileTokenProvider`

New file: `Core/Services/Turnstile/TurnstileTokenProvider.swift`

`@MainActor @Observable final class TurnstileTokenProvider`, conforms to a
new protocol `TurnstileTokenProviding` (for testability/mocking):

```swift
protocol TurnstileTokenProviding: AnyObject {
    func getToken() async throws -> String
}
```

- Holds a reference to the mounted `TurnstileWidgetView`'s coordinator
  (injected at mount time — see Mounting below).
- `getToken()`:
  1. Calls `reset()` then `execute()` on the widget (tokens are single-use
     with a ~5 minute TTL — **never cached or reused** across calls, even
     for the same form resubmitted).
  2. Awaits the next `token`/`error`/`expired` callback via a
     `CheckedContinuation`, with a 10-second timeout.
  3. On `expired`, retries once automatically (reset + execute again) before
     surfacing an error.
  4. On timeout, JS error, or after the one retry: throws
     `AuthError.captchaUnavailable`.
- `AuthError` (existing enum in `Core/Models/AuthError.swift` — confirm exact
  location during implementation) gets a new case `captchaUnavailable` with
  a user-facing message like "Couldn't verify you're human — check your
  connection and try again."

### 4. Mounting

- One `TurnstileWidgetView` instance is mounted for the lifetime of the
  unauthenticated flow — in `TheRecruitingCompassApp.swift`'s root view (or
  wherever `LandingView`/the auth `NavigationStack` root lives), as a
  `.background(TurnstileWidgetView(...).frame(width: 1, height: 1))` or
  equivalent hidden placement. Must stay in the view hierarchy (not
  `.hidden()`/removed) so WKWebView keeps running its JS.
- The `TurnstileTokenProvider` (owning a reference to that mounted widget)
  is injected into the environment via `.environment(turnstileTokenProvider)`
  so `LoginViewModel`, `SignupViewModel` (or equivalent — confirm exact type
  name during implementation), and `ForgotPasswordViewModel` can resolve it.

### 5. Wiring through Auth/Supabase layers

**`AuthManaging`** (`Core/Protocols/AuthManaging.swift`) — 3 signature
changes:
```swift
func login(email: String, password: String, captchaToken: String) async throws
func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?, captchaToken: String) async throws
func resetPasswordForEmail(email: String, captchaToken: String) async throws
```

**`AuthManager`** — same 3 methods thread `captchaToken` straight through to
the matching `SupabaseManager` call, no other logic change.

**`SupabaseManaging`/`SupabaseManager`** — same 3 methods gain
`captchaToken: String`, passed into the supabase-swift SDK's captcha option
on each call (`SignInWithPasswordCredentials`/equivalent for `signIn`,
`SignUpRequest`/equivalent for `signUp`, and the resetPasswordForEmail
options struct — confirm exact supabase-swift API shape during
implementation; the web `useAuth.ts` reference at
`options.captchaToken` confirms the pattern, exact Swift SDK naming needs a
quick doc/source check).

**Call sites** — `LoginViewModel`, `SignupViewModel`, and
`ForgotPasswordViewModel` each:
1. Resolve `TurnstileTokenProviding` from environment/DI.
2. `let token = try await turnstileProvider.getToken()` immediately before
   calling into `AuthManager`.
3. Pass `token` as the new `captchaToken` argument.
4. On `AuthError.captchaUnavailable`, surface it through the existing
   error-display path (same as any other `AuthError` case) — no new UI
   pattern needed.

**Test updates** — `MockAuthManager` and `MockSupabaseManager` get the new
params added (ignored by default). One new assertion per call site (in
`LoginViewModelTests`/equivalent, `ForgotPasswordViewModelTests`) confirms
the resolved token is actually forwarded into the `AuthManager` call, not
just accepted and dropped.

## Error handling

| Failure | Behavior |
|---|---|
| Widget fails to load (no network, CF unreachable) | `getToken()` throws after 10s timeout → `.captchaUnavailable` shown to user |
| Token expires before use | One automatic reset+retry inside `getToken()`; if that also fails, `.captchaUnavailable` |
| Widget JS error callback fires | Immediate `.captchaUnavailable`, no retry |
| Server still rejects despite a token (edge case: token consumed elsewhere, clock skew, etc.) | Falls through to the existing generic Supabase auth-error handling — not a new case, this is just a normal Supabase error response |

## Testing

- Unit: `TurnstileTokenProviderTests` — mock the widget/coordinator layer,
  verify reset+execute sequencing, timeout behavior, expired-retry-once
  behavior, and error mapping to `.captchaUnavailable`.
- Unit: existing `LoginViewModelTests`, `SignupViewModel` tests (name TBD
  during implementation), `ForgotPasswordViewModelTests` — updated to inject
  a `MockTurnstileTokenProvider` returning a fixed fake token; add one
  assertion per test confirming the token reaches the `AuthManager` mock
  call.
- No new UI/E2E test — the widget is invisible in the normal path and
  E2E/XCUITest cannot drive a real Cloudflare challenge in CI anyway. Manual
  simulator verification is the acceptance bar for the widget itself (see
  Risk spike below).

## Risk / open question — resolve first

Turnstile validates the **hostname of the document** making the challenge
request against the site key's Cloudflare-dashboard allow-list. A WKWebView
given local HTML via `loadHTMLString(_:baseURL: nil)` normally resolves to
no real hostname, which Turnstile will reject. The fix — passing
`baseURL: https://myrecruitingcompass.com` so `document.location.hostname`
matches the already-allow-listed web domain — is a known technique for
hybrid captcha integrations, but **unverified in this codebase**.

**First implementation step must be a small spike**: build just the
`TurnstileWidgetView` + a throwaway button to call `execute()`, confirm a
real token comes back in the simulator, *before* wiring it through
`AuthManaging`/`SupabaseManaging`/the three call sites. If the `baseURL`
trick doesn't satisfy Turnstile's hostname check, the fallback is adding
`myrecruitingcompass.com` (or a dedicated `ios-app://` style identifier, if
Cloudflare's dashboard supports custom hostname patterns) to the site key's
allow-list in the Cloudflare/Supabase dashboard — a dashboard change, not a
code change, and something to flag back to Chris if needed rather than
silently work around.

## Files touched (summary)

**New:**
- `Core/Services/Turnstile/TurnstileWidgetView.swift`
- `Core/Services/Turnstile/TurnstileTokenProvider.swift`
- `Core/Services/TurnstileConfig.generated.swift` (build-phase output,
  placeholder committed)

**Modified:**
- `TheRecruitingCompass/Release.xcconfig`
- `TheRecruitingCompass.xcodeproj/project.pbxproj` (build phase script)
- `Core/Protocols/AuthManaging.swift`
- `Core/Services/AuthManager.swift`
- `Core/Protocols/SupabaseManaging.swift`
- `Core/Services/SupabaseManager.swift`
- `Core/Models/AuthError.swift` (new `.captchaUnavailable` case)
- `Features/Auth/ViewModels/LoginViewModel.swift`
- `Features/Auth/ViewModels/ForgotPasswordViewModel.swift`
- Signup view model (exact file TBD — confirm name during implementation)
- `TheRecruitingCompassApp.swift` (widget mounting)
- `TheRecruitingCompassTests/Mocks/MockAuthManager.swift`
- `TheRecruitingCompassTests/Mocks/MockSupabaseManager.swift`
- Associated `*ViewModelTests.swift` files

## Explicitly out of scope

- Web login/password-reset captcha gap (flagged to Chris, not fixed here).
- Any dashboard-side Cloudflare/Supabase configuration change, unless the
  risk spike above proves the `baseURL` trick doesn't work.
