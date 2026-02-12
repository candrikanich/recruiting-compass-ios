# E2E Test Plan - Phase 4 Preferences

**Created:** 2026-02-12
**Test Engineer:** e2e-test-engineer
**Status:** Planning - Waiting for implementation

---

## Overview

Comprehensive end-to-end test plan for Phase 4 Preferences feature covering all 5 preference pages:
1. Player Details
2. School Preferences
3. Notification Preferences
4. Dashboard Customization
5. Home Location

---

## Test Infrastructure

### Screen Objects to Create

```
TheRecruitingCompassUITests/Helpers/
├── PreferencesNavigationScreenObject.swift  # Navigation & settings list
├── PlayerDetailsScreenObject.swift          # Player details form
├── SchoolPreferencesScreenObject.swift      # School preferences
├── NotificationSettingsScreenObject.swift   # Notification toggles
├── DashboardCustomizationScreenObject.swift # Dashboard widgets
└── HomeLocationScreenObject.swift           # Location entry & geocoding
```

### Test Files to Create

```
TheRecruitingCompassUITests/Features/Preferences/
├── PlayerDetailsE2ETests.swift
├── SchoolPreferencesE2ETests.swift
├── NotificationSettingsE2ETests.swift
├── DashboardCustomizationE2ETests.swift
├── HomeLocationE2ETests.swift
├── PreferencesPersistenceE2ETests.swift     # Cross-cutting
├── PreferencesAccessibilityE2ETests.swift   # Accessibility
└── PreferencesErrorHandlingE2ETests.swift   # Network errors
```

---

## Test Scenarios by Page

### 1. Player Details Preferences

**Model:** `PlayerDetails` (62+ fields)

**Test Cases:**

```swift
// Basic Navigation
testPlayerDetails_navigation_success()
  - Navigate from Settings → Player Details
  - Verify form loads with default/existing values
  - Verify all sections visible

// Field Editing
testPlayerDetails_editBasicInfo_savesPersists()
  - Edit graduation year, high school, club team
  - Save changes
  - Navigate away and back
  - Verify changes persisted

testPlayerDetails_editAthleticProfile_savesPersists()
  - Edit primary sport, positions, bats/throws
  - Save changes
  - Verify persistence

testPlayerDetails_editPhysicalStats_savesPersists()
  - Edit height, weight
  - Save changes
  - Verify persistence

testPlayerDetails_editAcademics_savesPersists()
  - Edit GPA, SAT, ACT scores
  - Validate ranges (GPA: 0-5.0, SAT: 400-1600, ACT: 1-36)
  - Save and verify

testPlayerDetails_editSocialMedia_savesPersists()
  - Edit Twitter, Instagram, TikTok, Facebook
  - Save and verify

testPlayerDetails_editContactInfo_savesPersists()
  - Edit phone, email
  - Toggle share permissions
  - Save and verify

// Role-Based Access
testPlayerDetails_parentView_readOnly()
  - Login as parent
  - Navigate to Player Details
  - Verify all fields are read-only (disabled)
  - Verify "Contact player to update" message shown

testPlayerDetails_playerView_editable()
  - Login as player
  - Navigate to Player Details
  - Verify all fields are editable
  - Edit and save successfully

// Validation
testPlayerDetails_invalidGPA_showsError()
  - Enter GPA > 5.0 or < 0.0
  - Verify inline error shown
  - Save button disabled

testPlayerDetails_invalidSAT_showsError()
  - Enter SAT > 1600 or < 400
  - Verify error shown

testPlayerDetails_invalidACT_showsError()
  - Enter ACT > 36 or < 1
  - Verify error shown

// Unsaved Changes
testPlayerDetails_unsavedChanges_showsWarning()
  - Edit multiple fields
  - Tap back button
  - Verify "Unsaved changes" alert shown
  - Cancel and verify still on page
  - Discard and verify navigation away
```

---

### 2. School Preferences

**Model:** `SchoolPreferences` (templates, criteria)

**Test Cases:**

```swift
// Template Application
testSchoolPreferences_applyTemplate_populatesFields()
  - Navigate to School Preferences
  - Select "D1 Power 5" template
  - Verify division set to D1
  - Verify conference filters applied
  - Save and verify

testSchoolPreferences_applyTemplate_overwritesWarning()
  - Fill some custom preferences
  - Select template
  - Verify "This will overwrite current settings" alert
  - Confirm and verify template applied

// Criteria Editing
testSchoolPreferences_editDivisionFilter_savesPersists()
  - Toggle D1, D2, D3 checkboxes
  - Save and verify persistence

testSchoolPreferences_editConferenceFilter_savesPersists()
  - Select specific conferences
  - Save and verify

testSchoolPreferences_editLocationRadius_savesPersists()
  - Set radius slider (0-500 miles)
  - Save and verify

// Priority Ordering (Drag-to-Reorder)
testSchoolPreferences_reorderPriorities_savesPersists()
  - Drag "Academic Rank" above "Athletic Prestige"
  - Save changes
  - Navigate away and back
  - Verify order persisted

testSchoolPreferences_reorderPriorities_voiceOverAccessible()
  - Enable VoiceOver
  - Use accessibility actions to reorder
  - Verify order updates

// Reset to Default
testSchoolPreferences_resetToDefault_restoresDefaults()
  - Customize all preferences
  - Tap "Reset to Default"
  - Verify confirmation alert
  - Confirm and verify defaults restored
```

---

### 3. Notification Preferences

**Model:** `NotificationSettings` (9 fields)

**Test Cases:**

```swift
// Toggle Settings
testNotificationSettings_toggleFollowUpReminders_savesPersists()
  - Toggle "Enable Follow-up Reminders" ON/OFF
  - Adjust reminder days (1-30)
  - Save and verify persistence

testNotificationSettings_toggleDeadlineAlerts_savesPersists()
  - Toggle "Deadline Alerts" ON/OFF
  - Save and verify

testNotificationSettings_toggleDailyDigest_savesPersists()
  - Toggle "Daily Digest" ON/OFF
  - Save and verify

testNotificationSettings_toggleEmailNotifications_savesPersists()
  - Toggle "Email Notifications" ON/OFF
  - Verify "High Priority Only" checkbox appears when ON
  - Toggle high priority checkbox
  - Save and verify

// Quiet Hours
testNotificationSettings_setQuietHours_savesPersists()
  - Set quiet hours start (10:00 PM)
  - Set quiet hours end (7:00 AM)
  - Save and verify
  - Verify displayed as "10:00 PM - 7:00 AM"

testNotificationSettings_clearQuietHours_savesPersists()
  - Set quiet hours
  - Tap "Clear Quiet Hours"
  - Verify fields cleared
  - Save and verify

// Reset to Default
testNotificationSettings_resetToDefault_restoresDefaults()
  - Customize all settings
  - Tap "Reset to Default"
  - Verify confirmation alert
  - Confirm and verify defaults restored
    - Follow-up reminders: ON, 7 days
    - Deadline alerts: ON
    - Daily digest: ON
    - Inbound alerts: ON
    - Email: ON
    - High priority only: OFF
    - Quiet hours: not set
```

---

### 4. Dashboard Customization

**Model:** `DashboardWidgetVisibility`

**Test Cases:**

```swift
// Widget Visibility
testDashboardCustomization_toggleWidgetVisibility_savesPersists()
  - Toggle "Upcoming Deadlines" widget OFF
  - Toggle "Recent Interactions" widget ON
  - Save changes
  - Navigate to Dashboard
  - Verify widgets shown/hidden accordingly

testDashboardCustomization_reorderWidgets_savesPersists()
  - Drag "Schools List" to top
  - Drag "Coaches List" to bottom
  - Save changes
  - Navigate to Dashboard
  - Verify widget order matches

// Reset to Default
testDashboardCustomization_resetToDefault_restoresDefaults()
  - Hide all widgets
  - Reorder widgets
  - Tap "Reset to Default"
  - Verify confirmation alert
  - Confirm and verify defaults restored
    - All widgets visible
    - Default order restored
```

---

### 5. Home Location

**Model:** `HomeLocation`

**Test Cases:**

```swift
// Location Entry
testHomeLocation_enterAddress_geocodesSuccessfully()
  - Enter address: "123 Main St, Boston, MA 02108"
  - Tap "Geocode" or auto-geocode on blur
  - Wait for geocoding API response
  - Verify latitude/longitude populated
  - Verify formatted address shown
  - Save and verify persistence

testHomeLocation_enterZipCode_geocodesSuccessfully()
  - Enter zip code: "90210"
  - Geocode
  - Verify coordinates populated
  - Save and verify

testHomeLocation_enterInvalidAddress_showsError()
  - Enter invalid address: "xyz123"
  - Geocode
  - Verify error message: "Could not find location"
  - Save button remains enabled (allows manual entry)

// Manual Coordinates
testHomeLocation_enterManualCoordinates_savesPersists()
  - Toggle "Enter coordinates manually"
  - Enter latitude: 42.3601
  - Enter longitude: -71.0589
  - Save and verify

// Clear Location
testHomeLocation_clearLocation_savesPersists()
  - Enter and geocode location
  - Tap "Clear Location"
  - Verify all fields cleared
  - Save and verify cleared state persisted

// Geocoding Timeout
testHomeLocation_geocodingTimeout_showsError()
  - Enter address
  - Geocode (simulate network timeout)
  - Verify error message: "Geocoding timed out"
  - Verify retry button shown
  - Tap retry and verify attempt made
```

---

## Cross-Cutting Test Scenarios

### Persistence Across Sessions

```swift
testPreferences_editAllPages_persistsAcrossSessions()
  - Login as player
  - Edit Player Details (save)
  - Edit School Preferences (save)
  - Edit Notification Settings (save)
  - Edit Dashboard Customization (save)
  - Edit Home Location (save)
  - Logout
  - Re-login
  - Navigate to each page and verify all changes persisted
```

### Unsaved Changes Warning

```swift
testPreferences_unsavedChanges_warnsOnNavigateAway()
  - Navigate to Player Details
  - Edit graduation year
  - Tap back button (without saving)
  - Verify "Unsaved changes. Discard?" alert
  - Tap "Cancel" → verify still on page with changes
  - Tap back again → Tap "Discard" → verify navigation away

testPreferences_unsavedChanges_warnsOnSwitchTab()
  - Navigate to Notification Settings
  - Toggle follow-up reminders
  - Tap "Schools" tab (without saving)
  - Verify unsaved changes alert
  - Discard and verify tab switch
```

### Network Error Handling

```swift
testPreferences_saveWithNetworkError_showsRetry()
  - Navigate to Player Details
  - Edit fields
  - Tap Save
  - Simulate network timeout/error
  - Verify error alert: "Failed to save. Retry?"
  - Tap "Retry" → verify save attempted again
  - Tap "Cancel" → verify changes still in form (not lost)

testPreferences_loadWithNetworkError_showsRetry()
  - Navigate to School Preferences
  - Simulate network error on load
  - Verify error message: "Failed to load preferences"
  - Verify "Retry" button shown
  - Tap retry → verify load attempted again
```

---

## Accessibility Testing

### VoiceOver Support

```swift
testPreferences_voiceOver_allFieldsLabeled()
  - Enable VoiceOver
  - Navigate to each preference page
  - Verify all form fields have accessibility labels
  - Verify all toggles/switches have labels
  - Verify all buttons have labels

testPreferences_voiceOver_groupedLogically()
  - Enable VoiceOver
  - Navigate to Player Details
  - Verify sections grouped with headers
    - "Basic Info" header → graduation, high school, club team
    - "Athletic Profile" header → sport, positions, bats/throws
  - Verify swipe navigation flows logically

testPreferences_voiceOver_saveFeedback()
  - Enable VoiceOver
  - Edit field
  - Tap Save button
  - Verify VoiceOver announces "Saved successfully"
```

### Dynamic Type Support

```swift
testPreferences_dynamicType_largeText()
  - Set Dynamic Type to "Accessibility XXX-Large"
  - Navigate to all preference pages
  - Verify text scales properly
  - Verify no text truncation
  - Verify layout remains usable
```

---

## Performance Testing

```swift
testPreferences_largePlayerDetails_loadsQuickly()
  - Create player with all 62 fields populated
  - Navigate to Player Details
  - Measure load time (should be < 1 second)
  - Verify UI responsive

testPreferences_saveAll_completesFast()
  - Edit all 5 preference pages
  - Measure save time for each
  - Verify all saves complete < 2 seconds
```

---

## Test Data Setup

### User Roles

- **Player:** `testplayer@example.com` / `TestPass1`
- **Parent:** `testparent@example.com` / `TestPass1`

### Initial State

- Player has some preferences already saved
- Parent is linked to player via family code

### Cleanup

- After each test, reset preferences to defaults or known state
- Use `tearDown()` to delete test data

---

## Artifacts & Reporting

### Screenshots

Capture screenshots at key points:
- Before editing
- After filling fields
- After saving
- After navigating back to verify persistence
- Error states

### Test Report Format

```markdown
## Preferences E2E Test Report

**Date:** YYYY-MM-DD HH:MM
**Duration:** Xm Ys
**Status:** ✅ PASSING / ❌ FAILING

### Summary
- Total Tests: 45
- Passed: 43 (95.6%)
- Failed: 2
- Flaky: 0

### Test Results by Page
- Player Details: 12/12 ✅
- School Preferences: 8/8 ✅
- Notification Settings: 9/9 ✅
- Dashboard Customization: 6/6 ✅
- Home Location: 6/7 ❌ (geocoding timeout)
- Cross-Cutting: 2/3 ❌ (persistence)

### Failed Tests
1. testHomeLocation_geocodingTimeout_showsError
   - Error: Geocoding API did not timeout as expected
   - Fix: Adjust network simulation or timeout duration

2. testPreferences_editAllPages_persistsAcrossSessions
   - Error: Dashboard customization not persisting
   - Fix: Check DashboardWidgetVisibility save logic

### Next Steps
- Fix 2 failing tests
- Re-run full suite
- Report PASS to team lead
```

---

## Success Criteria

- ✅ All 45+ E2E tests passing
- ✅ All pages navigable and functional
- ✅ All fields save and persist correctly
- ✅ Role-based access working (player editable, parent read-only)
- ✅ Unsaved changes warning working
- ✅ Network error handling graceful
- ✅ Accessibility compliant (VoiceOver, Dynamic Type)
- ✅ Screenshots captured for all critical flows
- ✅ Test report generated and shared with team

---

## Dependencies

**Blocked By:**
- Task #1: Implement Player Details page
- Task #2: Implement School Preferences page
- Task #3: Implement Notification Preferences page
- Task #4: Implement Dashboard Customization page
- Task #5: Implement Home Location page
- Task #6: Create shared PreferenceService infrastructure
- Task #7: Unit tests passing

**Unblocks:**
- Phase 4 completion
- Release to staging/production

---

## Timeline Estimate

| Phase | Duration | Description |
|-------|----------|-------------|
| Screen Objects | 2h | Create 6 screen object helpers |
| Player Details Tests | 2h | 12 test cases |
| School Preferences Tests | 1.5h | 8 test cases |
| Notification Settings Tests | 1.5h | 9 test cases |
| Dashboard Customization Tests | 1h | 6 test cases |
| Home Location Tests | 1.5h | 7 test cases |
| Cross-Cutting Tests | 1.5h | 6 test cases |
| Accessibility Tests | 1h | 3 test cases |
| Debugging & Fixes | 2h | Fix flaky/failing tests |
| **Total** | **~14h** | Full E2E test suite |

---

## Notes

- Follow existing E2E patterns from `AddSchoolE2ETests.swift`
- Use `XCUITestHelpers.swift` for login, screenshots, waits
- Use Screen Object pattern for maintainability
- Capture screenshots with meaningful names
- Use `@MainActor` for all test methods
- Use `XCTSkip` for tests that depend on Supabase config
- Add comprehensive error messages to assertions
