# SwiftUI Code Review

**Based on:** Apple SwiftUI documentation (Context7) and current codebase.  
**Target:** Modern iOS apps on recent OS versions (iOS 16+, 17+).

---

## Executive Summary

The app already follows many modern SwiftUI patterns: **@Observable** view models, **NavigationStack** with type-safe destinations, **.task** for async loading, **@MainActor** on view models, and **@State** for owning observable types. A few inconsistencies and small improvements are noted below so the codebase stays aligned with current Apple guidance and your own CLAUDE.md rules.

---

## 1. State Management: @Observable and View Ownership

### What Apple Recommends (Context7)

- Use the **@Observable** macro for model/view model types (iOS 17+).
- **Do not** use `@ObservedObject` / `@StateObject` with `@Observable` types. Store them in **@State** when the view owns the instance, or pass them as plain properties when the parent owns them.
- With `@Observable`, SwiftUI tracks which properties are read in `body` and updates only when those change.

### Your Codebase

**Correct usage (most of the app):**

- View models are `@Observable` and `@MainActor`.
- Views that own the view model use `@State private var viewModel = ...` (e.g. `LoginView`, `OffersListView`, `MainTabView` for `NotificationsListViewModel`).
- No `@ObservedObject`/`@StateObject` on `@Observable` types in production views.

**✅ Fixed: Screen template**

- **File:** `TheRecruitingCompass/UI/Screens/ExampleScreenView.swift` and `_ScreenTemplate/ExampleScreenView.swift`
- Both now use `@State private var viewModel = ExampleScreenViewModel()` so new screens get the correct pattern for `@Observable` view models.

**✅ Fixed: MockFamilyManager**

- `MockFamilyManager` is now `@Observable` (was `ObservableObject` + `@Published`) so it matches `FamilyManager` and works with `@State` / `@Environment` in tests and previews.

---

## 2. View Lifecycle: .task vs .onAppear

### What Apple Recommends (Context7)

- **`.task(priority:_:)`** – Use for **async** work when the view appears. The task is **cancelled** when the view disappears or identity changes. Use `await` inside the closure.
- **`.onAppear(perform:)`** – Synchronous only; no automatic cancellation. Prefer `.task` for any async loading or network calls.

### Your Codebase

**Good:**

- List/detail screens use `.task { await viewModel.load...() }` (e.g. `OffersListView`, `SchoolsListView`, `InteractionsListView`, `DashboardView`, `CoachDetailView`). This is the recommended pattern.

**Review these:**

| File | Current | Suggestion |
|------|--------|------------|
| `ScholarshipCalculatorView.swift` | `.onAppear { ... }` | If the closure does async work, switch to `.task { ... }` and use `await` so the task is cancelled when the view disappears. |
| `ExportFormatSheet.swift` | `.onAppear { ... }` | Same as above; use `.task` if the work is async. |
| `PerformanceDashboardView` (toast) | `.onAppear { DispatchQueue.main.asyncAfter(...) }` | Fine as-is: fire-and-forget timer, not async loading. |
| `EmailVerificationView` | `.onAppear { viewModel.onAppear() }` | OK if `onAppear()` is synchronous (e.g. starting a timer). If it ever becomes async, call it from a `.task` instead. |
| `StatCardSkeleton` | `.onAppear { isAnimating = true }` | Sync; no change needed. |
| `Toast` | `.onAppear` for timer | Sync timer; no change needed. |

**Rule of thumb:** Any modifier that runs `await` or async code should be `.task`, not `.onAppear`.

---

## 3. Navigation: NavigationStack and Type-Safe Destinations

### What Apple Recommends (Context7)

- Use **NavigationStack** (iOS 16+) with **value-based** navigation.
- Use **`.navigationDestination(for:destination:)`** so the stack shows the right view for a given type. Prefer this over embedding destination in lazy containers (e.g. inside `LazyVStack`/`List` items).

### Your Codebase

- **MainTabView** and root flows use `NavigationStack`; good.
- **OffersListView** uses `NavigationLink(value: OfferDestination.detail(offer.id))` and `.navigationDestination(for: OfferDestination.self)` on the view (not inside the lazy list); correct and type-safe.

No changes required for navigation pattern; optional follow-up is to ensure other list/detail features (Schools, Coaches, Interactions) use the same `NavigationStack` + `navigationDestination` + `NavigationLink(value:)` pattern where applicable.

---

## 4. Alerts and Bindings

### ✅ Implemented: Proper binding for error alerts

Error alerts now use a **derived `Binding`** so SwiftUI can drive dismissal correctly (no `.constant(...)` for `isPresented`).

**Pattern used (see also `docs/CODE_PATTERNS.md`):**

```swift
.alert("Error", isPresented: Binding(
  get: { viewModel.errorMessage != nil },
  set: { if !$0 { viewModel.errorMessage = nil } }
)) {
  Button("Retry") { viewModel.errorMessage = nil; Task { await viewModel.load() } }
  Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
} message: {
  if let error = viewModel.errorMessage { Text(error) }
}
```

**Updated files:** `OffersListView`, `SchoolsListView`, `InteractionsListView`, `CoachesListView`, `AddInteractionView`, `FamilyManagementView`, `PreferenceViewModifiers` (PreferenceErrorAlertModifier).

---

## 5. Typography and Accessibility (CLAUDE.md)

### Your Rule

- “Use semantic fonts (.title, .body, .caption) - **NEVER** `.system(size: 14)`.”

### Implemented: Semantic fonts for text

**Text** (labels, copy, numeric values) that used `.font(.system(size: ...))` has been updated to semantic fonts: **ParentPreviewBanner** (`.subheadline`/`.caption`), **StatCard** (`.largeTitle.weight(.bold)`), **AtAGlanceSummary** (`.title.weight(.bold)`), **InteractionAnalyticsCards** (`.title2.weight(.bold)`), **CoachDetailHeader** (`.largeTitle.bold()`), **CompactCoachCard** (`.headline.weight(.semibold)`). **Icons** keep `.font(.system(size: iconSize))` where `iconSize` is from `sizeCategory`.

- **Text/labels (icons only):** Many components use `.font(.system(size: iconSize))` or similar for **icons** (SF Symbols), not for body text. For **decorative or icon-only** elements that scale with `sizeCategory` (e.g. `iconSize` based on `sizeCategory.isAccessibilityCategory`), this is a common and acceptable pattern.
- **TheRecruitingCompassApp** uses `.font(.system(size: splashIconSize))` for the splash icon, with `splashIconSize` respecting `sizeCategory`; good.

**Recommendation:**

- **Body/copy text:** Use only semantic fonts (e.g. `.title`, `.body`, `.caption`) so Dynamic Type and accessibility work as intended. Audit any `.font(.system(size: N))` on `Text` used for readable content and replace with semantic styles.
- **Icons / decorative:** Keeping `.font(.system(size: iconSize))` where `iconSize` is derived from `@Environment(\.sizeCategory)` is reasonable; optionally add a short comment or doc that “icons use scaled system size for Dynamic Type” so the exception to the “never .system(size:)” rule is clear.

---

## 6. Other Good Practices Already in Place

- **Environment:** `AuthManager` and `FamilyManager` are passed via `.environment()` and read with `@Environment`; consistent and testable.
- **Reduce motion:** `TheRecruitingCompassApp` uses `@Environment(\.accessibilityReduceMotion)` and disables animations when it’s true; good for accessibility.
- **Deep links:** `onOpenURL` is used for reset-password; appropriate.
- **Sheets:** Reset password and comparison sheet use `sheet(isPresented:destination:)` with clear bindings.
- **Refreshable:** List views use `.refreshable { await viewModel.load...() }`; matches modern pull-to-refresh with async.
- **Protocol-based DI:** View models take `AuthManaging` / `OffersManaging` etc.; good for unit tests and mocks.

---

## 7. Checklist for New and Touched Code

When adding or refactoring SwiftUI code:

1. **View models:** `@Observable` + `@MainActor`; views that own them use `@State`, not `@StateObject`/`@ObservedObject`.
2. **Async on appear:** Use `.task { await ... }` for any async load; use `.onAppear` only for synchronous setup or timers.
3. **Navigation:** Prefer `NavigationStack` + `NavigationLink(value:)` + `.navigationDestination(for:destination:)` and keep `.navigationDestination` on a non-lazy parent.
4. **Alerts:** Bind `isPresented` to a real `Binding` (e.g. derived from error state: `Binding(get: { error != nil }, set: { if !$0 { error = nil } })`). Never use `.constant(...)` for alert presentation.
5. **Text:** Use semantic fonts for user-facing text; reserve `.font(.system(size:))` for icons/decorative elements, ideally scaled by `sizeCategory`.
6. **Accessibility:** Keep existing patterns (labels, hints, `accessibilityHidden` for decorative content, 44pt minimum hit areas).

---

## Status & next steps

| Item | Status |
|------|--------|
| @Observable + @State (template) | ✅ Fixed |
| Error alert bindings | ✅ Implemented (7 files) |
| .task for async load | ✅ Already used on list/detail screens |
| NavigationStack + navigationDestination | ✅ In use (e.g. Offers) |
| MockFamilyManager | ✅ Converted to `@Observable` |
| Typography | ✅ Semantic fonts for text (6 components); icons keep scaled `.system(size:)` |

---

## References

- Apple: [Migrating from ObservableObject to the Observable macro](https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- Apple: [View.task(priority:_:)](https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/task%28priority%3A_%3A%29) and [View.onAppear(perform:)](https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/onappear%28perform%3A%29)
- Apple: [NavigationStack](https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/navigationstack) and [navigationDestination(for:destination:)](https://developer.apple.com/documentation/SwiftUI/documentation/swiftui/view/navigationdestination%28for%3Adestination%3A%29)
- Project: `CLAUDE.md`, `docs/CODE_PATTERNS.md`, `docs/ACCESSIBILITY_AUDIT.md`
