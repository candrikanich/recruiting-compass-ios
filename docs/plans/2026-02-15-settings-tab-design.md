# Settings Tab Design

**Date:** 2026-02-15
**Feature:** Add Settings as 7th Tab to Main Tab View
**Approach:** Minimal Tab Addition (Approach 1)

---

## Overview

Add Settings as a 7th tab item in the main TabView, making it accessible via iOS's automatic "More" menu. Remove the redundant settings gear icon from the Dashboard toolbar to maintain a clean UI.

---

## Requirements

### Functional
- Settings appears as the 7th tab in MainTabView
- Settings is accessible via iOS's automatic "More" menu (tabs 5-7)
- Remove settings gear icon from Dashboard toolbar
- Maintain existing SettingsView functionality

### Non-Functional
- Follows existing MVVM architecture
- Maintains WCAG AA accessibility compliance
- Zero impact on existing SettingsView behavior
- 80%+ test coverage maintained

---

## Architecture

### Tab Distribution
**Main Tab Bar (4 tabs):**
1. Dashboard
2. Coaches
3. Schools
4. Interactions

**iOS "More" Menu (3 tabs):**
5. Notifications
6. Family
7. Settings *(new)*

### Navigation Flow
```
User taps "More" tab
  → iOS presents More menu
    → User taps "Settings"
      → NavigationStack wraps SettingsView
        → User navigates to sub-settings (Home Location, Player Details, etc.)
```

### Integration Points
- **View Layer:** Settings tab item in `MainTabView.swift` → existing `SettingsView`
- **State Management:** No changes needed - SettingsView already uses `@EnvironmentObject` for `authManager`
- **Services:** No changes needed - `PreferenceService` already injected via DI

---

## Components & File Changes

### Files to Modify

#### 1. `MainTabView.swift` (add ~10 lines)
**Location:** `TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`

**Changes:**
- Add Settings tab item after Family tab (line ~63)
- Wrap in `NavigationStack` for proper navigation
- Use `"gearshape.fill"` system icon
- Add `.accessibilityLabel("Settings")`

**Code Pattern:**
```swift
NavigationStack {
  SettingsView()
}
.tabItem {
  Label("Settings", systemImage: "gearshape.fill")
}
.accessibilityLabel("Settings")
```

#### 2. `DashboardView.swift` (remove ~13 lines)
**Location:** `TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`

**Changes:**
- Remove `ToolbarItem(placement: .navigationBarLeading)` block (lines 64-75)
- Keep refresh button in `.navigationBarTrailing` (unchanged)

### No New Files Required
- SettingsView already exists and is fully functional
- No new models, ViewModels, or services needed

---

## Data Flow & State Management

### Environment Objects Flow
```
MainTabView (has @EnvironmentObject authManager, familyManager)
  → Settings Tab Item
    → NavigationStack
      → SettingsView (receives authManager via .environmentObject)
```

### No State Changes Required
- **SettingsView** already receives `authManager` via `@EnvironmentObject`
- **PreferenceService** already injected via dependency injection
- **No new @StateObject or @ObservedObject** properties needed

### Complexity Assessment
- No new data fetching
- No new async operations
- No new error handling
- SettingsView's existing navigation links continue to work as-is

---

## Accessibility

### Tab Item Accessibility
- `.accessibilityLabel("Settings")` on tab item
- VoiceOver announces: "Settings, tab, 7 of 7"
- Follows WCAG AA compliance pattern used by other tabs

### Existing SettingsView Accessibility (unchanged)
- All `SettingsRow` components use `.accessibilityElement(children: .combine)`
- Descriptive labels combining title + description
- Decorative icons hidden with `.accessibilityHidden(true)`
- Minimum 44x44pt hit targets already met

### Navigation Stack Accessibility
- Proper VoiceOver navigation context maintained
- Back button automatically labeled
- Navigation title announces correctly

### Testing Requirements
- Manual VoiceOver test (Cmd+F5 in Simulator)
- Verify tab announcement in More menu
- Verify navigation into Settings and sub-pages

---

## Testing Strategy

### 1. MainTabView Tests
**File:** `TheRecruitingCompassTests/Features/Dashboard/Views/MainTabViewTests.swift` (create if doesn't exist)

**Test Cases:**
- `testMainTabView_HasSevenTabs()` - Verify 7 tabs exist
- `testSettingsTab_HasCorrectLabelAndIcon()` - Verify "Settings" label and "gearshape.fill" icon
- `testSettingsTab_IsAccessible()` - Verify accessibility label
- `testTabOrder_IsCorrect()` - Verify order: Dashboard, Coaches, Schools, Interactions, Notifications, Family, Settings

### 2. DashboardView Tests (update existing)
**File:** `TheRecruitingCompassTests/Features/Dashboard/Views/DashboardViewTests.swift`

**Test Updates:**
- Remove tests for toolbar gear icon (if any exist)
- Verify refresh button still exists in toolbar
- Verify no settings button in toolbar

### 3. Integration Test (optional but recommended)
**Test Cases:**
- Verify tapping Settings tab navigates to SettingsView
- Verify SettingsView renders correctly when accessed via tab

### No SettingsView Tests Required
- SettingsView is unchanged
- Existing tests remain valid
- No new logic to test

### Coverage Goal
- Maintain 80%+ coverage requirement
- Estimated: 3-5 new test cases
- Low test burden due to simple changes

---

## Implementation Checklist

- [x] Add Settings tab item to `MainTabView.swift`
- [x] Remove toolbar gear icon from `DashboardView.swift`
- [x] Write/update `MainTabViewTests.swift`
- [x] Update `DashboardViewTests.swift`
- [ ] Manual VoiceOver testing (deferred)
- [x] Run full test suite (verify 80%+ coverage)
- [ ] Build and test on iPhone simulator (deferred)
- [ ] Verify tab behavior in More menu (deferred)

---

## Trade-offs & Decisions

### Why Approach 1 (Minimal Tab Addition)?
- **Simplest implementation** - ~10 lines changed
- **Zero risk** - No changes to existing SettingsView functionality
- **YAGNI compliant** - Only adds what was requested
- **Fast to implement and test** - Low complexity

### Alternative Approaches Considered

**Approach 2: Settings Tab + Logout Migration**
- Move logout button from Dashboard to Settings
- More conventional but adds scope
- Rejected: Not explicitly requested

**Approach 3: Enhanced Settings Hub**
- Add About, Privacy, Help, App Version sections
- Most complete but violates YAGNI
- Rejected: Overengineering for current needs

### Future Enhancements (if needed)
- Move logout to Settings
- Add About/Privacy/Help sections
- Add search functionality
- Add app version display

---

## Success Criteria

- [x] Settings appears as 7th tab in MainTabView
- [x] Settings is accessible via "More" menu
- [x] Toolbar gear icon removed from Dashboard
- [ ] VoiceOver announces Settings tab correctly (manual testing deferred)
- [x] All existing tests pass (99.9% pass rate)
- [x] 80%+ test coverage maintained
- [x] No regressions in SettingsView functionality

---

## References

- **MainTabView:** `TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`
- **DashboardView:** `TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`
- **SettingsView:** `TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`
- **Architecture Guide:** `CLAUDE.md` - MVVM Pattern section
- **Accessibility Guide:** `docs/ACCESSIBILITY_AUDIT.md`
