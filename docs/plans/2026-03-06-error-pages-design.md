# iOS Error Pages — Design Document

**Date:** 2026-03-06
**Status:** Approved
**Spec:** `planning/iOS_SPEC_ErrorPages.md` (ported from web `error.vue`)

---

## Goals

Replace generic iOS error states with branded, human-friendly error screens that match the web app experience. Keep users calm, explain what happened, and give a clear next step. Blame the system, never the user.

---

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Naming | Rename `ErrorStateView` → `InlineErrorView`, create new `AppErrorView` | Clear purpose distinction between inline content errors and full-screen fatal errors |
| Sport field background | Skip — use plain emerald gradient | Component doesn't exist in iOS yet; Login/Signup are consistent without it |
| Error state ownership | Local per-ViewModel (`var appError: AppError?`) | Matches existing MVVM pattern; keeps components testable in isolation |

---

## Files

### New
- `TheRecruitingCompass/Shared/Components/AppError.swift` — enum + HTTP/URLError initializers
- `TheRecruitingCompass/Shared/Components/AppErrorView.swift` — full-screen branded error view
- `TheRecruitingCompass/Shared/Components/SessionExpiredSheet.swift` — modal sheet for token expiry

### Modified
- `TheRecruitingCompass/Shared/Components/ErrorStateView.swift` → renamed to `InlineErrorView.swift`, struct renamed `InlineErrorView`, call sites updated

---

## AppError Enum

```swift
enum AppError: Identifiable {
    case notFound
    case unauthorized
    case forbidden
    case serverError(statusCode: Int)
    case serviceUnavailable
    case networkOffline
    case sessionExpired
    case unknown
}
```

Two failable initializers:
- `init(from: Error)` — maps `URLError` codes (`.notConnectedToInternet`, `.networkConnectionLost` → `.networkOffline`; `.timedOut` → `.serviceUnavailable`; default → `.unknown`)
- `init(statusCode: Int)` — maps HTTP status codes (401 → `.unauthorized`, 403 → `.forbidden`, 404 → `.notFound`, 500 → `.serverError(500)`, 502/503/504 → `.serviceUnavailable`, default → `.unknown`)

---

## AppErrorView

### Signature
```swift
struct AppErrorView: View {
    let error: AppError
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
}
```
Stateless. Calling ViewModel owns retry/navigation logic.

### Layout (top to bottom)
1. `LinearGradient.primaryBackground` full-bleed ignoring safe area
2. `LogoStacked` image — height 120, proportional width, drop shadow — above the card
3. White card — `Color.white.opacity(0.95)`, `cornerRadius: 16`, `padding: 32`, max width 400, `padding(.horizontal, 24)`
   - 56×56 colored icon circle (`cornerRadius: 28`) — `accessibilityHidden(true)`
   - Headline — `.title2.bold`, centered, `accessibilityAddTraits(.isHeader)`
   - Body — `.body`, `.secondary`, centered
   - Status code — `.caption`, `.tertiaryLabel`, `.monospacedDigit()`, hidden when nil
   - Primary button — blue filled (`LinearGradient.primaryButton`)
   - Secondary button — gray background, optional (nil for some error types)
4. Support link — `"Need help? Contact support"`, `.white.opacity(0.7)`, `mailto:support@therecruitingcompass.com` — below card

### Error Type Configurations

| Type | Headline | Icon | Icon BG | Icon FG | Primary | Secondary |
|---|---|---|---|---|---|---|
| 404 | "That page ran a different route." | `magnifyingglass` | `#EFF6FF` | `#3B82F6` | Go to Dashboard | Search Schools |
| 401 | "You'll need to sign in first." | `lock.fill` | `#FFFBEB` | `#F59E0B` | Sign In | Create Account |
| 403 | "This isn't your playbook." | `shield.slash.fill` | `#FEF2F2` | `#EF4444` | Go to Dashboard | — |
| 500 | "We fumbled. It's on us." | `exclamationmark.triangle.fill` | `#FEF2F2` | `#EF4444` | Try Again | Go Home |
| 502/503/504 | "We're taking a timeout." | `clock.fill` | `#F8FAFC` | `#64748B` | Try Again | Go Home |
| Network | "Looks like the connection dropped." | `wifi.slash` | `#F8FAFC` | `#64748B` | Try Again | — |
| Unknown | "Something went sideways." | `exclamationmark.circle.fill` | `#F8FAFC` | `#64748B` | Try Again | Go Home |

---

## SessionExpiredSheet

Plain modal (`.sheet`), no branded background. Shown when a background token refresh returns 401 and the user may have unsaved state.

```
Title:   "You've been away for a while."
Body:    "For your security, we signed you out after a period of inactivity. Log back in to continue."
Button:  "Sign In Again" → Login screen
```

---

## Presentation Patterns

```swift
// Fatal / navigation failed
.fullScreenCover(item: $viewModel.appError) { error in
    AppErrorView(error: error, onPrimary: { ... }, onSecondary: nil)
}

// Tab content failure (inline)
if let error = viewModel.appError {
    AppErrorView(error: error, onPrimary: { Task { await viewModel.load() } }, onSecondary: nil)
} else {
    // normal content
}

// Session expired
.sheet(isPresented: $viewModel.showSessionExpired) {
    SessionExpiredSheet(onSignIn: { ... })
}
```

---

## Accessibility

- Icon circles: `accessibilityHidden(true)` (decorative)
- Headline: `accessibilityAddTraits(.isHeader)`
- On appear: `UIAccessibility.post(notification: .announcement, argument: headline)`
- Buttons: labels match visible text
- Support link: `Link("Contact support", destination: URL(string: "mailto:support@therecruitingcompass.com")!)`

---

## InlineErrorView (Rename)

`ErrorStateView` → `InlineErrorView`. Zero behavior change. All existing call sites updated. Keeps serving tab-level and section-level content failure states.
