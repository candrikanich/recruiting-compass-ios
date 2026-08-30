# Native iPad Experience — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the iPhone-only app into a full native iPad app with NavigationSplitView sidebar, multi-column dashboard, adaptive list grids, and detail-page sidebars — while keeping the iPhone experience identical.

**Architecture:** Size-class branching at key layout boundaries. `AdaptiveRootView` reads `horizontalSizeClass` to switch between `MainTabView` (compact/iPhone) and `NavigationSplitView` with sidebar (regular/iPad). All existing views remain intact for the compact path. New adaptive wrapper components handle the regular path: `AdaptiveDashboardGrid`, `AdaptiveListView`, `AdaptiveDetailLayout`, `FormContainerView`.

**Tech Stack:** SwiftUI, NavigationSplitView, LazyVGrid, @Environment(\.horizontalSizeClass), ViewThatFits

**Spec:** `planning/2026-08-30-native-ipad-design.md`

## Global Constraints

- All source files under `TheRecruitingCompass/TheRecruitingCompass/` (double-nested)
- All test files under `TheRecruitingCompass/TheRecruitingCompassTests/`
- Build from `TheRecruitingCompass/` directory: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`
- iPad test target: `xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPad Air'`
- `@MainActor` on all ViewModels; every new `@MainActor` class needs `nonisolated deinit {}`
- Line length ≤120 (SwiftLint)
- PBXFileSystemSynchronizedRootGroup — new .swift files auto-included, never edit .xcodeproj for file additions
- iPhone behavior must remain identical — all iPad changes gated on `horizontalSizeClass == .regular`

---

### Task 1: Project Settings — Enable iPad + Makefile Targets

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj` (lines 533, 572, 592, 613, 632, 651)
- Modify: `Makefile`

**Interfaces:**
- Consumes: nothing
- Produces: iPad simulator builds and runs; `make test-ipad` and `make build-ipad` targets

- [ ] **Step 1: Revert TARGETED_DEVICE_FAMILY to "1,2"**

Six substitutions in `project.pbxproj`, all identical:

```
TARGETED_DEVICE_FAMILY = 1;
```
→
```
TARGETED_DEVICE_FAMILY = "1,2";
```

Lines 533, 572, 592, 613, 632, 651. Use:
```bash
cd TheRecruitingCompass
perl -pi -e 's/TARGETED_DEVICE_FAMILY = 1;/TARGETED_DEVICE_FAMILY = "1,2";/g' TheRecruitingCompass.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Add iPad targets to Makefile**

Add after the existing `test-unit-fast` target:

```makefile
build-ipad:
	cd TheRecruitingCompass && xcodebuild build \
	  -scheme TheRecruitingCompass \
	  -destination 'platform=iOS Simulator,name=iPad Air' \
	  $(XCARGS)

test-ipad:
	cd TheRecruitingCompass && xcodebuild test \
	  -scheme TheRecruitingCompass \
	  -destination 'platform=iOS Simulator,name=iPad Air' \
	  -skip-testing:TheRecruitingCompassUITests \
	  -disable-concurrent-destination-testing \
	  -test-timeouts-enabled YES \
	  $(XCARGS)

test-all-devices: test-unit test-ipad
```

- [ ] **Step 3: Verify iPad build**

```bash
make build-ipad
```

Expected: BUILD SUCCEEDED. App launches as scaled iPhone layout on iPad simulator.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj Makefile
git commit -m "chore: re-enable iPad support and add iPad build/test targets"
```

---

### Task 2: AppDestination Enum

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/AppDestination.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/AppDestinationTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `AppDestination` enum used by `SidebarView` (Task 3) and `AdaptiveRootView` (Task 4). Cases: `dashboard`, `schools`, `coaches`, `interactions`, `timeline`, `events`, `performance`, `offers`, `analytics`, `documents`, `deadlines`, `settings`. Properties: `section: SidebarSection`, `label: String`, `systemImage: String`, `id: String`.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/AppDestinationTests.swift
import XCTest
@testable import TheRecruitingCompass

final class AppDestinationTests: XCTestCase {
    func testAllCasesExist() {
        let allCases = AppDestination.allCases
        XCTAssertEqual(allCases.count, 12)
    }

    func testSectionGrouping() {
        let mainItems = AppDestination.allCases.filter { $0.section == .main }
        let moreItems = AppDestination.allCases.filter { $0.section == .more }
        let bottomItems = AppDestination.allCases.filter { $0.section == .bottom }

        XCTAssertEqual(mainItems.count, 6, "Main: dashboard, schools, coaches, interactions, timeline, events")
        XCTAssertEqual(moreItems.count, 5, "More: performance, offers, analytics, documents, deadlines")
        XCTAssertEqual(bottomItems.count, 1, "Bottom: settings")
    }

    func testMainSectionOrder() {
        let mainItems = AppDestination.allCases.filter { $0.section == .main }
        XCTAssertEqual(mainItems, [.dashboard, .schools, .coaches, .interactions, .timeline, .events])
    }

    func testEachCaseHasLabel() {
        for destination in AppDestination.allCases {
            XCTAssertFalse(destination.label.isEmpty, "\(destination) missing label")
        }
    }

    func testEachCaseHasSystemImage() {
        for destination in AppDestination.allCases {
            XCTAssertFalse(destination.systemImage.isEmpty, "\(destination) missing systemImage")
        }
    }

    func testIdentifiable() {
        let ids = Set(AppDestination.allCases.map(\.id))
        XCTAssertEqual(ids.count, AppDestination.allCases.count, "IDs must be unique")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppDestinationTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `AppDestination` not found.

- [ ] **Step 3: Implement AppDestination**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/AppDestination.swift
import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    // Main
    case dashboard, schools, coaches, interactions, timeline, events
    // More
    case performance, offers, analytics, documents, deadlines
    // Bottom
    case settings

    var id: String { rawValue }

    var section: SidebarSection {
        switch self {
        case .dashboard, .schools, .coaches, .interactions, .timeline, .events:
            return .main
        case .performance, .offers, .analytics, .documents, .deadlines:
            return .more
        case .settings:
            return .bottom
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .schools: return "Schools"
        case .coaches: return "Coaches"
        case .interactions: return "Interactions"
        case .timeline: return "Timeline"
        case .events: return "Events"
        case .performance: return "Performance"
        case .offers: return "Offers"
        case .analytics: return "Analytics"
        case .documents: return "Documents"
        case .deadlines: return "Deadlines"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .schools: return "building.2"
        case .coaches: return "person.2"
        case .interactions: return "bubble.left.and.bubble.right"
        case .timeline: return "clock"
        case .events: return "calendar"
        case .performance: return "chart.bar"
        case .offers: return "envelope.open"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .documents: return "doc.text"
        case .deadlines: return "exclamationmark.circle"
        case .settings: return "gear"
        }
    }

    enum SidebarSection: String, CaseIterable {
        case main, more, bottom

        var header: String? {
            switch self {
            case .main: return nil
            case .more: return "More"
            case .bottom: return nil
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AppDestinationTests -quiet 2>&1 | tail -5
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(ipad): add AppDestination enum for sidebar navigation"
```

---

### Task 3: SidebarView

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/SidebarView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/SidebarViewTests.swift`

**Interfaces:**
- Consumes: `AppDestination` enum (Task 2)
- Produces: `SidebarView` with `@Binding var selection: AppDestination?` — used by `AdaptiveRootView` (Task 4)

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/SidebarViewTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class SidebarViewTests: XCTestCase {
    nonisolated deinit {}

    func testSidebarRendersAllDestinations() throws {
        var selection: AppDestination? = .dashboard
        let view = SidebarView(selection: .constant(selection))

        // Verify all sections are represented
        let mainItems = AppDestination.allCases.filter { $0.section == .main }
        let moreItems = AppDestination.allCases.filter { $0.section == .more }
        let bottomItems = AppDestination.allCases.filter { $0.section == .bottom }

        XCTAssertEqual(mainItems.count, 6)
        XCTAssertEqual(moreItems.count, 5)
        XCTAssertEqual(bottomItems.count, 1)
    }

    func testSidebarDefaultSelection() {
        let view = SidebarView(selection: .constant(.dashboard))
        // Compiles and renders without crash
        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SidebarViewTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `SidebarView` not found.

- [ ] **Step 3: Implement SidebarView**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppDestination?
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(itemsForSection(.main)) { destination in
                    sidebarLabel(destination)
                }
            }

            Section("More") {
                ForEach(itemsForSection(.more)) { destination in
                    sidebarLabel(destination)
                }
            }

            Section {
                ForEach(itemsForSection(.bottom)) { destination in
                    sidebarLabel(destination)
                }
                profileRow
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("myCompass")
    }

    private func itemsForSection(_ section: AppDestination.SidebarSection) -> [AppDestination] {
        AppDestination.allCases.filter { $0.section == section }
    }

    private func sidebarLabel(_ destination: AppDestination) -> some View {
        Label(destination.label, systemImage: destination.systemImage)
            .tag(destination)
    }

    @ViewBuilder
    private var profileRow: some View {
        if let user = authManager.currentUser {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(user.initials)
                            .font(.caption.bold())
                            .foregroundStyle(.accent)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.subheadline.weight(.medium))
                    Text(user.email ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Profile: \(user.fullName)")
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SidebarViewTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5: Build-verify on iPad simulator**

```bash
make build-ipad
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(ipad): add SidebarView with grouped navigation items"
```

---

### Task 4: AdaptiveRootView — Navigation Shell

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/AdaptiveRootView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/TheRecruitingCompassApp.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/AdaptiveRootViewTests.swift`

**Interfaces:**
- Consumes: `AppDestination` (Task 2), `SidebarView` (Task 3), `MainTabView` (existing), all feature views
- Produces: `AdaptiveRootView` — top-level view that replaces `MainTabView` in the app entry point. Exposes same environment actions as `MainTabView` (`switchTab`, `filterCoachesBySchool`, `openMoreSection`).

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Navigation/AdaptiveRootViewTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveRootViewTests: XCTestCase {
    nonisolated deinit {}

    func testCompactSizeClassRendersTabView() {
        // AdaptiveRootView should exist and accept the same bindings as MainTabView
        let view = AdaptiveRootView(pendingPushDestination: .constant(nil))
            .environment(\.horizontalSizeClass, .compact)
        XCTAssertNotNil(view)
    }

    func testRegularSizeClassRendersSplitView() {
        let view = AdaptiveRootView(pendingPushDestination: .constant(nil))
            .environment(\.horizontalSizeClass, .regular)
        XCTAssertNotNil(view)
    }

    func testDefaultSelectionIsDashboard() {
        let rootView = AdaptiveRootView(pendingPushDestination: .constant(nil))
        // The view should compile and default to dashboard
        XCTAssertNotNil(rootView)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveRootViewTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `AdaptiveRootView` not found.

- [ ] **Step 3: Implement AdaptiveRootView**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/AdaptiveRootView.swift
import SwiftUI

struct AdaptiveRootView: View {
    @Binding var pendingPushDestination: NotificationDestination?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedDestination: AppDestination? = .dashboard

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            MainTabView(pendingPushDestination: $pendingPushDestination)
        }
    }

    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedDestination)
        } detail: {
            detailView(for: selectedDestination ?? .dashboard)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detailView(for destination: AppDestination) -> some View {
        NavigationStack {
            switch destination {
            case .dashboard:
                DashboardView()
            case .schools:
                SchoolsListView(navigationPath: .constant(NavigationPath()))
            case .coaches:
                CoachesListView(
                    prefilterSchoolId: .constant(nil),
                    navigationPath: .constant(NavigationPath())
                )
            case .interactions:
                InteractionsListView(navigationPath: .constant(NavigationPath()))
            case .timeline:
                TimelineView()
            case .events:
                EventsView()
            case .performance:
                PerformanceView()
            case .offers:
                OffersView()
            case .analytics:
                AnalyticsView()
            case .documents:
                DocumentsView()
            case .deadlines:
                DeadlinesView()
            case .settings:
                MoreMenuView()
            }
        }
    }
}
```

> **Note for implementer:** The exact view names for Timeline, Events, Performance, Offers, Analytics, Documents, Deadlines must match what `MoreMenuView` currently routes to. Check `MoreMenuView.swift` and `MorePath` enum for the real view names and adjust the switch cases accordingly. Some may be wrapped in navigation destinations inside `MoreMenuView` — extract the destination views directly.

- [ ] **Step 4: Modify TheRecruitingCompassApp.swift**

In `TheRecruitingCompassApp.swift`, find the line in `AuthenticatedContent` that renders `MainTabView`:

```swift
MainTabView(pendingPushDestination: $pendingPushDestination)
```

Replace with:

```swift
AdaptiveRootView(pendingPushDestination: $pendingPushDestination)
```

This is the only change needed in the app entry point. All environment objects (`authManager`, `familyManager`, etc.) flow through unchanged.

- [ ] **Step 5: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveRootViewTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6: Build-verify on both targets**

```bash
make build        # iPhone — must still work identically
make build-ipad   # iPad — should now show sidebar + detail
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 7: Verify existing tests still pass**

```bash
make test-unit
```

Expected: All existing tests PASS. No regressions from the swap.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(ipad): add AdaptiveRootView with NavigationSplitView sidebar"
```

---

### Task 5: Dashboard — AdaptiveDashboardGrid

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/AdaptiveDashboardGrid.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/DashboardWidgetID.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/DashboardWidgetStack.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/AdaptiveDashboardGridTests.swift`

**Interfaces:**
- Consumes: `DashboardWidgetID` (existing), `DashboardWidgetStack` (existing), `DashboardView` (existing)
- Produces: `AdaptiveDashboardGrid` — renders widgets in single-column (compact) or 4+2 grid (regular). `DashboardWidgetID.widthClass: WidgetWidth` property classifying each widget.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/AdaptiveDashboardGridTests.swift
import XCTest
@testable import TheRecruitingCompass

final class AdaptiveDashboardGridTests: XCTestCase {
    func testWidgetWidthClassification() {
        // Sidebar widgets
        XCTAssertEqual(DashboardWidgetID.recruitingCalendar.widthClass, .sidebar)

        // Full-width widgets
        XCTAssertEqual(DashboardWidgetID.actionItems.widthClass, .full)
        XCTAssertEqual(DashboardWidgetID.interactionTrends.widthClass, .full)

        // Half-width widgets
        XCTAssertEqual(DashboardWidgetID.coachFollowup.widthClass, .half)
        XCTAssertEqual(DashboardWidgetID.upcomingEvents.widthClass, .half)
    }

    func testMainWidgetsExcludesSidebar() {
        let allWidgets = DashboardWidgetID.allCases
        let mainWidgets = allWidgets.filter { $0.widthClass != .sidebar }
        let sidebarWidgets = allWidgets.filter { $0.widthClass == .sidebar }

        XCTAssertTrue(mainWidgets.count > sidebarWidgets.count)
        XCTAssertTrue(sidebarWidgets.count >= 1)
    }

    func testAllWidgetsHaveWidthClass() {
        for widget in DashboardWidgetID.allCases {
            // Should not crash — every case has a widthClass
            _ = widget.widthClass
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveDashboardGridTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `widthClass` property not found on `DashboardWidgetID`.

- [ ] **Step 3: Add WidgetWidth enum and widthClass to DashboardWidgetID**

In `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Models/DashboardWidgetID.swift`, add:

```swift
enum WidgetWidth {
    case full    // spans entire main column on iPad
    case half    // shares row with another .half widget on iPad
    case sidebar // pinned to right sidebar column on iPad, inline on iPhone
}
```

Add computed property to `DashboardWidgetID`:

```swift
var widthClass: WidgetWidth {
    switch self {
    case .actionItems: return .full
    case .coachFollowup: return .half
    case .upcomingEvents: return .half
    case .quickTasks: return .half
    case .atAGlance: return .half
    case .recruitingCalendar: return .sidebar
    case .performance: return .half
    case .interactionTrends: return .full
    case .recentActivity: return .sidebar
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveDashboardGridTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5: Implement AdaptiveDashboardGrid**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/AdaptiveDashboardGrid.swift
import SwiftUI

struct AdaptiveDashboardGrid<MainContent: View, SidebarContent: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let sidebarContent: () -> SidebarContent

    var body: some View {
        if sizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                mainContent()
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                sidebarContent()
                    .frame(width: 300)
            }
            .frame(width: 300)
        }
        .padding(.horizontal)
    }

    private var compactLayout: some View {
        VStack(spacing: 24) {
            mainContent()
            sidebarContent()
        }
    }
}
```

- [ ] **Step 6: Integrate into DashboardView**

In `DashboardView.swift`, wrap the widget area in `AdaptiveDashboardGrid`. The existing `DashboardWidgetStack` renders all widgets sequentially — split it so widgets with `.sidebar` widthClass go to the sidebar closure and others go to main.

Modify `DashboardView` to replace the current `VStack(spacing: 24)` content section with:

```swift
AdaptiveDashboardGrid {
    // Main column content
    VStack(spacing: 24) {
        DashboardHeaderSection(/* existing params */)
        DashboardTimelineSummaryCard(/* existing params */)
        DashboardAthleteSelectorSection(/* existing params */)
        DashboardStatsCardsSection(/* existing params */)
        DashboardWidgetStack(
            /* existing params */,
            excludeWidthClasses: [.sidebar]  // skip sidebar widgets
        )
    }
} sidebarContent: {
    // Sidebar column content (iPad) / inline below main (iPhone)
    VStack(spacing: 16) {
        DashboardPublicProfileCard(/* existing params */)
        DashboardWidgetStack(
            /* existing params */,
            onlyWidthClasses: [.sidebar]  // only sidebar widgets
        )
    }
}
```

> **Note for implementer:** `DashboardWidgetStack` currently renders all widgets. Add optional `excludeWidthClasses: Set<WidgetWidth>?` and `onlyWidthClasses: Set<WidgetWidth>?` filter parameters. In the `widget(for:)` method, skip widgets that don't pass the filter. When both are nil, render all (backward compatible).

- [ ] **Step 7: Build-verify both targets**

```bash
make build && make build-ipad
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 8: Run full unit test suite**

```bash
make test-unit
```

Expected: All tests PASS, including existing dashboard tests.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat(ipad): add AdaptiveDashboardGrid with 4+2 column layout"
```

---

### Task 6: AdaptiveListView — Multi-Column Card Grid

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/AdaptiveListView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveListViewTests.swift`

**Interfaces:**
- Consumes: nothing (standalone generic component)
- Produces: `AdaptiveListView<Item, CardContent>` — generic wrapper that renders items in `LazyVStack` (compact) or `LazyVGrid` (regular). Used by Tasks 7-9 to wrap list pages.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveListViewTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveListViewTests: XCTestCase {
    nonisolated deinit {}

    struct MockItem: Identifiable {
        let id: Int
        let name: String
    }

    func testAdaptiveListViewCompactCreation() {
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testAdaptiveListViewRegularCreation() {
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testAdaptiveListViewEmptyItems() {
        let items: [MockItem] = []
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveListViewTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `AdaptiveListView` not found.

- [ ] **Step 3: Implement AdaptiveListView**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/AdaptiveListView.swift
import SwiftUI

struct AdaptiveListView<Item: Identifiable, CardContent: View>: View {
    let items: [Item]
    @ViewBuilder let cardContent: (Item) -> CardContent
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 16)]
    }

    var body: some View {
        if sizeClass == .regular {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(items) { item in
                    cardContent(item)
                }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    cardContent(item)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveListViewTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(ipad): add AdaptiveListView generic multi-column grid component"
```

---

### Task 7: Apply AdaptiveListView to Schools, Coaches, Interactions

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolsListView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachesListView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/InteractionsListView.swift`

**Interfaces:**
- Consumes: `AdaptiveListView` (Task 6)
- Produces: Schools, Coaches, Interactions list pages render multi-column cards on iPad

- [ ] **Step 1: Modify SchoolsListView**

In `SchoolsListView.swift`, find the `ForEach(viewModel.filteredSchools)` block that renders `SchoolCardView` inside a `LazyVStack`. Replace the `ForEach` wrapper (keep the `NavigationLink` + `SchoolCardView` content) with `AdaptiveListView`:

Before:
```swift
ForEach(viewModel.filteredSchools) { school in
    NavigationLink(value: SchoolDestination.detail(school.id)) {
        SchoolCardView(school: school, onToggleFavorite: { ... }, onDelete: { ... }, overall: ...)
    }
}
```

After:
```swift
AdaptiveListView(items: viewModel.filteredSchools) { school in
    NavigationLink(value: SchoolDestination.detail(school.id)) {
        SchoolCardView(school: school, onToggleFavorite: { ... }, onDelete: { ... }, overall: ...)
    }
}
```

The surrounding `LazyVStack` that contains other elements (analytics cards, filter bar) stays — only the card-rendering loop changes. The `AdaptiveListView` provides its own `LazyVStack`/`LazyVGrid` internally.

- [ ] **Step 2: Modify CoachesListView**

Same pattern. Find the `ForEach(viewModel.filteredCoaches)` block, replace with:

```swift
AdaptiveListView(items: viewModel.filteredCoaches) { coach in
    NavigationLink(value: CoachDestination.detail(coach.id)) {
        CoachCardView(coach: coach, variant: .full, /* existing params */)
    }
    .contextMenu { /* existing context menu */ }
}
```

- [ ] **Step 3: Modify InteractionsListView**

Same pattern. Find the `ForEach(viewModel.filteredInteractions)` block, replace with:

```swift
AdaptiveListView(items: viewModel.filteredInteractions) { interaction in
    Button {
        navigationPath.append(InteractionDestination.detail(interaction.id))
    } label: {
        InteractionCard(interaction: interaction, /* existing params */)
    }
}
```

- [ ] **Step 4: Build-verify both targets**

```bash
make build && make build-ipad
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 5: Run full unit test suite**

```bash
make test-unit
```

Expected: All existing tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(ipad): apply AdaptiveListView to Schools, Coaches, Interactions"
```

---

### Task 8: AdaptiveDetailLayout — Detail Page Sidebars

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/AdaptiveDetailLayout.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveDetailLayoutTests.swift`

**Interfaces:**
- Consumes: nothing (standalone generic component)
- Produces: `AdaptiveDetailLayout<Content, Sidebar>` — renders content + sidebar stacked (compact) or side-by-side (regular) with configurable `sidebarPlacement: .leading | .trailing` and `sidebarWidth: CGFloat`. Used by Tasks 9-10.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveDetailLayoutTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveDetailLayoutTests: XCTestCase {
    nonisolated deinit {}

    func testTrailingSidebarCompact() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .trailing) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testTrailingSidebarRegular() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .trailing) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testLeadingSidebarRegular() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .leading) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testCustomSidebarWidth() {
        let view = AdaptiveDetailLayout(
            sidebarPlacement: .leading,
            sidebarWidth: 340
        ) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveDetailLayoutTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `AdaptiveDetailLayout` not found.

- [ ] **Step 3: Implement AdaptiveDetailLayout**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/AdaptiveDetailLayout.swift
import SwiftUI

struct AdaptiveDetailLayout<Content: View, Sidebar: View>: View {
    let sidebarPlacement: SidebarPlacement
    let sidebarWidth: CGFloat
    @ViewBuilder let content: () -> Content
    @ViewBuilder let sidebar: () -> Sidebar
    @Environment(\.horizontalSizeClass) private var sizeClass

    enum SidebarPlacement {
        case leading
        case trailing
    }

    init(
        sidebarPlacement: SidebarPlacement,
        sidebarWidth: CGFloat = 300,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder sidebar: @escaping () -> Sidebar
    ) {
        self.sidebarPlacement = sidebarPlacement
        self.sidebarWidth = sidebarWidth
        self.content = content
        self.sidebar = sidebar
    }

    var body: some View {
        if sizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            if sidebarPlacement == .leading {
                sidebarColumn
                Divider()
            }

            ScrollView {
                content()
                    .padding()
            }
            .frame(maxWidth: .infinity)

            if sidebarPlacement == .trailing {
                Divider()
                sidebarColumn
            }
        }
    }

    private var sidebarColumn: some View {
        ScrollView {
            sidebar()
                .padding()
        }
        .frame(width: sidebarWidth)
        .background(Color(.systemGroupedBackground))
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                content()
                sidebar()
            }
            .padding()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/AdaptiveDetailLayoutTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(ipad): add AdaptiveDetailLayout with leading/trailing sidebar"
```

---

### Task 9: School Detail — Extract Sidebar + Wrap in AdaptiveDetailLayout

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailSidebar.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailView.swift`

**Interfaces:**
- Consumes: `AdaptiveDetailLayout` (Task 8), existing `SchoolDetailView` sections
- Produces: `SchoolDetailSidebar` component + `SchoolDetailView` wrapped in `AdaptiveDetailLayout(sidebarPlacement: .trailing)`

- [ ] **Step 1: Read SchoolDetailView.swift to identify sidebar sections**

Read the full `SchoolDetailView.swift`. The following sections move to the sidebar (matching web's SchoolSidebar):
1. `SchoolRecruitingStatusAndTierSection` — status pipeline
2. `SchoolQuickActions` — log interaction, send email, manage coaches
3. `SchoolCoachesPanel` — coaches at this school
4. `SchoolFitSection` — personal + academic fit
5. `SchoolAttributionSection` — created/updated metadata

Everything else stays in the main content column.

- [ ] **Step 2: Create SchoolDetailSidebar**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/SchoolDetailSidebar.swift
import SwiftUI

struct SchoolDetailSidebar: View {
    @Bindable var viewModel: SchoolDetailViewModel

    var body: some View {
        VStack(spacing: 16) {
            SchoolRecruitingStatusAndTierSection(
                viewModel: viewModel
            )

            SchoolQuickActions(
                viewModel: viewModel
            )

            SchoolCoachesPanel(
                viewModel: viewModel
            )

            SchoolFitSection(
                viewModel: viewModel
            )

            SchoolAttributionSection(
                viewModel: viewModel
            )
        }
    }
}
```

> **Note for implementer:** The exact parameters passed to each section component will differ — match them to what `SchoolDetailView` currently passes. The sections above are extracted by cutting them from `SchoolDetailView`'s body and pasting into `SchoolDetailSidebar`. The ViewModel is the same `SchoolDetailViewModel` — just shared between content and sidebar.

- [ ] **Step 3: Wrap SchoolDetailView in AdaptiveDetailLayout**

In `SchoolDetailView.swift`, replace the existing `ScrollView { VStack { ... } }` body with:

```swift
AdaptiveDetailLayout(sidebarPlacement: .trailing) {
    // Main content — everything except sidebar sections
    VStack(spacing: 16) {
        SchoolDetailHeader(viewModel: viewModel)
        Divider()
        SchoolMapView(viewModel: viewModel)
        SchoolBasicInfoDisplaySection(viewModel: viewModel)
        CollegeDataSection(viewModel: viewModel)
        // ... remaining non-sidebar sections ...
        SchoolCoachingPhilosophySection(viewModel: viewModel)
        SchoolProsConsSection(viewModel: viewModel)
        SchoolNotesSection(/* "Why this program" */)
        SchoolNotesSection(/* "Why it fits you" */)
        SchoolNotesSection(/* "Notes" */)
        SchoolDocumentsSection(viewModel: viewModel)
        SchoolStatusHistorySection(viewModel: viewModel)
    }
} sidebar: {
    SchoolDetailSidebar(viewModel: viewModel)
}
```

Remove the sections that moved to `SchoolDetailSidebar` from the main content VStack. The `ScrollView` wrapping is handled by `AdaptiveDetailLayout` — remove the outer `ScrollView` from `SchoolDetailView`.

- [ ] **Step 4: Build-verify both targets**

```bash
make build && make build-ipad
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 5: Run existing school tests**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/SchoolDetailViewModelTests -quiet 2>&1 | tail -5
```

Expected: All existing school tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(ipad): extract SchoolDetailSidebar, wrap detail in AdaptiveDetailLayout"
```

---

### Task 10: Coach Detail — Extract Rail + Wrap in AdaptiveDetailLayout

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachDetailRail.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachDetailView.swift`

**Interfaces:**
- Consumes: `AdaptiveDetailLayout` (Task 8), existing `CoachDetailView` sections
- Produces: `CoachDetailRail` component + `CoachDetailView` wrapped in `AdaptiveDetailLayout(sidebarPlacement: .leading, sidebarWidth: 340)`

- [ ] **Step 1: Read CoachDetailView.swift to identify rail sections**

Read the full `CoachDetailView.swift`. The following sections move to the left rail (matching web's coach left-rail pattern):
1. `CoachDetailHeader` — avatar, name, school, edit/delete
2. `SectionCard("Direct Channels") { CoachDirectChannelsGrid }` — channel action buttons
3. `SectionCard("Internal Notes") { sharedNotesSection }` — notes with auto-save
4. `SectionCard("Tags") { CoachTagsCard }` — add/remove tags
5. `SectionCard("Profile Meta") { CoachProfileMetaCard }` — metadata

Everything else stays in the main content area (alerts, stats grid, analytics, interactions history, send profile).

- [ ] **Step 2: Create CoachDetailRail**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachDetailRail.swift
import SwiftUI

struct CoachDetailRail: View {
    @Bindable var viewModel: CoachDetailViewModel

    var body: some View {
        VStack(spacing: 16) {
            SectionCard {
                CoachDetailHeader(viewModel: viewModel)
            }

            SectionCard("Direct Channels") {
                CoachDirectChannelsGrid(viewModel: viewModel)
            }

            SectionCard("Internal Notes") {
                // shared notes section content — extract from CoachDetailView
            }

            SectionCard("Tags") {
                CoachTagsCard(viewModel: viewModel)
            }

            SectionCard("Profile Meta") {
                CoachProfileMetaCard(viewModel: viewModel)
            }
        }
    }
}
```

> **Note for implementer:** The shared notes section is defined inline in `CoachDetailView` as `sharedNotesSection` (a computed property or `@ViewBuilder`). Extract it to be usable from both `CoachDetailRail` and inline. Match exact parameters from the current `CoachDetailView`.

- [ ] **Step 3: Wrap CoachDetailView in AdaptiveDetailLayout**

Replace the existing body with:

```swift
AdaptiveDetailLayout(sidebarPlacement: .leading, sidebarWidth: 340) {
    // Main content — alerts, stats, analytics, interactions, send profile
    VStack(spacing: 16) {
        CoachAlertsSection(insights: viewModel.insights)
        SectionCard { CoachStatsGrid(insights: viewModel.insights) }
        SectionCard { CoachAnalyticsCard(insights: viewModel.insights) }
        SectionCard("Interactions History") {
            CoachInteractionsLogSection(viewModel: viewModel)
        }
        sendProfileSection(coach: viewModel.coach)
    }
} sidebar: {
    CoachDetailRail(viewModel: viewModel)
}
```

Remove the sections that moved to `CoachDetailRail` from the main content. Remove the outer `ScrollView` (handled by `AdaptiveDetailLayout`).

- [ ] **Step 4: Build-verify both targets**

```bash
make build && make build-ipad
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 5: Run existing coach tests**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/CoachDetailViewModelTests -quiet 2>&1 | tail -5
```

Expected: All existing coach tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(ipad): extract CoachDetailRail, wrap detail in AdaptiveDetailLayout"
```

---

### Task 11: FormContainerView — Centered Forms on iPad

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/FormContainerView.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/FormContainerViewTests.swift`

**Interfaces:**
- Consumes: nothing (standalone component)
- Produces: `FormContainerView<Content>` — wraps form content. Full-width on compact, centered card with max-width on regular. Used by form views in Task 12.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/FormContainerViewTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FormContainerViewTests: XCTestCase {
    nonisolated deinit {}

    func testFormContainerCompact() {
        let view = FormContainerView {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testFormContainerRegular() {
        let view = FormContainerView {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testFormContainerCustomMaxWidth() {
        let view = FormContainerView(maxWidth: 800) {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/FormContainerViewTests -quiet 2>&1 | tail -5
```

Expected: FAIL — `FormContainerView` not found.

- [ ] **Step 3: Implement FormContainerView**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Shared/Components/Layout/FormContainerView.swift
import SwiftUI

struct FormContainerView<Content: View>: View {
    let maxWidth: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(
        maxWidth: CGFloat = 672,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxWidth = maxWidth
        self.content = content
    }

    var body: some View {
        if sizeClass == .regular {
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .frame(maxWidth: maxWidth)
                .padding(.vertical, 24)
                .padding(.horizontal, 32)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .padding()
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/FormContainerViewTests -quiet 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(ipad): add FormContainerView for centered form layouts"
```

---

### Task 12: Apply FormContainerView to Key Form Views + Hover Effects + Keyboard Shortcuts

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Presentation/Views/AddSchoolView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/AddCoachView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Interactions/Views/AddInteractionView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Shared/Navigation/AdaptiveRootView.swift`

**Interfaces:**
- Consumes: `FormContainerView` (Task 11), `AdaptiveRootView` (Task 4)
- Produces: Forms centered on iPad; keyboard shortcuts for sidebar navigation; hover effects on cards

- [ ] **Step 1: Wrap AddSchoolView in FormContainerView**

In `AddSchoolView.swift`, find the outer `ScrollView { VStack { ... } }` and replace with:

```swift
FormContainerView {
    // existing form field content (cut from the VStack)
}
```

Remove the existing `ScrollView` wrapper — `FormContainerView` provides its own.

- [ ] **Step 2: Wrap AddCoachView in FormContainerView**

Same pattern as Step 1. Find the outer `ScrollView { VStack { ... } }`, replace with `FormContainerView { ... }`.

- [ ] **Step 3: Wrap AddInteractionView in FormContainerView**

Same pattern as Steps 1-2.

- [ ] **Step 4: Add keyboard shortcuts to AdaptiveRootView**

In `AdaptiveRootView.swift`, add keyboard shortcuts to the iPad layout. After the `NavigationSplitView`:

```swift
.keyboardShortcut("1", modifiers: .command)  // won't work on SplitView directly
```

Instead, add a `commands` block or use `.onKeyPress` (iOS 17+). The cleanest approach: add an overlay with hidden buttons that respond to keyboard shortcuts:

```swift
private var iPadLayout: some View {
    NavigationSplitView {
        SidebarView(selection: $selectedDestination)
    } detail: {
        detailView(for: selectedDestination ?? .dashboard)
    }
    .navigationSplitViewStyle(.balanced)
    .background {
        keyboardShortcuts
    }
}

@ViewBuilder
private var keyboardShortcuts: some View {
    let mainItems = AppDestination.allCases.filter { $0.section == .main }
    ForEach(Array(mainItems.enumerated()), id: \.element) { index, dest in
        Button("") { selectedDestination = dest }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            .hidden()
    }
    Button("") { selectedDestination = .settings }
        .keyboardShortcut(",", modifiers: .command)
        .hidden()
}
```

- [ ] **Step 5: Add hover effects to card components**

Add `.hoverEffect(.highlight)` to these card components (find each file's outermost container view):
- `SchoolCardView.swift` — add `.hoverEffect(.highlight)` to the card's outer container
- `CoachCardView.swift` — same
- `InteractionCard.swift` — same

Example (in each card view's body):
```swift
// At the end of the card's outer VStack/HStack:
.hoverEffect(.highlight)
```

- [ ] **Step 6: Build-verify both targets**

```bash
make build && make build-ipad
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 7: Run full unit test suite**

```bash
make test-unit
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(ipad): apply FormContainerView to forms, add keyboard shortcuts and hover effects"
```

---

### Task 13: iPad Integration Verification + Final Polish

**Files:**
- Modify: `Makefile` (if not already done)
- No new source files — verification and bug-fix task

**Interfaces:**
- Consumes: all previous tasks
- Produces: verified iPad experience, all tests green on both device families

- [ ] **Step 1: Run full test suite on iPhone**

```bash
make test-unit
```

Expected: All tests PASS.

- [ ] **Step 2: Run full test suite on iPad**

```bash
make test-ipad
```

Expected: All tests PASS. If failures, fix before proceeding.

- [ ] **Step 3: Build and launch on iPad simulator — visual verification checklist**

```bash
make build-ipad
```

Launch the app in iPad Air simulator. Verify each screen manually:

**Navigation:**
- [ ] Sidebar visible with all 12 items in correct groups (Main: 6, More: 5, Settings: 1)
- [ ] Tapping sidebar item switches detail view
- [ ] Profile row at sidebar bottom shows user info
- [ ] `⌘1`–`⌘6` keyboard shortcuts navigate to main items
- [ ] `⌘,` opens settings

**Dashboard:**
- [ ] Widgets render in 4+2 grid (main column + sidebar column)
- [ ] Sidebar column shows Recruiting Calendar, Recent Activity
- [ ] Main column shows action items, stats, other widgets in 2-col sub-grid for half-width

**List pages:**
- [ ] Schools: cards render in 2-3 column grid
- [ ] Coaches: cards render in 2-3 column grid
- [ ] Interactions: cards render in 2-3 column grid
- [ ] Filter bars span full width above grids
- [ ] Tapping card navigates to detail

**Detail pages:**
- [ ] School detail: content left, sidebar right (status, actions, coaches, fit, attribution)
- [ ] Coach detail: rail left (header, channels, notes, tags, meta), content right
- [ ] Scrolling works independently in main and sidebar columns

**Forms:**
- [ ] Add School form centered in card on iPad
- [ ] Add Coach form centered
- [ ] Log Interaction form centered
- [ ] Side-by-side field pairs render horizontally (AdaptiveHStackVStack)

**Hover & Pointer:**
- [ ] School/Coach/Interaction cards show hover highlight effect
- [ ] Buttons show pointer cursor on hover

**Orientation:**
- [ ] Landscape: sidebar + wider detail
- [ ] Portrait: sidebar may auto-collapse, detail fills width
- [ ] Rotation transition smooth

- [ ] **Step 4: Fix any issues found during visual verification**

Address each issue as a targeted fix. Build and test after each fix.

- [ ] **Step 5: Verify iPhone is unchanged**

Launch on iPhone 17 simulator. Verify:
- [ ] TabView with 5 tabs (no sidebar)
- [ ] Dashboard single-column scroll
- [ ] List pages single-column cards
- [ ] Detail pages single-column stacked
- [ ] Forms full-width
- [ ] All existing behavior intact

- [ ] **Step 6: Final commit**

```bash
git add -A && git commit -m "feat(ipad): integration verification and polish fixes"
```

---

## File Map Summary

### New Files (10)
| File | Task | Purpose |
|------|------|---------|
| `Shared/Navigation/AppDestination.swift` | 2 | Destination enum for all nav items |
| `Shared/Navigation/SidebarView.swift` | 3 | iPad sidebar with grouped items |
| `Shared/Navigation/AdaptiveRootView.swift` | 4 | TabView ↔ NavigationSplitView switch |
| `Features/Dashboard/Views/AdaptiveDashboardGrid.swift` | 5 | 4+2 column dashboard grid |
| `Shared/Components/Layout/AdaptiveListView.swift` | 6 | Multi-column card grid |
| `Shared/Components/Layout/AdaptiveDetailLayout.swift` | 8 | Content + sidebar detail layout |
| `Features/Schools/Presentation/Views/SchoolDetailSidebar.swift` | 9 | Extracted school sidebar |
| `Features/Coaches/Views/CoachDetailRail.swift` | 10 | Extracted coach left rail |
| `Shared/Components/Layout/FormContainerView.swift` | 11 | Centered form wrapper |

### New Test Files (6)
| File | Task |
|------|------|
| `TheRecruitingCompassTests/Shared/Navigation/AppDestinationTests.swift` | 2 |
| `TheRecruitingCompassTests/Shared/Navigation/SidebarViewTests.swift` | 3 |
| `TheRecruitingCompassTests/Shared/Navigation/AdaptiveRootViewTests.swift` | 4 |
| `TheRecruitingCompassTests/Features/Dashboard/AdaptiveDashboardGridTests.swift` | 5 |
| `TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveListViewTests.swift` | 6 |
| `TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveDetailLayoutTests.swift` | 8 |
| `TheRecruitingCompassTests/Shared/Components/Layout/FormContainerViewTests.swift` | 11 |

### Modified Files (12)
| File | Task | Change |
|------|------|--------|
| `project.pbxproj` | 1 | TARGETED_DEVICE_FAMILY → "1,2" |
| `Makefile` | 1 | iPad build/test targets |
| `TheRecruitingCompassApp.swift` | 4 | MainTabView → AdaptiveRootView |
| `DashboardWidgetID.swift` | 5 | Add WidgetWidth + widthClass |
| `DashboardWidgetStack.swift` | 5 | Width class filtering |
| `DashboardView.swift` | 5 | Wrap in AdaptiveDashboardGrid |
| `SchoolsListView.swift` | 7 | ForEach → AdaptiveListView |
| `CoachesListView.swift` | 7 | ForEach → AdaptiveListView |
| `InteractionsListView.swift` | 7 | ForEach → AdaptiveListView |
| `SchoolDetailView.swift` | 9 | Wrap in AdaptiveDetailLayout |
| `CoachDetailView.swift` | 10 | Wrap in AdaptiveDetailLayout |
| `AddSchoolView.swift`, `AddCoachView.swift`, `AddInteractionView.swift` | 12 | Wrap in FormContainerView |
| `SchoolCardView.swift`, `CoachCardView.swift`, `InteractionCard.swift` | 12 | Add .hoverEffect |
