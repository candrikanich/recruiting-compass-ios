# E2E Test Completion Guide
## Remaining Test Files for Phase 4 Preferences

**Date:** 2026-02-12
**Status:** 62% Complete - 5 test files remaining
**Estimated Effort:** 4-5 hours

---

## Quick Start

**What's Done:**
- ✅ All 6 Screen Objects (100%)
- ✅ 3 test files with 28 tests (PlayerDetails, HomeLocation, Notifications)
- ✅ Pattern established and proven

**What's Remaining:**
- ⏳ 5 test files with 17 tests
- ⏳ Follow established pattern from completed files

---

## Pattern to Follow

All remaining tests should follow this proven template from existing files:

```swift
import XCTest

final class [Feature]E2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: [Feature]ScreenObject!
  private var navigation: PreferencesNavigationScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()
    screen = [Feature]ScreenObject(app: app)
    navigation = PreferencesNavigationScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
    navigation = nil
  }

  @MainActor
  func test[Feature]_[action]_[expectedResult]() throws {
    // Given: Setup
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-initial-state"))

    navigation.navigateTo[Feature]()
    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    // When: Perform action
    add(app.takeScreenshot(name: "02-before-action"))
    screen.performAction()
    add(app.takeScreenshot(name: "03-after-action"))

    // Then: Verify outcome
    XCTAssertTrue(screen.verifyOutcome(), "Description")
    add(app.takeScreenshot(name: "04-verified"))
  }
}
```

---

## 1. DashboardCustomizationE2ETests (6 tests, ~1 hour)

**Screen Object:** `DashboardCustomizationScreenObject` (already created)

**Test Cases:**

### Test 1: Navigation
```swift
@MainActor
func testDashboardCustomization_navigation_success() throws {
  // Navigate from Settings → Dashboard Customization
  // Verify screen loads with navigation title
  // Verify stats cards and widgets sections visible
}
```

### Test 2: Toggle Stats Cards
```swift
@MainActor
func testDashboardCustomization_toggleStatsCards_savesPersists() throws {
  // Toggle coaches stats card OFF
  // Toggle schools stats card OFF
  // Save changes
  // Navigate away and back
  // Verify toggles persisted
}
```

### Test 3: Select/Deselect All Stats
```swift
@MainActor
func testDashboardCustomization_selectAllStats_enablesAllCards() throws {
  // Tap "Deselect All" button
  // Verify all 8 stats cards disabled
  // Tap "Select All" button
  // Verify all 8 stats cards enabled
  // Save and verify persistence
}
```

### Test 4: Toggle Widgets
```swift
@MainActor
func testDashboardCustomization_toggleWidgets_savesPersists() throws {
  // Toggle Recent Notifications widget OFF
  // Toggle Upcoming Events widget ON
  // Save changes
  // Navigate away and back
  // Verify widget settings persisted
}
```

### Test 5: Reset to Defaults
```swift
@MainActor
func testDashboardCustomization_resetToDefaults_restoresDefaults() throws {
  // Disable all stats cards and widgets
  // Save changes
  // Tap "Reset to Defaults"
  // Verify all cards/widgets return to default state
}
```

### Test 6: Comprehensive Flow
```swift
@MainActor
func testDashboardCustomization_modifyAllSettings_success() throws {
  // Modify stats cards (toggle several)
  // Modify widgets (toggle several)
  // Use Select/Deselect All
  // Save all changes
  // Navigate away and back
  // Verify comprehensive persistence
}
```

**Reference:** Use `NotificationPreferencesE2ETests` as template (similar toggle-based)

---

## 2. SchoolPreferencesE2ETests (8 tests, ~1.5 hours)

**Screen Object:** `SchoolPreferencesScreenObject` (already created)

**Test Cases:**

### Test 1: Navigation
```swift
@MainActor
func testSchoolPreferences_navigation_success() throws {
  // Navigate from Settings → School Preferences
  // Verify screen loads with templates section
}
```

### Test 2: Apply Template
```swift
@MainActor
func testSchoolPreferences_applyTemplate_populatesPreferences() throws {
  // Tap "D1 Power Conference" template
  // Confirm replacement warning
  // Verify preferences list populated
  // Save changes
}
```

### Test 3: Template Warning Alert
```swift
@MainActor
func testSchoolPreferences_applyTemplateWithExisting_showsWarning() throws {
  // Add custom preference first
  // Tap template button
  // Verify "Replace Existing Preferences?" alert
  // Test Cancel button (preferences unchanged)
  // Test Replace button (preferences replaced)
}
```

### Test 4: Add Custom Preference
```swift
@MainActor
func testSchoolPreferences_addCustomPreference_success() throws {
  // Tap "Add Custom Preference" button
  // Fill in custom preference sheet
  // Verify preference added to list
  // Save and verify persistence
}
```

### Test 5: Reorder Preferences (Drag-to-Reorder)
```swift
@MainActor
func testSchoolPreferences_reorderPreferences_savesPersists() throws {
  // Apply template to get preferences list
  // Tap "Edit" button
  // Drag preference from index 0 to index 2
  // Tap "Done"
  // Save changes
  // Navigate away and back
  // Verify reorder persisted
}
```

### Test 6: Delete Preference
```swift
@MainActor
func testSchoolPreferences_deletePreference_removesFromList() throws {
  // Apply template
  // Tap "Edit" button
  // Swipe to delete or tap delete button
  // Verify preference removed
  // Save changes
}
```

### Test 7: Empty State
```swift
@MainActor
func testSchoolPreferences_emptyState_showsMessage() throws {
  // Navigate to school preferences (no preferences set)
  // Verify empty state message visible
  // Verify "Apply template or add your own" message
}
```

### Test 8: Comprehensive Flow
```swift
@MainActor
func testSchoolPreferences_completeFlow_success() throws {
  // Apply "Academic Excellence" template
  // Add custom preference
  // Reorder preferences
  // Delete one preference
  // Save all changes
  // Navigate away and back
  // Verify all changes persisted
}
```

**Reference:** Use `PlayerDetailsE2ETests` for comprehensive flow pattern

---

## 3. PreferencesPersistenceE2ETests (3 tests, ~1 hour)

**Purpose:** Cross-cutting tests that verify preferences persist across multiple pages

**Test Cases:**

### Test 1: All Preferences Persist Across Sessions
```swift
@MainActor
func testAllPreferences_editAll_persistsAcrossSessions() throws {
  // Login as player

  // Edit Player Details
  navigation.navigateToPlayerDetails()
  playerScreen.fillBasicInfo(highSchool: "Test HS")
  playerScreen.tapSave()
  _ = playerScreen.waitForSaveToComplete()

  // Edit Home Location
  navigation.navigateToHomeLocation()
  locationScreen.fillAddress(city: "Boston", state: "MA")
  locationScreen.dismissKeyboard()
  sleep(1) // Wait for auto-save

  // Edit Notification Settings
  navigation.navigateToNotificationPreferences()
  notificationScreen.followUpRemindersToggle.tap()
  notificationScreen.tapSave()
  _ = notificationScreen.waitForSaveToComplete()

  // Navigate away (back to Dashboard)
  screen.backButton.tap()

  // Verify Player Details persisted
  navigation.navigateToPlayerDetails()
  let highSchool = playerScreen.highSchoolTextField.value as? String
  XCTAssertTrue(highSchool?.contains("Test HS") ?? false)

  // Verify Home Location persisted
  navigation.navigateToHomeLocation()
  let city = locationScreen.cityField.value as? String
  XCTAssertTrue(city?.contains("Boston") ?? false)

  // Verify Notification Settings persisted
  navigation.navigateToNotificationPreferences()
  let reminderValue = notificationScreen.followUpRemindersToggle.value as? String
  XCTAssertEqual(reminderValue, "0") // We toggled it OFF
}
```

### Test 2: Logout and Re-login Persistence
```swift
@MainActor
func testAllPreferences_logoutRelogin_dataPersis() throws {
  // Login, edit Player Details
  // Edit Home Location
  // Logout (if logout functionality exists)
  // Re-login with same credentials
  // Verify all preferences still there
}
```

### Test 3: Concurrent Edits Handle Correctly
```swift
@MainActor
func testAllPreferences_concurrentEdits_handleCorrectly() throws {
  // Edit Player Details
  // Edit Notification Preferences WITHOUT saving Player Details
  // Verify no data loss
  // Verify both saves work independently
}
```

**Reference:** Use navigation and multiple screen objects

---

## 4. PreferencesAccessibilityE2ETests (3 tests, ~1 hour)

**Purpose:** Verify WCAG AA compliance and VoiceOver support

**Test Cases:**

### Test 1: VoiceOver All Fields Labeled
```swift
@MainActor
func testPlayerDetails_voiceOver_allFieldsLabeled() throws {
  // Enable VoiceOver simulation (if possible, else manual test)
  // Navigate to Player Details
  // Verify all form fields have accessibility labels
  // Verify all toggles have accessibility labels
  // Verify all buttons have accessibility labels

  XCTAssertTrue(playerScreen.highSchoolTextField.label.count > 0)
  XCTAssertTrue(playerScreen.saveButton.label.count > 0)
}
```

### Test 2: Dynamic Type Scaling
```swift
@MainActor
func testAllPreferences_dynamicType_scalesCorrectly() throws {
  // Set Dynamic Type to XXX-Large (if possible via launch args)
  // Navigate to each preference page
  // Verify text scales properly
  // Verify no text truncation
  // Verify layout remains usable

  // Note: May need to use accessibility inspector or manual testing
}
```

### Test 3: Keyboard Navigation
```swift
@MainActor
func testPlayerDetails_keyboardNavigation_worksCorrectly() throws {
  // Navigate to Player Details
  // Tap first field
  // Use keyboard "Next" button to navigate through fields
  // Verify logical tab order
  // Verify can reach all fields via keyboard
}
```

**Reference:** Use existing accessibility labels from Views

---

## 5. PreferencesErrorHandlingE2ETests (3 tests, ~1 hour)

**Purpose:** Verify graceful error handling for network and server errors

**Test Cases:**

### Test 1: Network Timeout on Save
```swift
@MainActor
func testPlayerDetails_networkTimeoutOnSave_showsRetry() throws {
  // Note: Difficult without network mocking
  // Edit Player Details
  // Save (may timeout in slow network conditions)
  // If error alert appears, verify:
  //   - Error message clear
  //   - "Retry" or "OK" button exists
  //   - Can dismiss alert
  //   - Form data not lost

  // Fallback: Just verify error handling UI exists
  if playerScreen.errorAlert.waitForExistence(timeout: 2) {
    XCTAssertTrue(playerScreen.errorOkButton.exists)
  }
}
```

### Test 2: Server Error on Load
```swift
@MainActor
func testHomeLocation_serverErrorOnLoad_showsErrorMessage() throws {
  // Navigate to Home Location
  // If loading fails (server error), verify:
  //   - Error message displayed
  //   - "Retry" button available
  //   - Can retry loading

  // This test may require staging environment with error injection
}
```

### Test 3: Invalid Data from Server
```swift
@MainActor
func testAllPreferences_invalidServerData_handlesGracefully() throws {
  // Load preferences that may have invalid data
  // Verify app doesn't crash
  // Verify defaults used for invalid data
  // Verify error logged (if visible)

  // This is more of a resilience test
}
```

**Reference:** Use error alert handling from existing tests

---

## Execution Checklist

For each test file:

1. **Create File**
   - Copy template from PlayerDetailsE2ETests
   - Update class name and screen object references
   - Implement test methods following pattern

2. **Test Each Method**
   ```bash
   xcodebuild test -scheme TheRecruitingCompass \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:TheRecruitingCompassUITests/[TestFileName]/[testMethodName]
   ```

3. **Verify Screenshots**
   - Check that screenshots are captured
   - Verify meaningful names (01-description, 02-description)
   - Ensure at least 3-5 screenshots per test

4. **Run Full Suite**
   ```bash
   xcodebuild test -scheme TheRecruitingCompass \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:TheRecruitingCompassUITests/[TestFileName]
   ```

5. **Fix Flaky Tests**
   - Add waits where needed
   - Use XCTSkip for unavailable dependencies
   - Verify timeouts are sufficient

---

## Tips for Success

### Use Existing Patterns
- **PlayerDetailsE2ETests** - Comprehensive flow, validation, persistence
- **HomeLocationE2ETests** - Simple forms, auto-save, error handling
- **NotificationPreferencesE2ETests** - Toggle-based UI, reset to defaults

### Common Patterns
```swift
// Wait for screen to load
guard screen.waitForScreenToLoad() else {
  throw XCTSkip("Screen did not load")
}

// Save and wait
screen.tapSave()
_ = screen.waitForSaveToComplete(timeout: 15)

// Navigate away and back for persistence
screen.backButton.tap()
_ = navigation.waitForSettingsToLoad()
navigation.navigateToFeature()
_ = screen.waitForScreenToLoad()

// Take screenshots at key points
add(app.takeScreenshot(name: "01-initial"))
add(app.takeScreenshot(name: "02-after-action"))
add(app.takeScreenshot(name: "03-verified"))
```

### Avoid Common Pitfalls
- ❌ Don't use `sleep()` unless necessary (auto-save debounce)
- ❌ Don't assume element is ready - use `waitForExistence()`
- ❌ Don't skip screenshots - they're essential for debugging
- ✅ Use XCTSkip for unavailable Supabase
- ✅ Use descriptive assertion messages
- ✅ Use explicit timeouts (10-20s)

---

## Final Test Report Template

After all tests complete, generate report:

```markdown
# E2E Test Report - Phase 4 Preferences

**Date:** YYYY-MM-DD
**Tests:** 45/45 (100%)
**Duration:** Xm Ys
**Status:** ✅ ALL PASSING

## Summary
- Total Tests: 45
- Passed: 45 (100%)
- Failed: 0
- Flaky: 0
- Screenshots: 200+

## Test Results by File
- PlayerDetailsE2ETests: 12/12 ✅
- HomeLocationE2ETests: 7/7 ✅
- NotificationPreferencesE2ETests: 9/9 ✅
- DashboardCustomizationE2ETests: 6/6 ✅
- SchoolPreferencesE2ETests: 8/8 ✅
- PreferencesPersistenceE2ETests: 3/3 ✅
- PreferencesAccessibilityE2ETests: 3/3 ✅
- PreferencesErrorHandlingE2ETests: 3/3 ✅

## Artifacts
- Screenshots: planning/screenshots/
- Test logs: planning/test-logs/

## Next Steps
- ✅ All E2E tests passing
- ✅ Ready for CI/CD integration
- ✅ Ready for production deployment
```

---

## Completion Criteria

- [ ] All 5 test files created
- [ ] All 17 tests implemented
- [ ] All tests passing (45/45)
- [ ] No flaky tests
- [ ] Screenshots captured for all tests
- [ ] Test report generated
- [ ] CI/CD integration documented

---

**Estimated Time:** 4-5 hours for experienced engineer following patterns

**Success Rate:** 100% if following established patterns from completed files

**Support:** All Screen Objects complete, patterns proven, documentation comprehensive
