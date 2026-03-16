# SwiftUI Modernization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all custom implementations that duplicate built-in SwiftUI/Foundation capabilities, removing UIKit dependencies and aligning with modern iOS 18+ API patterns.

**Architecture:** Each task is independent. No shared state changes cross task boundaries. Every task ends with a clean build (`make build`). Tests that cover changed code are updated in the same commit.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts (already imported in `PerformanceChartView`), Foundation `RelativeDateTimeFormatter`, iOS 18 `Tab` API, SwiftUI `sensoryFeedback`, `AccessibilityNotification`

**Build command (run from project dir):**
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|warning:|BUILD"
```

**Test command:**
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed|error:"
```

---

## Path Reference

All source files live under this double-nested root — do not drop a level:
```
TheRecruitingCompass/TheRecruitingCompass/   ← source root
TheRecruitingCompass/TheRecruitingCompassTests/  ← test root
```

---

## Chunk 1: Structural Fixes

### Task 1: `@Entry` Macro for `TabEnvironment`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/TabEnvironment.swift`

The legacy `EnvironmentKey` boilerplate (private struct + extension) is replaced by the `@Entry` macro (Swift 5.9 / iOS 17+).

- [ ] **Step 1: Replace the EnvironmentKey boilerplate**

Open `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/TabEnvironment.swift`.

Replace the entire file with:

```swift
import SwiftUI

enum AppTab: Int {
  case dashboard = 0
  case schools = 1
  case coaches = 2
  case interactions = 3
  case more = 4
}

extension EnvironmentValues {
  @Entry var switchTab: (AppTab) -> Void = { _ in }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`, no errors.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/TabEnvironment.swift
git commit -m "refactor: replace EnvironmentKey boilerplate with @Entry macro"
```

---

### Task 2: Fix `AdaptiveHStackVStack` Closure Storage

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Forms/AdaptiveHStackVStack.swift`

The view stores `@ViewBuilder let content: () -> Content` — an escaping closure. The correct pattern stores the built view value, not the builder closure.

- [ ] **Step 1: Change closure storage to built-view storage**

Replace the struct body:

```swift
// Before
struct AdaptiveHStackVStack<Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let content: () -> Content

  init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
    self.spacing = spacing
    self.content = content
  }

  var body: some View {
    ViewThatFits {
      HStack(spacing: spacing) {
        content()
      }
      VStack(spacing: spacing) {
        content()
      }
    }
  }
}
```

```swift
// After
struct AdaptiveHStackVStack<Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let content: Content

  init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    ViewThatFits {
      HStack(spacing: spacing) {
        content
      }
      VStack(spacing: spacing) {
        content
      }
    }
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`, no errors.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Forms/AdaptiveHStackVStack.swift
git commit -m "refactor: store built view instead of escaping ViewBuilder closure in AdaptiveHStackVStack"
```

---

### Task 3: Fix `Binding(get:set:)` Anti-Patterns

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Documents/Views/DocumentViewerView.swift`

Two places construct `Binding(get:set:)` in view bodies. Because both targets are `@Observable` classes, `@Bindable` gives clean direct bindings, and side effects on dismiss belong in `onDismiss:`, not the setter.

- [ ] **Step 1: Fix the Face ID alert binding in `TheRecruitingCompassApp.swift`**

Find the `.alert("Enable Face ID?", ...)` modifier. It currently has:

```swift
.alert("Enable Face ID?", isPresented: Binding(
    get: { authManager.pendingBiometricEnrollmentOffer },
    set: { authManager.pendingBiometricEnrollmentOffer = $0 }
))
```

`authManager` is already stored as `@State private var authManager = AuthManager.shared`. Because it's `@Observable`, wrap it with `@Bindable` locally:

```swift
// Replace the full .alert modifier block
let bindableAuth = Bindable(authManager)
// ... then pass:
.alert("Enable Face ID?", isPresented: bindableAuth.pendingBiometricEnrollmentOffer) {
```

However, since `WindowGroup.body` is a computed property, the cleanest zero-boilerplate approach is to bind via a local `@Bindable` wrapper inline. The existing pattern can also be replaced by adding a separate `@Bindable` computed property or a dedicated subview. The simplest correct fix:

```swift
// Inside WindowGroup body, add @Bindable to access the stored @State
// authManager is @State var authManager = AuthManager.shared
// @State vars on @Observable give us Binding via $:

.alert("Enable Face ID?", isPresented: $authManager.pendingBiometricEnrollmentOffer) {
    Button("Enable") {
        do {
            try authManager.enableBiometrics()
        } catch {
            // Keychain write failed — biometrics silently not enabled.
        }
        authManager.pendingBiometricEnrollmentOffer = false
    }
    Button("Not Now", role: .cancel) {
        authManager.pendingBiometricEnrollmentOffer = false
    }
} message: {
    Text("Sign in quickly and securely with Face ID on future visits.")
}
```

Note: `$authManager` works here because `authManager` is declared `@State private var authManager = AuthManager.shared` at the `App` struct level. `@State` on an `@Observable` class exposes bindings via `$`.

- [ ] **Step 2: Fix the share sheet binding in `DocumentViewerView.swift`**

Find the `.sheet(isPresented: Binding(get:set:) ...)` block (around line 130). The setter runs `viewModel.downloadedFileURL = nil` on dismiss.

```swift
// Before
.sheet(isPresented: Binding(
    get: { viewModel.isShareSheetPresented },
    set: {
        viewModel.isShareSheetPresented = $0
        if !$0 { viewModel.downloadedFileURL = nil }
    }
))

// After — side effect moves to onDismiss
// viewModel is @State or injected as @Observable, so use @Bindable
.sheet(
    isPresented: Bindable(viewModel).isShareSheetPresented,
    onDismiss: { viewModel.downloadedFileURL = nil }
) {
    // existing sheet content unchanged
}
```

Check how `viewModel` is declared at the top of `DocumentViewerView`. If it's `@State var viewModel = DocumentViewerViewModel(...)`, then `$viewModel.isShareSheetPresented` works directly. If it's passed in, use `Bindable(viewModel).isShareSheetPresented`. Use whichever applies.

- [ ] **Step 3: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`, no errors.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Documents/Views/DocumentViewerView.swift
git commit -m "refactor: replace Binding(get:set:) with direct Observable bindings"
```

---

## Chunk 2: Remove UIKit Dependencies

### Task 4: Replace `HapticFeedbackManager` with `.sensoryFeedback()`

**Files:**
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/HapticFeedbackManager.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/InteractionDetailView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/AddInteractionView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/Views/EventsListView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Events/ViewModels/EventDetailViewModel.swift`

**Background:** `.sensoryFeedback()` is a SwiftUI view modifier that fires haptics when a value changes. It requires a state property to watch. For imperative triggers (e.g., "fire success on button tap"), use a counter `@State var hapticSuccessTrigger = 0` incremented at the call site, then attach `.sensoryFeedback(.success, trigger: hapticSuccessTrigger)` once to the root view. `EventDetailViewModel` currently drives haptics from the ViewModel — the fix is to expose observable trigger properties the view watches.

The pattern to use throughout:

```swift
// In the view — declare triggers
@State private var hapticSuccessTrigger = 0
@State private var hapticErrorTrigger = 0
@State private var hapticWarningTrigger = 0

// Attach once to root view
.sensoryFeedback(.success, trigger: hapticSuccessTrigger)
.sensoryFeedback(.error, trigger: hapticErrorTrigger)
.sensoryFeedback(.impact(weight: .light), trigger: hapticLightTrigger)
.sensoryFeedback(.warning, trigger: hapticWarningTrigger)

// At call sites — replace HapticFeedbackManager.shared.success() with:
hapticSuccessTrigger += 1
```

For `EventDetailViewModel`, add observable properties so the view can react:

```swift
// In EventDetailViewModel
var hapticSuccessTrigger = 0
var hapticErrorTrigger = 0
var hapticWarningTrigger = 0

// Replace haptics.success() with:
hapticSuccessTrigger += 1
// Replace haptics.error() with:
hapticErrorTrigger += 1
// Replace haptics.warning() with:
hapticWarningTrigger += 1

// Remove: private let haptics = HapticFeedbackManager.shared
```

Then in the view that owns `EventDetailViewModel`, attach:

```swift
.sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
.sensoryFeedback(.error, trigger: viewModel.hapticErrorTrigger)
.sensoryFeedback(.warning, trigger: viewModel.hapticWarningTrigger)
```

- [ ] **Step 1: Update `InteractionDetailView.swift`**

Add `@State` trigger properties after the existing `@State` declarations:

```swift
@State private var hapticWarningTrigger = 0
@State private var hapticSuccessTrigger = 0
@State private var hapticErrorTrigger = 0
```

Replace each `HapticFeedbackManager.shared.warning()` → `hapticWarningTrigger += 1`
Replace each `HapticFeedbackManager.shared.success()` → `hapticSuccessTrigger += 1`
Replace each `HapticFeedbackManager.shared.error()` → `hapticErrorTrigger += 1`

Attach to the root `body` view (e.g., the outermost `NavigationStack` or `List`):

```swift
.sensoryFeedback(.warning, trigger: hapticWarningTrigger)
.sensoryFeedback(.success, trigger: hapticSuccessTrigger)
.sensoryFeedback(.error, trigger: hapticErrorTrigger)
```

- [ ] **Step 2: Update `AddInteractionView.swift`**

Same pattern. Find the three `HapticFeedbackManager.shared.*` calls and replace:
- `.success()` → `hapticSuccessTrigger += 1`
- `.error()` → `hapticErrorTrigger += 1`

Add `@State` triggers and attach `.sensoryFeedback()` modifiers to root view.

- [ ] **Step 3: Update `EventsListView.swift`**

Two calls in this view file:
- Line 69: `HapticFeedbackManager.shared.warning()` → `hapticWarningTrigger += 1`
- Line 233: `HapticFeedbackManager.shared.lightImpact()` → `hapticLightTrigger += 1`

Add triggers and attach:

```swift
.sensoryFeedback(.warning, trigger: hapticWarningTrigger)
.sensoryFeedback(.impact(weight: .light), trigger: hapticLightTrigger)
```

- [ ] **Step 4: Update `EventDetailViewModel.swift`**

Remove: `private let haptics = HapticFeedbackManager.shared`

Add observable trigger properties (these are `@Observable` class properties so views react automatically):

```swift
var hapticSuccessTrigger = 0
var hapticErrorTrigger = 0
var hapticWarningTrigger = 0
```

Replace all `haptics.success()` → `hapticSuccessTrigger += 1`, etc. (17 occurrences — use find-and-replace carefully).

In the view that owns this ViewModel (find the view that creates `EventDetailViewModel`), attach `.sensoryFeedback()` modifiers watching `viewModel.hapticSuccessTrigger`, etc.

- [ ] **Step 5: Delete `HapticFeedbackManager.swift`**

```bash
rm TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/HapticFeedbackManager.swift
```

- [ ] **Step 6: Verify build — no UIKit haptic references remain**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Also confirm no remaining references:

```bash
grep -r "HapticFeedbackManager\|UIImpactFeedbackGenerator\|UINotificationFeedbackGenerator\|UISelectionFeedbackGenerator" TheRecruitingCompass/
```

Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: replace HapticFeedbackManager with SwiftUI .sensoryFeedback() modifier"
```

---

### Task 5: Replace UIKit Accessibility Posting with `AccessibilityNotification`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/AccessibilityAnnouncing.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/AppErrorView.swift`

`UIAccessibility.post(notification: .announcement, argument:)` is UIKit. SwiftUI 17+ has `AccessibilityNotification.Announcement("...").post()` which lives in `SwiftUI`, not `UIKit`. `AppErrorView` calls UIKit directly from `onAppear`. `UIAccessibilityAnnouncer` wraps it. Both need updating.

`UIAccessibilityAnnouncer.announceWithFeedback()` also fires UIKit haptics — those should now use `sensoryFeedback` via the view layer. Since `UIAccessibilityAnnouncer` is used from ViewModels (not views), the haptic part should be removed from the announcer and handled by the view observing the same outcome.

- [ ] **Step 1: Rewrite `AccessibilityAnnouncing.swift`**

```swift
import SwiftUI

/// Protocol for announcing messages to VoiceOver users
protocol AccessibilityAnnouncing {
  func announce(_ message: String)
}

/// Default implementation using SwiftUI's AccessibilityNotification
final class AccessibilityAnnouncer: AccessibilityAnnouncing {
  func announce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
  }
}

/// Mock implementation for testing
final class MockAccessibilityAnnouncer: AccessibilityAnnouncing {
  var announcedMessages: [String] = []

  func announce(_ message: String) {
    announcedMessages.append(message)
  }

  func reset() {
    announcedMessages.removeAll()
  }
}
```

Note: `announceWithFeedback(_:success:)` is removed. The haptic side of announcements is now the view's responsibility via `.sensoryFeedback()`. Any call sites using `announceWithFeedback` must be updated to call `announce` only. Search for `announceWithFeedback` and replace with `announce`.

The class is also renamed from `UIAccessibilityAnnouncer` to `AccessibilityAnnouncer` to remove the UIKit-connoting prefix. Update all instantiation sites.

- [ ] **Step 2: Find and update all `announceWithFeedback` and `UIAccessibilityAnnouncer` call sites**

```bash
grep -rn "announceWithFeedback\|UIAccessibilityAnnouncer" \
  /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/
```

For each result:
- Replace `UIAccessibilityAnnouncer()` → `AccessibilityAnnouncer()`
- Replace `.announceWithFeedback(msg, success: true)` → `.announce(msg)`
- Replace `.announceWithFeedback(msg, success: false)` → `.announce(msg)`

- [ ] **Step 3: Fix `AppErrorView.swift`**

Find `onAppear` in `AppErrorView.swift`:

```swift
// Before
.onAppear {
    UIAccessibility.post(notification: .announcement, argument: config.headline)
}
```

```swift
// After — remove UIKit import if present, use SwiftUI
.onAppear {
    AccessibilityNotification.Announcement(config.headline).post()
}
```

Remove `import UIKit` from `AppErrorView.swift` if it was only there for this call.

- [ ] **Step 4: Remove `import UIKit` from `AccessibilityAnnouncing.swift`**

The new file imports `SwiftUI` only. Confirm no remaining `UIKit` imports in these files.

- [ ] **Step 5: Verify no UIKit accessibility calls remain**

```bash
grep -rn "UIAccessibility\|import UIKit" \
  TheRecruitingCompass/TheRecruitingCompass/Core/Protocols/ \
  TheRecruitingCompass/TheRecruitingCompass/Shared/Components/AppErrorView.swift
```

Expected: no output.

- [ ] **Step 6: Verify build and tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

Tests involve `MockAccessibilityAnnouncer` — confirm those still compile and pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: replace UIKit UIAccessibility with SwiftUI AccessibilityNotification"
```

---

## Chunk 3: Tab API Migration

### Task 6: Migrate `MainTabView` to iOS 18 `Tab` API

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`

The current code uses the deprecated `.tabItem {}` + `.tag()` pattern. iOS 18 replaces it with `Tab("Label", systemImage: "icon", value: .enumCase) { content }`.

**Key differences from current code:**
- `Tab` takes the label and icon as parameters — no separate `.tabItem {}` needed
- `.tag()` is replaced by the `value:` parameter
- `.badge()` attaches directly to `Tab`
- The `@Environment(\.symbolVariants, .none)` hack is no longer needed — Tab renders its own icons
- `.accessibilityLabel()` on the container is replaced by the `Tab` label itself (first parameter)
- `selection:` binding on `TabView` works the same way

- [ ] **Step 1: Rewrite `MainTabView.body` using `Tab` API**

```swift
var body: some View {
  TabView(selection: $selectedTab) {
    Tab("Dashboard", systemImage: "house", value: AppTab.dashboard) {
      NavigationStack {
        DashboardView(viewModel: dashboardViewModel)
          .activityNavigation()
          .navigationDestination(for: DashboardDestination.self) { destination in
            dashboardDestinationView(for: destination)
          }
      }
    }

    Tab("Schools", systemImage: "building.2", value: AppTab.schools) {
      SchoolsListView()
    }

    Tab("Coaches", systemImage: "person.2", value: AppTab.coaches) {
      CoachesListView()
    }

    Tab("Interactions", systemImage: "bubble.left.and.bubble.right", value: AppTab.interactions) {
      InteractionsListView()
    }

    Tab("More", systemImage: "ellipsis.circle", value: AppTab.more) {
      MoreMenuView(notificationsViewModel: notificationsViewModel)
    }
    .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
  }
  .environment(\.switchTab, { selectedTab = $0 })
  .task {
    await notificationsViewModel.fetchNotifications()
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`, no errors.

- [ ] **Step 3: Verify tests pass**

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift
git commit -m "refactor: migrate TabView from deprecated tabItem to iOS 18 Tab API"
```

---

## Chunk 4: Delete Dead Code and Custom Formatters

### Task 7: Delete `CountdownTimer.swift` (Unused Dead Code)

**Files:**
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/CountdownTimer.swift`

The function `startCountdownTimer(config:)` has zero call sites in the entire codebase. The file is dead code.

- [ ] **Step 1: Confirm no callers**

```bash
grep -rn "startCountdownTimer\|CountdownTimerConfig" \
  /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/
```

Expected: only the definition file itself appears.

- [ ] **Step 2: Delete the file**

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/CountdownTimer.swift
```

- [ ] **Step 3: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: delete unused CountdownTimer utility"
```

---

### Task 8: Delete `RelativeTimeFormatter`, Use `Text(.relative)`

**Files:**
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/RelativeTimeFormatter.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed/Components/ActivityEventItem.swift`
- Delete: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Utilities/RelativeTimeFormatterTests.swift`

`RelativeTimeFormatter.format(_:)` is a hand-rolled "Xm ago / Xh ago / Xd ago" formatter. SwiftUI's `Text(date, format: .relative(presentation: .named))` does this natively — auto-updates while the view is on screen, fully localized.

**Important:** The formatter is used in two places in `ActivityEventItem.swift` — once in the `body` to display the timestamp, and once in the `accessibilityLabel` computed property to build the VoiceOver string. The accessibility label string cannot use `Text(_, format:)` directly since it returns a `String`. For the accessibility label, use `Foundation.RelativeDateTimeFormatter` to generate the string.

- [ ] **Step 1: Update `ActivityEventItem.swift` — display timestamp**

Find:
```swift
Text(RelativeTimeFormatter.format(event.timestamp))
```

Replace with:
```swift
Text(event.timestamp, format: .relative(presentation: .named))
```

Also remove `.font(.caption).foregroundStyle(Color.tertiaryText)` from the same chain if needed — add it back after the format call:

```swift
Text(event.timestamp, format: .relative(presentation: .named))
    .font(.caption)
    .foregroundStyle(Color.tertiaryText)
```

- [ ] **Step 2: Update `ActivityEventItem.swift` — accessibility label**

Find `accessibilityLabel` computed property which calls `RelativeTimeFormatter.format(event.timestamp)`. Replace with:

```swift
private var accessibilityLabel: String {
    let relativeTime = RelativeDateTimeFormatter().localizedString(for: event.timestamp, relativeTo: Date())
    var parts: [String] = []
    parts.append(event.type.label)
    parts.append(event.title)
    if !event.description.isEmpty {
        parts.append(event.description)
    }
    parts.append(relativeTime)
    return parts.joined(separator: ", ")
}
```

`RelativeDateTimeFormatter` is from `Foundation` (already imported transitively). No new imports needed.

- [ ] **Step 3: Confirm no other callers of `RelativeTimeFormatter`**

```bash
grep -rn "RelativeTimeFormatter" \
  /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/
```

Expected: only the definition file and test file.

- [ ] **Step 4: Delete the formatter and its tests**

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/RelativeTimeFormatter.swift
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompassTests/Shared/Utilities/RelativeTimeFormatterTests.swift
```

- [ ] **Step 5: Verify build and tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

Note: `ActivityEventItemAccessibilityTests.swift` tests the accessibility label — those tests may need updating if they assert the exact "Xm ago" string format. Check and update to use `RelativeDateTimeFormatter` output or loosen the assertion.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: replace RelativeTimeFormatter with Text(.relative) and RelativeDateTimeFormatter"
```

---

## Chunk 5: Chart and Loading UI Modernization

### Task 9: Replace `MiniBarChart` `GeometryReader` with Swift Charts

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/MiniBarChart.swift`

`MiniBarChart` uses `GeometryReader` to compute bar heights and spacing manually. Swift Charts (`import Charts`) is already a dependency (used in `PerformanceChartView.swift`). A `Chart { BarMark }` implementation is simpler, consistent, and avoids `GeometryReader`.

The current public interface is:
```swift
MiniBarChart(values: [Double], maxValue: Double)
```

The new implementation maintains this interface. Since this is a decorative chart (`.accessibilityHidden(true)`), we don't need to worry about chart accessibility labels.

- [ ] **Step 1: Rewrite `MiniBarChart.swift`**

```swift
import SwiftUI
import Charts

struct MiniBarChart: View {
  let values: [Double]
  let maxValue: Double

  var body: some View {
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      BarMark(
        x: .value("Index", index),
        y: .value("Value", value)
      )
      .foregroundStyle(Color.accentBlue)
      .cornerRadius(3)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: 0...max(maxValue, 1))
    .accessibilityHidden(true)
  }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Performance/Components/MiniBarChart.swift
git commit -m "refactor: replace MiniBarChart GeometryReader with Swift Charts BarMark"
```

---

### Task 10: Replace Skeleton/Shimmer with `.redacted(reason: .placeholder)` Where Applicable

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift` (line ~181)
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/StatCardSkeleton.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/ListRowSkeleton.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/CardSkeleton.swift`
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/ShimmerModifier.swift`

**Strategy:** `.redacted(reason: .placeholder)` works best when you have the real view that you can show in placeholder state. `StatCardSkeleton` has a concrete matching view (`StatCard`) — replace it. `ListRowSkeleton` and `CardSkeleton` are generic grey-shape skeletons that don't correspond to a single known view. For those two, replace `.shimmer()` (which uses a `@State` opacity animation) with a direct inline `@State` + `.animation(.easeInOut.repeatForever, value:)` — this removes the dependency on `ShimmerModifier` so it can be deleted.

**Callers found:**
- `.shimmer()` used in: `ListRowSkeleton.swift:26`, `CardSkeleton.swift:36`
- `StatCardSkeleton` used in: `DashboardView.swift:181` (inside `DashboardLoadingSection`)
- `StatCard` signature: `StatCard(title:count:subtitle:description:icon:gradientColors:isEnabled:destination:)`

- [ ] **Step 1: Replace `StatCardSkeleton` in `DashboardView.swift` with real `StatCard` + `.redacted`**

Find `DashboardLoadingSection` in `DashboardView.swift`:

```swift
// Before
private struct DashboardLoadingSection: View {
  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(0..<6, id: \.self) { _ in
        StatCardSkeleton()
      }
    }
  }
}
```

```swift
// After — show real StatCard shape with .redacted; gradient is hidden under redaction
private struct DashboardLoadingSection: View {
  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(0..<6, id: \.self) { _ in
        StatCard(
          title: "Loading",
          count: 0,
          subtitle: nil,
          description: nil,
          icon: "circle",
          gradientColors: [Color.Brand.slate100, Color.Brand.slate100],
          isEnabled: false,
          destination: nil
        )
        .redacted(reason: .placeholder)
      }
    }
  }
}
```

Note: `Color.Brand.slate100` is a known app color used throughout for skeleton states.

- [ ] **Step 2: Delete `StatCardSkeleton.swift`**

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/StatCardSkeleton.swift
```

- [ ] **Step 3: Update `ListRowSkeleton.swift` — inline animation, remove `.shimmer()`**

```swift
// Before
struct ListRowSkeleton: View {
  var body: some View {
    HStack(spacing: 12) { ... }
    .shimmer()
    ...
  }
}
```

```swift
// After
struct ListRowSkeleton: View {
  @State private var isAnimating = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color.Brand.slate100)
        .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 6) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(height: 14)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(width: 160, height: 12)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .opacity(isAnimating ? 0.4 : 0.8)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
      value: isAnimating
    )
    .onAppear { if !reduceMotion { isAnimating = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading")
    .accessibilityAddTraits(.updatesFrequently)
  }
}
```

- [ ] **Step 4: Update `CardSkeleton.swift` — same inline animation pattern**

Apply the same `@State private var isAnimating = false` + inline `.opacity` + `.animation` + `.onAppear` pattern, removing the `.shimmer()` call.

- [ ] **Step 5: Delete `ShimmerModifier.swift`**

Confirm no remaining callers:
```bash
grep -rn "\.shimmer()\|ShimmerModifier" \
  /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/
```

Expected: no output (only definition file, which you're about to delete).

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Shared/Components/ShimmerModifier.swift
```

- [ ] **Step 6: Verify build and tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: replace StatCardSkeleton with StatCard+.redacted, inline shimmer animations"
```

---

## Summary of Changes

| Task | Files Affected | Type | Status |
|---|---|---|---|
| 1. @Entry macro | `TabEnvironment.swift` | Simplify | ✅ Done |
| 2. AdaptiveHStackVStack closure | `AdaptiveHStackVStack.swift` | Fix | ✅ Done |
| 3. Binding(get:set:) | `TheRecruitingCompassApp.swift`, `DocumentViewerView.swift` | Fix | ✅ Done |
| 4. HapticFeedbackManager | Delete 1, modify 4 | Remove UIKit | ✅ Done |
| 5. UIAccessibility | `AccessibilityAnnouncing.swift`, `AppErrorView.swift` | Remove UIKit | ✅ Done |
| 6. Tab API | `MainTabView.swift` | Modernize | ✅ Done |
| 7. CountdownTimer | Delete 1 | Dead code | ✅ Done |
| 8. RelativeTimeFormatter | Delete 2, modify 1 | Remove custom | ✅ Done |
| 9. MiniBarChart | `MiniBarChart.swift` | Remove GeometryReader | ✅ Done |
| 10. Shimmer/Skeleton | Delete 2, modify callers | Remove custom | ✅ Done |
| 11. .searchable() | `NotificationsListView.swift`, delete `NotificationSearchBar.swift` | Remove custom | ⬜ Todo |
| 12. Swift Regex | `FormValidator.swift` | Modernize | ⬜ Todo |
| 13. .formatted() | `DateFormatting.swift` | Modernize | ⬜ Todo |

**End state:** No `UIKit` imports in view or component files. No custom implementations of things SwiftUI/Foundation provide. All iOS 18 API patterns in use.

---

## Chunk 6: Remaining Audit Items (2026-03-15)

### Task 11: Replace `NotificationSearchBar` with `.searchable()`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Views/NotificationsListView.swift`
- Delete: `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationSearchBar.swift`
- Delete: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Notifications/Accessibility/NotificationSearchBarAccessibilityTests.swift`

`NotificationSearchBar` is a custom HStack with a magnifying glass icon, TextField, and clear button. SwiftUI's `.searchable(text:prompt:)` (iOS 15+) renders the same UI natively, integrates with `NavigationStack` keyboard dismiss, and handles the clear button automatically.

The ViewModel already exposes `var searchText: String = ""` and the `filteredNotifications` computed property already filters on it — no ViewModel changes needed.

The `NotificationSearchBarAccessibilityTests.swift` tests the custom component directly via `UIHostingController`. With the component gone, those tests have no value (Apple owns the native search bar accessibility). Delete them.

- [ ] **Step 1: Add `.searchable()` to `NotificationsListView` and remove `NotificationSearchBar`**

Open `TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Views/NotificationsListView.swift`.

In `body`, remove these lines:
```swift
NotificationSearchBar(
  searchText: $viewModel.searchText,
  onSearchChanged: { _ in }
)
```

Add `.searchable(text: $viewModel.searchText, prompt: "Search notifications")` to the modifier chain on the outermost view (the `VStack`). Place it after `.navigationBarTitleDisplayMode(.inline)`:

```swift
.searchable(text: $viewModel.searchText, prompt: "Search notifications")
```

The full modifier block should look like:
```swift
.navigationTitle("Notifications")
.navigationBarTitleDisplayMode(.inline)
.searchable(text: $viewModel.searchText, prompt: "Search notifications")
.navigationDestination(item: $viewModel.selectedDestination) { destination in
  destinationView(for: destination)
}
```

- [ ] **Step 2: Delete `NotificationSearchBar.swift`**

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationSearchBar.swift
```

- [ ] **Step 3: Delete `NotificationSearchBarAccessibilityTests.swift`**

```bash
rm /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompassTests/Features/Notifications/Accessibility/NotificationSearchBarAccessibilityTests.swift
```

- [ ] **Step 4: Verify build and tests pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Views/NotificationsListView.swift
git rm TheRecruitingCompass/TheRecruitingCompass/Features/Notifications/Components/NotificationSearchBar.swift
git rm TheRecruitingCompass/TheRecruitingCompassTests/Features/Notifications/Accessibility/NotificationSearchBarAccessibilityTests.swift
git commit -m "refactor: replace custom NotificationSearchBar with native .searchable() modifier"
```

---

### Task 12: Replace `NSRegularExpression` with Swift `Regex` in `FormValidator`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/FormValidator.swift`

`FormValidator` uses `NSRegularExpression` with `try!` force-try, requiring `NSRange` boilerplate. Swift 5.7 (iOS 16+) ships native `Regex` literals — compile-time checked, no throwing, no `NSRange`. The public API (all static methods, return types) stays identical — tests require zero changes.

Current patterns:
- Email: `"^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$"`
- Name: `"^[a-zA-Z\\s\\-']+$"`
- Family code: `"^FAM-[A-Z0-9]{6}$"`

- [ ] **Step 1: Rewrite `FormValidator.swift`**

Replace the entire file content:

```swift
import Foundation

enum FormValidator {
  // MARK: - Email
  private static let emailRegex = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/

  static func validateEmail(_ email: String) -> String? {
    let trimmed = email.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "Email is required" }
    guard trimmed.wholeMatch(of: emailRegex) != nil else { return "Invalid email address" }
    return nil
  }

  // MARK: - Password
  static func validatePassword(_ password: String) -> String? {
    guard !password.isEmpty else { return "Password is required" }
    guard password.count >= 8 else { return "Password must be at least 8 characters" }
    return nil
  }

  static func validatePasswordStrength(_ password: String) -> (isValid: Bool, errors: [String]) {
    var errors: [String] = []
    if password.count < 8 { errors.append("at least 8 characters") }
    if !password.contains(where: { $0.isUppercase }) { errors.append("an uppercase letter") }
    if !password.contains(where: { $0.isLowercase }) { errors.append("a lowercase letter") }
    if !password.contains(where: { $0.isNumber }) { errors.append("a number") }
    return (isValid: errors.isEmpty, errors: errors)
  }

  static func validatePasswordMatch(_ password: String, _ confirmPassword: String) -> String? {
    guard password == confirmPassword else { return "Passwords do not match" }
    return nil
  }

  // MARK: - Name
  private static let nameRegex = /^[a-zA-Z\s\-']+$/

  static func validateName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "Name is required" }
    guard trimmed.count >= 2 else { return "Name must be at least 2 characters" }
    guard trimmed.wholeMatch(of: nameRegex) != nil else {
      return "Name can only contain letters, spaces, hyphens, and apostrophes"
    }
    return nil
  }

  // MARK: - Family Code
  private static let familyCodeRegex = /^FAM-[A-Z0-9]{6}$/

  static func validateFamilyCode(_ code: String?) -> String? {
    guard let code else { return nil }
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.wholeMatch(of: familyCodeRegex) != nil else {
      return "Family code must be in format FAM-XXXXXX"
    }
    return nil
  }
}
```

- [ ] **Step 2: Run existing tests to confirm all pass**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/FormValidatorTests 2>&1 | grep -E "Test Case|passed|failed|error:"
```

Expected: all 18 test cases pass with no changes to the test file.

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/FormValidator.swift
git commit -m "refactor: replace NSRegularExpression with Swift Regex literals in FormValidator"
```

---

### Task 13: Replace `DateFormatter` with `.formatted()` in `DateFormatting`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/DateFormatting.swift`

`DateFormatting` holds three singleton `DateFormatter` instances. `Date.formatted(_:)` with `FormatStyle` (iOS 15+) is faster (no singleton), locale-aware, and already partially used in `isoDateString`. The three display methods keep identical signatures — all 7 callers need no changes.

`isoExportFormatter` stays as `DateFormatter` — it uses a fixed POSIX locale for ISO serialization, which `FormatStyle` doesn't support cleanly.

Mapping:
- `mediumDateShortTime(_:)` → `.formatted(date: .abbreviated, time: .shortened)`
- `shortDate(_:)` → `.formatted(date: .numeric, time: .omitted)`
- `mediumDate(_:)` → `.formatted(date: .abbreviated, time: .omitted)`

- [ ] **Step 1: Rewrite the three display methods in `DateFormatting.swift`**

Replace the top of the file (the three `DateFormatter` instances and their methods) with:

```swift
import Foundation

enum DateFormatting {
  static func mediumDateShortTime(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .shortened)
  }

  static func shortDate(_ date: Date) -> String {
    date.formatted(date: .numeric, time: .omitted)
  }

  static func mediumDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
  }

  /// Shared formatter for ISO date export ("yyyy-MM-dd") — keep as DateFormatter for POSIX locale control
  static let isoExportFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  /// Converts an ISO date string ("yyyy-MM-dd") to a display string ("Apr 15, 2026")
  static func isoDateString(_ isoDate: String) -> String {
    let components = isoDate.split(separator: "-").compactMap { Int($0) }
    guard components.count == 3 else { return isoDate }
    let date = DateComponents(
      calendar: .current,
      year: components[0], month: components[1], day: components[2]
    ).date
    return date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? isoDate
  }

  /// Converts an ISO date range to "Apr 15, 2026" or "Apr 15 – Jun 5, 2026"
  static func isoDateRangeString(from startDate: String, to endDate: String?) -> String {
    let start = isoDateString(startDate)
    guard let endDate, endDate != startDate else { return start }
    let endComponents = endDate.split(separator: "-").compactMap { Int($0) }
    guard endComponents.count == 3,
          let end = DateComponents(
            calendar: .current,
            year: endComponents[0], month: endComponents[1], day: endComponents[2]
          ).date else { return "\(start) – \(isoDateString(endDate))" }
    return "\(start) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
  }
}
```

- [ ] **Step 2: Verify build — all 7 callers still compile**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. The 7 callers use the same method signatures, so no caller changes are needed.

- [ ] **Step 3: Run full test suite**

```bash
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Test Suite|passed|failed"
```

Expected: all tests pass. Note: `.formatted()` output is locale-dependent — if any test asserts exact date strings like "Feb 12, 2026", those tests will still pass on en_US locale machines but may differ in CI. Check for any hard-coded date string assertions and loosen them if needed.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add TheRecruitingCompass/TheRecruitingCompass/Shared/Utilities/DateFormatting.swift
git commit -m "refactor: replace DateFormatter singletons with Date.formatted() in DateFormatting"
```
