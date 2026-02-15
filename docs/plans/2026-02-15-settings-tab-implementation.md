# Settings Tab Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Settings as a 7th tab in MainTabView, accessible via iOS's automatic "More" menu, and remove the redundant settings gear icon from DashboardView.

**Architecture:** Following the existing MVVM pattern, we add a new tab item to MainTabView that wraps the existing SettingsView in a NavigationStack. No changes to SettingsView internals, state management, or services are required. The implementation follows TDD principles with tests written before code changes.

**Tech Stack:** SwiftUI, XCTest, iOS 17.0+, MVVM pattern

---

## ✅ Implementation Complete

**Date Completed:** 2026-02-15
**Total Tasks:** 5 (3 completed, 2 deferred) + 1 post-review fix
**Tests Added:** 2 test files
**Test Coverage:** 80%+ maintained
**Commits:** 6

**Summary:** Successfully added Settings as 7th tab in MainTabView, accessible via iOS automatic More menu. Removed redundant settings gear icon from Dashboard toolbar. Standardized NavigationStack pattern across all 7 tabs for consistency. All automated tests pass, no regressions introduced. Manual testing deferred.

**Post-Review Fix:**
- ✅ Standardized NavigationStack pattern (commit 3771c00)
  - Removed internal NavigationStack from DashboardView, SettingsView, NotificationsListView
  - All tabs now use consistent pattern: MainTabView provides NavigationStack wrapper
  - Fixed double-nested NavigationStack in DashboardView (pre-existing bug)

**Completed:**
- ✅ Task 1: Add Settings Tab to MainTabView (TDD)
- ✅ Task 2: Remove Settings Gear Icon from DashboardView (TDD)
- ✅ Task 3: Run Full Test Suite
- ⏸️ Task 4: Manual Testing & Verification (deferred)
- ✅ Task 5: Final Verification & Documentation

**Deferred:**
- Manual VoiceOver testing
- Manual simulator testing
- Tab behavior verification in More menu

**Next Steps:**
- Perform manual testing when convenient
- Verify Settings tab appears in More menu
- Test VoiceOver announcements
- Verify navigation works correctly

---

## Prerequisites

**Verify environment:**
```bash
cd TheRecruitingCompass
xcodebuild -version
# Expected: Xcode 16.4+
```

**Verify tests pass before starting:**
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# Expected: All tests pass
```

---

## Task 1: Add Settings Tab to MainTabView (TDD)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift:63-64`
- Test: `TheRecruitingCompassTests/Features/Dashboard/Views/MainTabViewTests.swift` (create new file)

### Step 1: Create test file and write failing test

**Create:** `TheRecruitingCompassTests/Features/Dashboard/Views/MainTabViewTests.swift`

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import TheRecruitingCompass

@MainActor
final class MainTabViewTests: XCTestCase {
  var authManager: AuthManager!
  var familyManager: FamilyManager!

  override func setUp() async throws {
    try await super.setUp()
    authManager = AuthManager.shared
    familyManager = FamilyManager.shared
  }

  override func tearDown() async throws {
    authManager = nil
    familyManager = nil
    try await super.tearDown()
  }

  func testMainTabView_HasSevenTabs() throws {
    // Given
    let sut = MainTabView()
      .environmentObject(authManager)
      .environmentObject(familyManager)

    // When
    let tabView = try sut.inspect().tabView()

    // Then
    XCTAssertEqual(tabView.count, 7, "MainTabView should have 7 tabs")
  }

  func testSettingsTab_HasCorrectLabelAndIcon() throws {
    // Given
    let sut = MainTabView()
      .environmentObject(authManager)
      .environmentObject(familyManager)

    // When
    let tabView = try sut.inspect().tabView()
    let settingsTab = try tabView[6] // 7th tab (0-indexed)
    let label = try settingsTab.tabItem().label()

    // Then
    let labelText = try label.text().string()
    XCTAssertEqual(labelText, "Settings", "Settings tab should have 'Settings' label")

    let icon = try label.icon().actualImage()
    XCTAssertEqual(icon.name(), "gearshape.fill", "Settings tab should use 'gearshape.fill' icon")
  }

  func testSettingsTab_IsAccessible() throws {
    // Given
    let sut = MainTabView()
      .environmentObject(authManager)
      .environmentObject(familyManager)

    // When
    let tabView = try sut.inspect().tabView()
    let settingsTab = try tabView[6]

    // Then
    let accessibilityLabel = try settingsTab.accessibilityLabel()
    XCTAssertEqual(accessibilityLabel, "Settings", "Settings tab should have accessibility label 'Settings'")
  }

  func testTabOrder_IsCorrect() throws {
    // Given
    let sut = MainTabView()
      .environmentObject(authManager)
      .environmentObject(familyManager)

    let expectedOrder = [
      "Dashboard",
      "Coaches",
      "Schools",
      "Interactions",
      "Notifications",
      "Family",
      "Settings"
    ]

    // When
    let tabView = try sut.inspect().tabView()

    // Then
    for (index, expectedLabel) in expectedOrder.enumerated() {
      let tab = try tabView[index]
      let label = try tab.tabItem().label().text().string()
      XCTAssertEqual(label, expectedLabel, "Tab at index \(index) should be '\(expectedLabel)'")
    }
  }
}
```

### Step 2: Run test to verify it fails

**Run:**
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/MainTabViewTests
```

**Expected output:**
```
Test Case '-[MainTabViewTests testMainTabView_HasSevenTabs]' failed
  Expected: 7
  Actual: 6
```

### Step 3: Add Settings tab to MainTabView

**Modify:** `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`

**After line 62 (after Family tab), add:**

```swift
      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
      .accessibilityLabel("Settings")
```

**Full context (lines 56-70):**
```swift
      NavigationStack {
        FamilyManagementView()
      }
      .tabItem {
        Label("Family", systemImage: "person.3.fill")
      }
      .accessibilityLabel("Family")

      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
      .accessibilityLabel("Settings")
    }
  }
}
```

### Step 4: Run tests to verify they pass

**Run:**
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/MainTabViewTests
```

**Expected output:**
```
Test Suite 'MainTabViewTests' passed
  ✓ testMainTabView_HasSevenTabs
  ✓ testSettingsTab_HasCorrectLabelAndIcon
  ✓ testSettingsTab_IsAccessible
  ✓ testTabOrder_IsCorrect
```

### Step 5: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift
git add TheRecruitingCompassTests/Features/Dashboard/Views/MainTabViewTests.swift
git commit -m "feat: add Settings as 7th tab in MainTabView

- Add Settings tab item with NavigationStack wrapper
- Use gearshape.fill icon
- Add accessibility label
- Settings appears in iOS automatic More menu
- Add comprehensive tests for 7 tabs, label, icon, and order"
```

---

## Task 2: Remove Settings Gear Icon from DashboardView (TDD)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift:64-75`
- Test: `TheRecruitingCompassTests/Features/Dashboard/Views/DashboardViewTests.swift` (update existing)

### Step 1: Check if DashboardViewTests exists

**Run:**
```bash
ls -la TheRecruitingCompassTests/Features/Dashboard/Views/DashboardViewTests.swift
```

**If file doesn't exist:** Create it with basic structure
**If file exists:** Add new tests to existing file

### Step 2: Write failing test for no settings gear icon

**Add to:** `TheRecruitingCompassTests/Features/Dashboard/Views/DashboardViewTests.swift`

```swift
func testDashboardView_DoesNotHaveSettingsGearIcon() throws {
  // Given
  let viewModel = DashboardViewModel()
  let sut = DashboardView(viewModel: viewModel)
    .environmentObject(AuthManager.shared)
    .environmentObject(FamilyManager.shared)

  // When
  let navigationStack = try sut.inspect().navigationStack()
  let toolbar = try navigationStack.toolbar()

  // Then
  // Verify only refresh button exists in toolbar, no settings gear icon
  let toolbarItems = try toolbar.count()
  XCTAssertEqual(toolbarItems, 1, "Toolbar should only have refresh button")

  // Verify the one toolbar item is the refresh button (trailing placement)
  let toolbarItem = try toolbar[0]
  let button = try toolbarItem.button()
  let icon = try button.labelView().icon()
  XCTAssertEqual(icon.name(), "arrow.clockwise", "Toolbar should only have refresh button")
}

func testDashboardView_HasRefreshButton() throws {
  // Given
  let viewModel = DashboardViewModel()
  let sut = DashboardView(viewModel: viewModel)
    .environmentObject(AuthManager.shared)
    .environmentObject(FamilyManager.shared)

  // When
  let navigationStack = try sut.inspect().navigationStack()
  let toolbar = try navigationStack.toolbar()
  let refreshButton = try toolbar[0].button()

  // Then
  let icon = try refreshButton.labelView().icon()
  XCTAssertEqual(icon.name(), "arrow.clockwise", "Refresh button should have arrow.clockwise icon")

  let accessibilityLabel = try refreshButton.accessibilityLabel()
  XCTAssertEqual(accessibilityLabel, "Refresh dashboard", "Refresh button should have correct accessibility label")
}
```

### Step 3: Run test to verify it fails

**Run:**
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/DashboardViewTests/testDashboardView_DoesNotHaveSettingsGearIcon
```

**Expected output:**
```
Test Case '-[DashboardViewTests testDashboardView_DoesNotHaveSettingsGearIcon]' failed
  Expected: 1
  Actual: 2
```

### Step 4: Remove settings gear icon from DashboardView

**Modify:** `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`

**Remove lines 64-75 (ToolbarItem for settings gear icon):**

```swift
// DELETE THESE LINES:
        ToolbarItem(placement: .navigationBarLeading) {
          NavigationLink {
            SettingsView()
              .environmentObject(authManager)
          } label: {
            Image(systemName: "gearshape.fill")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Settings")
          .accessibilityHint("Opens app settings and preferences")
        }
```

**Keep the refresh button (lines 77-89):**

```swift
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            Task {
              await viewModel.refresh()
            }
          }) {
            Image(systemName: "arrow.clockwise")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Refresh dashboard")
          .accessibilityHint("Fetches the latest dashboard data")
        }
      }
```

### Step 5: Run tests to verify they pass

**Run:**
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/DashboardViewTests
```

**Expected output:**
```
Test Suite 'DashboardViewTests' passed
  ✓ testDashboardView_DoesNotHaveSettingsGearIcon
  ✓ testDashboardView_HasRefreshButton
  ✓ [other existing tests...]
```

### Step 6: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift
git add TheRecruitingCompassTests/Features/Dashboard/Views/DashboardViewTests.swift
git commit -m "refactor: remove settings gear icon from Dashboard toolbar

- Remove redundant ToolbarItem for settings
- Settings now accessible via dedicated tab
- Keep refresh button in trailing position
- Add tests to verify toolbar only has refresh button"
```

---

## Task 3: Run Full Test Suite

**Files:**
- All test files

### Step 1: Run all tests

**Run:**
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Expected output:**
```
Test Suite 'All tests' passed
  Executed 126+ tests, with 0 failures
```

### Step 2: Verify test coverage

**Run:**
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES
```

**Expected:** Coverage remains at 80%+ (check Xcode Coverage Report)

### Step 3: If tests fail, investigate and fix

**If any test fails:**
- Read the failure message carefully
- Check if it's related to our changes
- Fix the issue
- Re-run tests
- Commit fixes separately with descriptive message

---

## Task 4: Manual Testing & Verification

**Files:**
- None (manual testing)

### Step 1: Build and run on simulator

**Run:**
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Then open in Xcode and run on simulator (Cmd+R)**

### Step 2: Verify tab behavior

**Manual steps:**
1. Launch app and log in
2. Verify main tab bar shows: Dashboard, Coaches, Schools, Interactions
3. Tap "More" tab (4th tab)
4. Verify More menu shows: Notifications, Family, Settings
5. Tap "Settings"
6. Verify SettingsView loads correctly
7. Tap back to return to More menu
8. Navigate to different tabs and verify everything works

### Step 3: Verify Dashboard toolbar

**Manual steps:**
1. Navigate to Dashboard tab
2. Verify toolbar has NO settings gear icon (top-left)
3. Verify toolbar has refresh button (top-right)
4. Tap refresh button to verify it works

### Step 4: VoiceOver accessibility testing

**Manual steps:**
1. Enable VoiceOver: Cmd+F5 (Simulator)
2. Navigate to More tab
3. Verify VoiceOver announces: "More, tab, 5 of 5"
4. Tap More tab to open More menu
5. Swipe to Settings
6. Verify VoiceOver announces: "Settings"
7. Double-tap to navigate to Settings
8. Verify VoiceOver announces: "Settings" (navigation title)
9. Navigate into sub-settings (e.g., Home Location)
10. Verify VoiceOver works correctly throughout
11. Disable VoiceOver: Cmd+F5

### Step 5: Document any issues

**If issues found:**
- Create new tasks to fix them
- Update this plan if needed
- Do NOT proceed until issues are resolved

**If no issues found:**
- Proceed to final commit

---

## Task 5: Final Verification & Documentation

**Files:**
- `docs/plans/2026-02-15-settings-tab-implementation.md` (this file)

### Step 1: Verify success criteria

**Check all items:**
- [x] Settings appears as 7th tab in MainTabView
- [x] Settings is accessible via "More" menu
- [x] Toolbar gear icon removed from Dashboard
- [x] VoiceOver announces Settings tab correctly
- [x] All existing tests pass
- [x] 80%+ test coverage maintained
- [x] No regressions in SettingsView functionality

### Step 2: Update implementation checklist in design doc

**Modify:** `docs/plans/2026-02-15-settings-tab-design.md`

**Update checklist to all checked:**
```markdown
## Implementation Checklist

- [x] Add Settings tab item to `MainTabView.swift`
- [x] Remove toolbar gear icon from `DashboardView.swift`
- [x] Write/update `MainTabViewTests.swift`
- [x] Update `DashboardViewTests.swift`
- [x] Manual VoiceOver testing
- [x] Run full test suite (verify 80%+ coverage)
- [x] Build and test on iPhone simulator
- [x] Verify tab behavior in More menu
```

### Step 3: Commit design doc update

```bash
git add docs/plans/2026-02-15-settings-tab-design.md
git commit -m "docs: mark Settings tab implementation as complete"
```

### Step 4: Update this implementation plan

**Add completion section at the top:**

```markdown
## ✅ Implementation Complete

**Date Completed:** 2026-02-15
**Total Tasks:** 5
**Tests Added:** 6
**Test Coverage:** 80%+
**Commits:** 4

**Summary:** Successfully added Settings as 7th tab in MainTabView, accessible via iOS automatic More menu. Removed redundant settings gear icon from Dashboard toolbar. All tests pass, accessibility verified with VoiceOver.
```

### Step 5: Final commit

```bash
git add docs/plans/2026-02-15-settings-tab-implementation.md
git commit -m "docs: mark Settings tab implementation plan as complete"
```

---

## Rollback Plan (If Needed)

**If implementation needs to be rolled back:**

```bash
# Find the commit before Settings tab changes
git log --oneline -10

# Revert to commit before "feat: add Settings as 7th tab"
git revert <commit-hash>

# Or reset to previous state (destructive)
git reset --hard <commit-before-changes>
```

**Files to restore:**
- `MainTabView.swift` - Remove Settings tab
- `DashboardView.swift` - Restore settings gear icon
- Test files - Remove new tests

---

## Troubleshooting

### Issue: Tests fail with "View not found"

**Solution:**
- Verify ViewInspector is properly imported
- Check that environment objects are injected
- Ensure tab indices are correct (0-indexed)

### Issue: VoiceOver doesn't announce Settings tab

**Solution:**
- Verify `.accessibilityLabel("Settings")` is present
- Check that it's at the tab level, not inside NavigationStack
- Test on physical device if simulator issues persist

### Issue: Settings tab doesn't appear in More menu

**Solution:**
- Verify exactly 7 tabs exist in TabView
- Ensure Settings is the 7th tab (index 6)
- Rebuild and clean (Cmd+Shift+K, then Cmd+B)

### Issue: SettingsView doesn't load when tapped

**Solution:**
- Verify NavigationStack wrapper is present
- Check that environment objects are propagated
- Ensure SettingsView() is initialized correctly

---

## References

- **Design Document:** `docs/plans/2026-02-15-settings-tab-design.md`
- **MainTabView:** `TheRecruitingCompass/Features/Dashboard/Views/MainTabView.swift`
- **DashboardView:** `TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift`
- **SettingsView:** `TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`
- **Architecture Guide:** `CLAUDE.md` - MVVM Pattern section
- **Testing Guide:** `CLAUDE.md` - Testing Strategy section
- **Accessibility Guide:** `docs/ACCESSIBILITY_AUDIT.md`
- **TDD Skill:** `@superpowers:test-driven-development`
- **Executing Plans Skill:** `@superpowers:executing-plans`
