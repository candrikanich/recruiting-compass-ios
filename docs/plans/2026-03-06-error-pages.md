# iOS Error Pages Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build branded, human-friendly error screens for iOS — an `AppError` enum, a full-screen `AppErrorView`, a `SessionExpiredSheet`, and a rename of the existing `ErrorStateView` to `InlineErrorView`.

**Architecture:** Local per-ViewModel error state (`var appError: AppError?`). `AppErrorView` is stateless — callers own retry/navigation closures. `AppError` carries its own display configuration via a computed `config` property, keeping the view dumb and the logic testable.

**Tech Stack:** SwiftUI, XCTest, SF Symbols, existing `LinearGradient.primaryBackground` + `LogoStacked` asset.

---

## Background

### Existing code to be aware of
- `Shared/Components/ErrorStateView.swift` — simple inline component used in 4 views; will be renamed
- `Core/Theme/AppColors.swift` — defines `Color` extensions (`primaryGreen`, `darkEmerald`, `accentBlue`, etc.)
- `Core/Theme/AppGradients.swift` — defines `LinearGradient.primaryBackground` (emerald gradient used on Login/Signup)
- `Features/Auth/Views/LoginView.swift` — uses `Image("LogoStacked")` — the stacked logo asset name

### Call sites for `ErrorStateView` (all need updating in Task 1)
- `Features/Coaches/Views/CoachDetailView.swift`
- `Features/Schools/Views/SchoolDetailView.swift`
- `Features/Offers/Views/OfferDetailView.swift`
- `Features/Interactions/Views/InteractionDetailView.swift`

### Build command (run from `TheRecruitingCompass/` directory)
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|warning:|BUILD"
```

### Test command
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests 2>&1 | grep -E "Test Case|error:|PASS|FAIL|BUILD"
```

### Important: new ViewModel rule (not needed here but FYI)
Every `@MainActor` ViewModel must have `nonisolated deinit {}` due to a macOS 26.x back-deployment crash. This task creates no ViewModels, so this doesn't apply.

---

## Task 1: Rename ErrorStateView → InlineErrorView

**Files:**
- Rename: `TheRecruitingCompass/Shared/Components/ErrorStateView.swift` → `InlineErrorView.swift`
- Modify: `TheRecruitingCompass/Features/Coaches/Views/CoachDetailView.swift`
- Modify: `TheRecruitingCompass/Features/Schools/Views/SchoolDetailView.swift`
- Modify: `TheRecruitingCompass/Features/Offers/Views/OfferDetailView.swift`
- Modify: `TheRecruitingCompass/Features/Interactions/Views/InteractionDetailView.swift`

**Step 1: Rename the file on disk**

```bash
mv TheRecruitingCompass/Shared/Components/ErrorStateView.swift \
   TheRecruitingCompass/Shared/Components/InlineErrorView.swift
```

**Step 2: Rename the struct inside the file**

Open `Shared/Components/InlineErrorView.swift`. The file currently contains `struct ErrorStateView`. Change every occurrence of `ErrorStateView` to `InlineErrorView`. The file should end up like this:

```swift
import SwiftUI

struct InlineErrorView: View {
  let message: String
  let icon: String
  let onRetry: (() -> Void)?
  let retryAccessibilityHint: String?

  init(
    message: String,
    icon: String = "exclamationmark.triangle",
    onRetry: (() -> Void)? = nil,
    retryAccessibilityHint: String? = nil
  ) {
    self.message = message
    self.icon = icon
    self.onRetry = onRetry
    self.retryAccessibilityHint = retryAccessibilityHint
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(Color.errorRed)
        .accessibilityHidden(true)

      Text(message)
        .font(.body)
        .foregroundStyle(Color.secondaryText)
        .multilineTextAlignment(.center)

      if let onRetry {
        Button("Retry", action: onRetry)
          .buttonStyle(.borderedProminent)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel("Retry")
          .accessibilityHint(retryAccessibilityHint ?? "Attempts to load again")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

#Preview {
  VStack(spacing: 40) {
    InlineErrorView(message: "Unable to load coach details")
    InlineErrorView(message: "Network connection failed", icon: "wifi.slash")
    InlineErrorView(message: "Something went wrong")
  }
}
```

**Step 3: Update call sites**

In each of these 4 files, find `ErrorStateView(` and replace with `InlineErrorView(`. No other changes — the initializer signature is identical.

- `Features/Coaches/Views/CoachDetailView.swift`
- `Features/Schools/Views/SchoolDetailView.swift`
- `Features/Offers/Views/OfferDetailView.swift`
- `Features/Interactions/Views/InteractionDetailView.swift`

**Step 4: Build to verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no `error:` lines.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename ErrorStateView to InlineErrorView"
```

---

## Task 2: AppError Enum + Tests

**Files:**
- Create: `TheRecruitingCompass/Shared/Components/AppError.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/AppErrorTests.swift`

**Step 1: Write the failing tests**

Create `TheRecruitingCompassTests/Shared/Components/AppErrorTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class AppErrorTests: XCTestCase {

    // MARK: - init(statusCode:)

    func testStatusCode401MapsToUnauthorized() {
        XCTAssertEqual(AppError(statusCode: 401), .unauthorized)
    }

    func testStatusCode403MapsToForbidden() {
        XCTAssertEqual(AppError(statusCode: 403), .forbidden)
    }

    func testStatusCode404MapsToNotFound() {
        XCTAssertEqual(AppError(statusCode: 404), .notFound)
    }

    func testStatusCode500MapsToServerError() {
        if case .serverError(let code) = AppError(statusCode: 500) {
            XCTAssertEqual(code, 500)
        } else {
            XCTFail("Expected .serverError(500)")
        }
    }

    func testStatusCode502MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 502), .serviceUnavailable)
    }

    func testStatusCode503MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 503), .serviceUnavailable)
    }

    func testStatusCode504MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 504), .serviceUnavailable)
    }

    func testUnknownStatusCodeMapsToUnknown() {
        XCTAssertEqual(AppError(statusCode: 418), .unknown)
    }

    // MARK: - init(from: Error)

    func testNotConnectedToInternetMapsToNetworkOffline() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(AppError(from: error), .networkOffline)
    }

    func testNetworkConnectionLostMapsToNetworkOffline() {
        let error = URLError(.networkConnectionLost)
        XCTAssertEqual(AppError(from: error), .networkOffline)
    }

    func testTimedOutMapsToServiceUnavailable() {
        let error = URLError(.timedOut)
        XCTAssertEqual(AppError(from: error), .serviceUnavailable)
    }

    func testUnknownURLErrorMapsToUnknown() {
        let error = URLError(.badURL)
        XCTAssertEqual(AppError(from: error), .unknown)
    }

    func testNonURLErrorMapsToUnknown() {
        let error = NSError(domain: "test", code: 999)
        XCTAssertEqual(AppError(from: error), .unknown)
    }

    // MARK: - Config

    func test404ConfigHeadline() {
        XCTAssertEqual(AppError.notFound.config.headline, "That page ran a different route.")
    }

    func test401ConfigHeadline() {
        XCTAssertEqual(AppError.unauthorized.config.headline, "You'll need to sign in first.")
    }

    func test403ConfigHeadline() {
        XCTAssertEqual(AppError.forbidden.config.headline, "This isn't your playbook.")
    }

    func test500ConfigHeadline() {
        XCTAssertEqual(AppError.serverError(statusCode: 500).config.headline, "We fumbled. It's on us.")
    }

    func testServiceUnavailableConfigHeadline() {
        XCTAssertEqual(AppError.serviceUnavailable.config.headline, "We're taking a timeout.")
    }

    func testNetworkOfflineConfigHeadline() {
        XCTAssertEqual(AppError.networkOffline.config.headline, "Looks like the connection dropped.")
    }

    func testUnknownConfigHeadline() {
        XCTAssertEqual(AppError.unknown.config.headline, "Something went sideways.")
    }

    func test403HasNoSecondaryButton() {
        XCTAssertNil(AppError.forbidden.config.secondaryButtonLabel)
    }

    func test404HasSecondaryButton() {
        XCTAssertNotNil(AppError.notFound.config.secondaryButtonLabel)
    }

    func test500ConfigStatusCode() {
        XCTAssertEqual(AppError.serverError(statusCode: 503).config.statusCode, 503)
    }

    func testNotFoundHasNoStatusCode() {
        XCTAssertNil(AppError.notFound.config.statusCode)
    }

    // MARK: - Identifiable

    func testServerErrorIdIncludesStatusCode() {
        XCTAssertEqual(AppError.serverError(statusCode: 500).id, "serverError-500")
    }

    func testNotFoundId() {
        XCTAssertEqual(AppError.notFound.id, "notFound")
    }
}
```

**Step 2: Run to verify tests fail**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppErrorTests 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD FAILED` (type not found). If it compiles somehow, the tests must FAIL.

**Step 3: Create AppError.swift**

Create `TheRecruitingCompass/Shared/Components/AppError.swift`:

```swift
import SwiftUI

enum AppError: Equatable, Identifiable {
    case notFound
    case unauthorized
    case forbidden
    case serverError(statusCode: Int)
    case serviceUnavailable
    case networkOffline
    case sessionExpired
    case unknown

    var id: String {
        switch self {
        case .notFound: return "notFound"
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .serverError(let code): return "serverError-\(code)"
        case .serviceUnavailable: return "serviceUnavailable"
        case .networkOffline: return "networkOffline"
        case .sessionExpired: return "sessionExpired"
        case .unknown: return "unknown"
        }
    }

    init(from error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                self = .networkOffline
            case .timedOut:
                self = .serviceUnavailable
            default:
                self = .unknown
            }
        } else {
            self = .unknown
        }
    }

    init(statusCode: Int) {
        switch statusCode {
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 500: self = .serverError(statusCode: 500)
        case 502, 503, 504: self = .serviceUnavailable
        default: self = .unknown
        }
    }

    var config: AppErrorConfig {
        switch self {
        case .notFound:
            return AppErrorConfig(
                headline: "That page ran a different route.",
                body: "We couldn't find what you're looking for. It may have moved, or the link might be off.",
                iconName: "magnifyingglass",
                iconBackground: Color(hex: "EFF6FF"),
                iconForeground: Color(hex: "3B82F6"),
                primaryButtonLabel: "Go to Dashboard",
                secondaryButtonLabel: "Search Schools",
                statusCode: nil
            )
        case .unauthorized:
            return AppErrorConfig(
                headline: "You'll need to sign in first.",
                body: "This page requires an account. Log in to pick up where you left off.",
                iconName: "lock.fill",
                iconBackground: Color(hex: "FFFBEB"),
                iconForeground: Color(hex: "F59E0B"),
                primaryButtonLabel: "Sign In",
                secondaryButtonLabel: "Create Account",
                statusCode: nil
            )
        case .forbidden:
            return AppErrorConfig(
                headline: "This isn't your playbook.",
                body: "You don't have access to this page. If you think that's a mistake, reach out to the account owner.",
                iconName: "shield.slash.fill",
                iconBackground: Color(hex: "FEF2F2"),
                iconForeground: Color(hex: "EF4444"),
                primaryButtonLabel: "Go to Dashboard",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .serverError(let code):
            return AppErrorConfig(
                headline: "We fumbled. It's on us.",
                body: "Something went wrong on our end. Your data is safe, but we hit an unexpected snag. Our team has been notified.",
                iconName: "exclamationmark.triangle.fill",
                iconBackground: Color(hex: "FEF2F2"),
                iconForeground: Color(hex: "EF4444"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: code
            )
        case .serviceUnavailable:
            return AppErrorConfig(
                headline: "We're taking a timeout.",
                body: "Something on our end isn't cooperating right now. Your recruiting data is safe — we're just temporarily offline. Try again in a few minutes.",
                iconName: "clock.fill",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: nil
            )
        case .networkOffline:
            return AppErrorConfig(
                headline: "Looks like the connection dropped.",
                body: "We can't reach our servers right now. Check your connection and try again.",
                iconName: "wifi.slash",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .sessionExpired:
            return AppErrorConfig(
                headline: "You've been away for a while.",
                body: "For your security, we signed you out after a period of inactivity. Log back in to continue.",
                iconName: "clock.badge.exclamationmark.fill",
                iconBackground: Color(hex: "FFFBEB"),
                iconForeground: Color(hex: "F59E0B"),
                primaryButtonLabel: "Sign In Again",
                secondaryButtonLabel: nil,
                statusCode: nil
            )
        case .unknown:
            return AppErrorConfig(
                headline: "Something went sideways.",
                body: "We hit an unexpected snag. Your data is safe — try refreshing or head back home.",
                iconName: "exclamationmark.circle.fill",
                iconBackground: Color(hex: "F8FAFC"),
                iconForeground: Color(hex: "64748B"),
                primaryButtonLabel: "Try Again",
                secondaryButtonLabel: "Go Home",
                statusCode: nil
            )
        }
    }
}

struct AppErrorConfig {
    let headline: String
    let body: String
    let iconName: String
    let iconBackground: Color
    let iconForeground: Color
    let primaryButtonLabel: String
    let secondaryButtonLabel: String?
    let statusCode: Int?
}
```

**Step 4: Run tests to verify they pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppErrorTests 2>&1 | grep -E "Test Case|PASS|FAIL|error:"
```

Expected: All `Test Case ... passed`.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add AppError enum with config and HTTP/URLError initializers"
```

---

## Task 3: AppErrorView

**Files:**
- Create: `TheRecruitingCompass/Shared/Components/AppErrorView.swift`

> Note: SwiftUI views aren't unit-tested here — the build + preview verify correctness. The `AppError.config` logic was already tested in Task 2.

**Step 1: Create AppErrorView.swift**

Create `TheRecruitingCompass/Shared/Components/AppErrorView.swift`:

```swift
import SwiftUI

struct AppErrorView: View {
    let error: AppError
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    @State private var announceError = false

    private var config: AppErrorConfig { error.config }

    var body: some View {
        ZStack {
            LinearGradient.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                logo

                card

                supportLink
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: config.headline)
        }
    }

    // MARK: - Sub-views

    private var logo: some View {
        Image("LogoStacked")
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .shadow(radius: 8)
            .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(spacing: 20) {
            iconCircle

            Text(config.headline)
                .font(.title2.bold())
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(config.body)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)

            if let code = config.statusCode {
                Text("Error \(code)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }

            primaryButton

            if let secondaryLabel = config.secondaryButtonLabel, let onSecondary {
                secondaryButton(label: secondaryLabel, action: onSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(config.iconBackground)
                .frame(width: 56, height: 56)

            Image(systemName: config.iconName)
                .font(.title2)
                .foregroundStyle(config.iconForeground)
        }
        .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Text(config.primaryButtonLabel)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(LinearGradient.primaryButton)
                .cornerRadius(8)
        }
        .accessibilityLabel(config.primaryButtonLabel)
    }

    private func secondaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.primary)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(8)
        }
        .accessibilityLabel(label)
    }

    private var supportLink: some View {
        Link(
            "Need help? Contact support",
            destination: URL(string: "mailto:support@therecruitingcompass.com")!
        )
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .accessibilityLabel("Contact support")
        .accessibilityHint("Opens email to support@therecruitingcompass.com")
    }
}

#Preview("404 Not Found") {
    AppErrorView(
        error: .notFound,
        onPrimary: {},
        onSecondary: {}
    )
}

#Preview("500 Server Error") {
    AppErrorView(
        error: .serverError(statusCode: 500),
        onPrimary: {},
        onSecondary: {}
    )
}

#Preview("Network Offline") {
    AppErrorView(
        error: .networkOffline,
        onPrimary: {},
        onSecondary: nil
    )
}

#Preview("401 Unauthorized") {
    AppErrorView(
        error: .unauthorized,
        onPrimary: {},
        onSecondary: {}
    )
}
```

**Step 2: Build to verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add AppErrorView full-screen branded error component"
```

---

## Task 4: SessionExpiredSheet

**Files:**
- Create: `TheRecruitingCompass/Shared/Components/SessionExpiredSheet.swift`

**Step 1: Create SessionExpiredSheet.swift**

Create `TheRecruitingCompass/Shared/Components/SessionExpiredSheet.swift`:

```swift
import SwiftUI

/// Presented as a `.sheet` when a background token refresh returns a 401.
/// Use instead of `AppErrorView` to avoid replacing the full screen when the
/// user may have unsaved form state.
struct SessionExpiredSheet: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: "F59E0B"))
                    .accessibilityHidden(true)

                Text("You've been away for a while.")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("For your security, we signed you out after a period of inactivity. Log back in to continue.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSignIn) {
                Text("Sign In Again")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(LinearGradient.primaryButton)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Sign in again")
        }
        .padding(32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: "You've been away for a while. Please sign in again."
            )
        }
    }
}

#Preview {
    Text("Behind the sheet")
        .sheet(isPresented: .constant(true)) {
            SessionExpiredSheet(onSignIn: {})
        }
}
```

**Step 2: Build to verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add SessionExpiredSheet for background auth expiry"
```

---

## Task 5: Full Test Suite Pass

**Step 1: Run all unit tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
```

Expected: All suites pass. If any test fails that was previously passing, fix it before proceeding.

**Step 2: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve any test failures from error page refactor"
```

---

## Usage Reference (for future call sites)

```swift
// Full-screen fatal error
.fullScreenCover(item: $viewModel.appError) { error in
    AppErrorView(
        error: error,
        onPrimary: { Task { await viewModel.retry() } },
        onSecondary: { router.navigateToDashboard() }
    )
}

// Inline tab content error
if let error = viewModel.appError {
    AppErrorView(
        error: error,
        onPrimary: { Task { await viewModel.load() } },
        onSecondary: nil
    )
} else {
    // normal content
}

// Session expired sheet
.sheet(isPresented: $viewModel.showSessionExpired) {
    SessionExpiredSheet(onSignIn: { router.navigateToLogin() })
}

// Map an HTTP error in a ViewModel
} catch {
    if let httpError = error as? HTTPError {
        appError = AppError(statusCode: httpError.statusCode)
    } else {
        appError = AppError(from: error)
    }
}
```
