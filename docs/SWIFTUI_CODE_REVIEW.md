# SwiftUI Code Review: Modern iOS Standards & Patterns

This review is based on **Apple’s SwiftUI documentation** and **modern SwiftUI best practices** (Context7), aligned with your project’s `docs/CODE_PATTERNS.md` and `CLAUDE.md`.

**Scope:** State management, view structure, performance, navigation, typography, and accessibility.

---

## 1. State Management — **Aligned**

- **ViewModels** use `@Observable` (iOS 17+) and `@MainActor`. No `ObservableObject` / `@Published` in production code.
- **Views** use `@State private var viewModel` (and sometimes inject for previews). No `@StateObject` or `@ObservedObject`.
- **App root** uses `@State private var authManager` / `familyManager` and `.environment(...)`, matching the [migration from ObservableObject to Observable](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro): store observable types in `@State`, pass with `.environment()`.

**Recommendation:** Update **CLAUDE.md** so it no longer describes ViewModels as “`@ObservableObject`” and “`@Published` properties.” Your **CODE_PATTERNS.md** is already correct; CLAUDE.md should match it (e.g. “ViewModels use `@Observable` and `@MainActor`”).

---

## 2. Navigation — **Aligned**

- **NavigationStack** is used throughout (no `NavigationView`).
- **Programmatic navigation** uses `NavigationStack(path:)` and `navigationDestination(for:destination:)` where needed (e.g. AddSchoolView).
- **MainTabView** uses one `NavigationStack` per tab, which is the right pattern for tab-based apps.

No changes required for navigation.

---

## 3. List & Scroll Performance — **Aligned**

- Long lists use **ScrollView + LazyVStack** (e.g. `TasksListView`, `SchoolsListView`) so views are created when visible.
- **ForEach** is keyed by model identity (e.g. `viewModel.filteredTasks`, `viewModel.filteredSchools`), which is correct for diffing and updates.

Continue using `List` when you need built-in swipe actions, reorder, or list styling; use `ScrollView` + `LazyVStack` for custom layouts and long, homogeneous lists.

---

## 4. View Structure & Performance — **Improvement opportunity**

**Current pattern (e.g. DashboardView):** Large views are split into **private computed properties** (e.g. `headerSection`, `statsCardsSection`, `widgetsSection`). These are re-evaluated whenever the parent’s `body` runs, so any change in `viewModel` or `familyManager` re-runs all of them.

**Modern SwiftUI guidance:** Extract **separate view structs** that take only the data they need (e.g. `let title: String`, `let count: Int`). SwiftUI can then skip re-evaluating those structs’ `body` when their inputs are unchanged.

**Example (conceptual):**

```swift
// Instead of: private var statsCardsSection: some View { ... }
// Prefer: a dedicated struct with value inputs
struct DashboardStatsCardsSection: View {
  let stats: DashboardStats
  var body: some View {
    LazyVGrid(...) {
      // StatCard(...) etc.
    }
  }
}

// In DashboardView body:
if let stats = viewModel.stats {
  DashboardStatsCardsSection(stats: stats)
}
```

**Recommendation:** For the heaviest screens (e.g. Dashboard, Schools list, Task list), consider extracting the largest sections into **small structs with value inputs** so only changed data triggers re-renders. Reusable cards (e.g. `StatCard`, `TaskCard`, `SchoolCardView`) are already well isolated.

---

## 5. Typography & Dynamic Type — **One fix**

- **Body and labels** correctly use semantic fonts (`.title2`, `.headline`, `.subheadline`, `.caption`, `.callout`), which supports Dynamic Type and accessibility.
- **Icons (SF Symbols)** mostly use `.font(.system(size: iconSize))` with `iconSize` derived from `@Environment(\.sizeCategory)` (e.g. StatCard, EmptyDashboardState, LoginView). That matches your CODE_PATTERNS exception for icons.

**Issue:** `TaskCard.swift` uses a **fixed** icon size for the checkbox:

```swift
.font(.system(size: 22))
```

**Recommendation:** Derive the icon size from `@Environment(\.sizeCategory)` (e.g. `sizeCategory.isAccessibilityCategory ? 26 : 22`) so the checkbox scales with Dynamic Type, consistent with the rest of the app and WCAG.

---

## 6. Accessibility — **Aligned**

- Interactive elements use `.accessibilityLabel()` and `.accessibilityHint()` where needed.
- Decorative icons use `.accessibilityHidden(true)` (e.g. StatCard icon, logout icon).
- Combined content uses `.accessibilityElement(children: .combine)` (e.g. StatCard).
- Buttons use `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(Rectangle())` for hit targets (e.g. Dashboard refresh, Schools add).
- **E2E / accessibility tests** are present and match your documented strategy.

No structural changes needed; keep applying these patterns to new UI.

---

## 7. Async & Lifecycle — **Aligned**

- Initial load uses **`.task { await viewModel.load... }`** (not `.onAppear` + fire-and-forget).
- Pull-to-refresh uses **`.refreshable { await viewModel.refresh() }`**.
- Error alerts use a **derived Binding** (e.g. `Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })`) so dismissal works correctly.

This matches current SwiftUI guidance for async and alerts.

---

## 8. Minor / Housekeeping

- **AddSchool sheet:** `SchoolsListView` presents `Text("Add School Form")` in the add-school sheet. When the real flow is implemented, present `AddSchoolView` (or equivalent) and pass any required state.
- **Comments in AddSchoolViewModel+*.swift:** References to “@Published properties” are outdated; the type is `@Observable`. Updating those comments avoids confusion.

---

## Summary

| Area              | Status   | Action |
|-------------------|----------|--------|
| State (@Observable) | Good     | Sync CLAUDE.md wording with CODE_PATTERNS.md |
| Navigation        | Good     | None |
| List/Scroll       | Good     | None |
| View structure    | Done     | Dashboard: `DashboardStatsCardsSection`, `DashboardChartsAndDataSection`, `DashboardWidgetsSection` |
| Typography        | Good     | Fix TaskCard checkbox icon to use sizeCategory |
| Accessibility     | Good     | None |
| Async / lifecycle | Good     | None |

Overall, the codebase is in line with **modern SwiftUI and iOS 17+ patterns**: Observation-based state, `NavigationStack`, lazy stacks, semantic fonts, and solid accessibility. The main follow-ups are aligning CLAUDE.md with your chosen patterns, making the TaskCard icon scale with Dynamic Type, and optionally refining view structure for the most complex screens.
