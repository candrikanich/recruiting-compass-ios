# Native iPad Experience — Design Spec

**Date:** 2026-08-30
**Status:** Draft
**Goal:** Transform the iPhone-only app into a full native iPad app that feels like the web app on larger screens, not a scaled-up phone app. Ship alongside iPhone App Store launch.

---

## Context

The app was built with `TARGETED_DEVICE_FAMILY = "1,2"` from inception, flipped to iPhone-only (`1`) for initial App Store submission. No iPad-specific code was removed. The codebase is pure SwiftUI with a TabView + per-tab NavigationStack architecture. One adaptive component exists (`AdaptiveHStackVStack`).

The web app (Nuxt/Tailwind) is the layout reference for wider screens:
- Top nav bar (5 main + 7 overflow items)
- Dashboard: 6-col CSS grid (4 content + 2 sidebar) at `lg:` (1024px)
- List pages: 3-column card grids at `lg:`
- School detail: 2+1 (content + right sidebar)
- Coach detail: 340px left rail + flex content
- Forms: centered narrow card (`max-w-2xl`)

---

## Navigation Architecture

### AppDestination Enum

```swift
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

    enum SidebarSection: String, CaseIterable {
        case main, more, bottom
    }
}
```

### AdaptiveRootView

Top-level wrapper replacing `MainTabView` in the app entry point.

- **`.compact` (iPhone):** Renders existing `MainTabView` unchanged. All 5 tabs preserved. Items not in tabs (Events, Performance, etc.) remain under More tab.
- **`.regular` (iPad):** Renders `NavigationSplitView` with:
  - **Sidebar:** Grouped `List` with `selection` binding to `AppDestination?`. SF Symbols per item. Section headers for Main / More. Settings + profile pinned at bottom.
  - **Detail:** Selected destination's view, each wrapped in its own `NavigationStack` for push navigation within that section.
  - Default selection: `.dashboard` on launch.

Deep link and push notification routing flows through a shared `navigate(to:)` method that sets `selectedDestination` (iPad) or switches tab + pushes path (iPhone).

### Files

| File | Action |
|------|--------|
| `Shared/Navigation/AppDestination.swift` | New — destination enum |
| `Shared/Navigation/AdaptiveRootView.swift` | New — size-class switch |
| `Shared/Navigation/SidebarView.swift` | New — iPad sidebar |
| `TheRecruitingCompassApp.swift` | Modify — swap `MainTabView` → `AdaptiveRootView` |
| `MainTabView.swift` | Unchanged — used by compact path |

---

## Dashboard — Multi-Column Widget Grid

### Layout

- **`.compact`:** Current single-column vertical scroll. No change.
- **`.regular`:** 6-column grid system mirroring web:
  - **Main column (4/6):** Widgets flow in 2-col sub-grid for `.half` width, full-width for `.full`.
  - **Sidebar column (2/6):** Fixed widgets stacked vertically — Public Profile Link, Recruiting Calendar, Contact Frequency, Athlete Activity.

### Widget Width Classification

Add `widthClass` to `DashboardWidgetConfig`:

```swift
enum WidgetWidth {
    case full    // spans entire main column
    case half    // shares row with another .half widget
    case sidebar // pinned to right sidebar column (iPad only)
}
```

Widgets with `.sidebar` width render inline (in normal scroll order) on iPhone, move to sidebar column on iPad.

### AdaptiveDashboardGrid

Reads `horizontalSizeClass`. On `.regular`, separates widgets into main vs sidebar groups, renders main group in a `LazyVGrid` with flexible 2-column layout, sidebar group in a fixed-width `VStack`.

### Files

| File | Action |
|------|--------|
| `Features/Dashboard/Views/AdaptiveDashboardGrid.swift` | New |
| `Features/Dashboard/Views/DashboardView.swift` | Modify — use adaptive grid |
| `Features/Dashboard/Models/DashboardWidgetConfig.swift` | Modify — add `widthClass` |
| All widget views | Unchanged — fill container |

---

## List Pages — Multi-Column Cards + Master-Detail

### Applies To

Schools, Coaches, Interactions, Events, Offers

### Two Modes (iPad)

**Mode A — Multi-column card grid (default):**
- `LazyVGrid` with adaptive columns
- Portrait: 2 columns. Landscape: 3 columns.
- Filter bar full-width above grid
- Tap card → push detail within NavigationStack

**Mode B — Master-detail split (optional, per-page):**
- Inner `NavigationSplitView` (two-column) within detail pane
- Left: compact list rows (not full cards)
- Right: full detail view
- Toggle between Mode A and Mode B via toolbar button
- User preference stored in `UserDefaults` per list page

### AdaptiveListView\<Item\>

Generic wrapper component:

```swift
struct AdaptiveListView<Item: Identifiable, CardContent: View>: View {
    let items: [Item]
    let cardContent: (Item) -> CardContent
    let onSelect: (Item) -> Void

    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        if sizeClass == .regular {
            LazyVGrid(columns: adaptiveColumns, spacing: 16) {
                ForEach(items) { item in
                    cardContent(item)
                        .onTapGesture { onSelect(item) }
                }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    cardContent(item)
                        .onTapGesture { onSelect(item) }
                }
            }
        }
    }
}
```

### ListDetailSplitView

Optional master-detail wrapper for pages that opt in. Manages its own `NavigationSplitView` with list selection state.

### Files

| File | Action |
|------|--------|
| `Shared/Components/Layout/AdaptiveListView.swift` | New |
| `Shared/Components/Layout/ListDetailSplitView.swift` | New |
| `Features/Schools/Presentation/Views/SchoolsListView.swift` | Modify — wrap in adaptive |
| `Features/Coaches/Views/CoachesListView.swift` | Modify — wrap in adaptive |
| `Features/Interactions/Views/InteractionsListView.swift` | Modify — wrap in adaptive |
| Card components | Unchanged |

---

## Detail Page Sidebars

### AdaptiveDetailLayout

Generic two-pane wrapper for detail views:

```swift
struct AdaptiveDetailLayout<Content: View, Sidebar: View>: View {
    let sidebarPlacement: SidebarPlacement // .leading or .trailing
    let sidebarWidth: CGFloat // ~300pt default
    let content: () -> Content
    let sidebar: () -> Sidebar

    @Environment(\.horizontalSizeClass) var sizeClass

    enum SidebarPlacement { case leading, trailing }

    var body: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 0) {
                if sidebarPlacement == .leading {
                    sidebarColumn
                }
                ScrollView { content() }
                    .frame(maxWidth: .infinity)
                if sidebarPlacement == .trailing {
                    sidebarColumn
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    content()
                    sidebar()
                }
            }
        }
    }
}
```

### School Detail

- `sidebarPlacement: .trailing` (right sidebar, matches web)
- Sidebar content extracted to `SchoolDetailSidebar`:
  - Status Pipeline (SchoolStatusStepper)
  - Quick Actions (Log Interaction, Send Email, Manage Coaches)
  - Coaches at this school
  - School Fit signals
  - Attribution

### Coach Detail

- `sidebarPlacement: .leading` (left rail, matches web)
- Rail content extracted to `CoachDetailRail`:
  - Avatar + identity card
  - Channel action buttons (Email, Text, DM)
  - Internal notes
  - Tags + source
  - Profile link

### Files

| File | Action |
|------|--------|
| `Shared/Components/Layout/AdaptiveDetailLayout.swift` | New |
| `Features/Schools/Presentation/Views/SchoolDetailSidebar.swift` | New — extracted from SchoolDetailView |
| `Features/Coaches/Views/CoachDetailRail.swift` | New — extracted from CoachDetailView |
| `Features/Schools/Presentation/Views/SchoolDetailView.swift` | Modify — wrap in AdaptiveDetailLayout |
| `Features/Coaches/Views/CoachDetailView.swift` | Modify — wrap in AdaptiveDetailLayout |

---

## Polish

### Forms — Centered Card Layout

**`FormContainerView`** wraps form content:
- `.compact`: Full-width with standard padding (current behavior)
- `.regular`: Centered card with `maxWidth(672)` + subtle background/shadow

Side-by-side field pairs via existing `AdaptiveHStackVStack` (City+State, First+Last name).

Apply to: Add School, Add Coach, Log Interaction, Edit Profile, all Settings sub-pages.

### Orientation & Multitasking

- Info.plist: Add `UISupportedInterfaceOrientations~ipad` with all 4 orientations
- iPhone stays portrait-only via existing config
- `NavigationSplitView` with `.balanced` style handles Slide Over, Split View, Stage Manager automatically
- Test graceful degradation: sidebar collapses at narrow widths, layouts fall back to compact

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘1`–`⌘6` | Navigate to Main sidebar items |
| `⌘N` | New item (context-dependent) |
| `⌘F` | Focus search |
| `Esc` | Dismiss modal/sheet |
| `⌘,` | Settings |

Register via `.keyboardShortcut()` on sidebar items and toolbar buttons.

### Pointer & Hover

- `.hoverEffect(.highlight)` on all cards, buttons, tappable list rows
- Context menus on cards (verify existing coverage, add where missing)
- Cursor changes on interactive elements (SwiftUI default with `.hoverEffect`)

### Drag & Drop (Stretch Goal — Post-Launch)

- Drag-reorder dashboard widgets
- Drag coach cards between contexts
- Not required for initial iPad launch

### Files

| File | Action |
|------|--------|
| `Shared/Components/Layout/FormContainerView.swift` | New |
| `Config/Info.plist` | Modify — iPad orientations |
| All form views | Modify — wrap in FormContainerView |
| Card components | Modify — add `.hoverEffect` |
| `AdaptiveRootView.swift` | Modify — keyboard shortcuts |

---

## Testing Strategy

### Unit Tests — Size-Class Injection

Test adaptive components with injected size class:

```swift
func testDashboardShowsGridOnRegular() {
    let view = AdaptiveDashboardGrid(widgets: mockWidgets)
        .environment(\.horizontalSizeClass, .regular)
    // Assert grid layout rendered
}

func testDashboardShowsStackOnCompact() {
    let view = AdaptiveDashboardGrid(widgets: mockWidgets)
        .environment(\.horizontalSizeClass, .compact)
    // Assert single-column layout rendered
}
```

Test both paths for every adaptive component:
- `AdaptiveRootView` (TabView vs SplitView)
- `AdaptiveDashboardGrid` (stack vs grid)
- `AdaptiveListView` (single vs multi-column)
- `AdaptiveDetailLayout` (stacked vs side-by-side)
- `FormContainerView` (full-width vs centered)

### Integration Tests — iPad Simulators

Add iPad targets to test matrix:
- **iPad Air (11")** — portrait 820×1180, landscape 1180×820
- **iPad Pro 13"** — portrait 1024×1366, landscape 1366×1024

Verify:
- Sidebar renders and selection works
- Dashboard widgets arrange in 2-column grid
- List pages show multi-column cards
- Detail sidebars render alongside content
- Forms center properly
- All orientations + rotation transitions
- Slide Over / Split View graceful degradation

### Makefile Updates

```makefile
test-ipad:
	cd TheRecruitingCompass && xcodebuild test \
	  -scheme TheRecruitingCompass \
	  -destination 'platform=iOS Simulator,name=iPad Air'

test-all-devices:
	make test-unit
	make test-ipad
```

---

## Implementation Phases

### Phase 0: Project Settings (< 1 hour)
- Revert `TARGETED_DEVICE_FAMILY` to `"1,2"`
- Add iPad orientations to Info.plist
- Add iPad simulator targets to Makefile
- Verify app launches on iPad simulator (scaled iPhone layout — baseline)

### Phase 1: Navigation Shell (1-2 days)
- `AppDestination` enum
- `SidebarView` with grouped items
- `AdaptiveRootView` switching TabView ↔ NavigationSplitView
- Deep link / push notification routing through shared method
- Tests: size-class injection for both paths

### Phase 2: Dashboard Grid (1 day)
- `AdaptiveDashboardGrid` with 4+2 column layout
- `widthClass` on `DashboardWidgetConfig`
- Widget sorting into main vs sidebar columns
- Tests: grid vs stack rendering

### Phase 3: List Pages (2-3 days)
- `AdaptiveListView` generic component
- Apply to Schools, Coaches, Interactions, Events, Offers
- `ListDetailSplitView` for opt-in master-detail
- Tests: column counts at different size classes

### Phase 4: Detail Sidebars (2 days)
- `AdaptiveDetailLayout` with leading/trailing placement
- Extract `SchoolDetailSidebar` and `CoachDetailRail`
- Wrap detail views in adaptive layout
- Tests: stacked vs side-by-side rendering

### Phase 5: Polish (1-2 days)
- `FormContainerView` for centered forms
- `.hoverEffect` on interactive elements
- Keyboard shortcuts
- Orientation + multitasking verification
- iPad simulator integration tests

**Total estimate: 7-10 days**

---

## Shared Adaptive Components Summary

| Component | Purpose | Size-Class Behavior |
|-----------|---------|-------------------|
| `AdaptiveRootView` | App shell | TabView ↔ NavigationSplitView |
| `SidebarView` | iPad nav | Grouped list with sections |
| `AdaptiveDashboardGrid` | Dashboard layout | VStack ↔ 6-col grid |
| `AdaptiveListView<Item>` | List pages | Single col ↔ multi-col grid |
| `ListDetailSplitView` | Optional master-detail | Push ↔ inline split |
| `AdaptiveDetailLayout` | Detail pages | Stacked ↔ sidebar |
| `FormContainerView` | Forms | Full-width ↔ centered card |
| `AdaptiveHStackVStack` | Field pairs | Already exists |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| NavigationSplitView bugs in iOS 26 beta | Test early (Phase 1), fall back to manual HStack if needed |
| Widget sizing inconsistencies on iPad | Each widget should use `maxWidth(.infinity)` — verify all |
| Deep link routing divergence (TabView vs SplitView) | Shared `navigate(to:)` method, tested for both paths |
| Keyboard shortcut conflicts with system | Use standard Apple conventions, test on hardware |
| Timeline pressure vs quality | Phase 0-1 are gating; Phases 2-5 can ship incrementally |

---

## Open Questions

None — all decisions locked during design review.
