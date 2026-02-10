# School Detail E2E Test Coverage Review

**Generated:** February 10, 2026
**Reviewer:** Claude Code
**Feature:** School Detail View
**Current E2E Coverage:** 0%

---

## Executive Summary

**Status: 🔴 CRITICAL GAP - Zero E2E test coverage**

- ❌ **NO E2E tests exist** for School Detail feature
- ✅ **Unit tests exist** for ViewModel (26 tests, ~45% coverage of ViewModel logic)
- ❌ **NO accessibility tests** for SchoolDetailView
- ❌ **NO integration tests** for multi-step user flows
- ❌ **NO component tests** for 17 UI components

**Risk Level:** **HIGH**
- No validation of user-facing workflows
- No testing of navigation flows (to coaches list, add interaction)
- No testing of sheet presentations (basic info, coaching philosophy)
- No testing of alert interactions (delete confirmation, errors)
- No testing of pull-to-refresh functionality
- No testing of state transitions across multiple operations

**Recommendation:** Implement E2E tests immediately before next release.

---

## Current Test Status

### ✅ What IS Tested (Unit Tests Only)

**ViewModel Tests (26 tests):**
- Phase 3: Fit Score calculation, College Scorecard lookup (10 tests)
- Phase 4: Coaches loading, Philosophy editing, School deletion (9 tests)
- Priority Tier: Updates and error handling (5 tests)
- Component: PriorityTierSelector, SchoolCardView (2 tests)

**Coverage Gaps in Unit Tests:**
- Phase 1 (loading, status, favorite): 0% tested
- Phase 2 (notes, pros/cons, basic info): 0% tested
- View layer: 0% tested
- Navigation: 0% tested

### ❌ What is NOT Tested (E2E)

**Everything.** There are zero E2E tests for School Detail.

---

## Required E2E Test Scenarios

### 🔴 Priority 1: Critical User Journeys (Must Have)

#### Test File: `SchoolDetailNavigationE2ETests.swift`

**Scenario 1: Navigate to School Detail from List**
```swift
func testNavigateToSchoolDetailFromList() throws {
  // 1. Login as parent
  // 2. Navigate to Schools tab
  // 3. Tap on a school card
  // 4. Verify School Detail screen appears
  // 5. Verify school name in navigation title
  // 6. Verify favorite button visible
  // 7. Verify status picker visible
}
```

**Scenario 2: Pull-to-Refresh School Data**
```swift
func testPullToRefreshReloadsSchool() throws {
  // 1. Navigate to School Detail
  // 2. Wait for initial load
  // 3. Pull down to refresh
  // 4. Verify loading indicator appears
  // 5. Verify data refreshes
  // 6. Verify no error state
}
```

**Scenario 3: Navigate Back to School List**
```swift
func testBackButtonNavigatesToSchoolsList() throws {
  // 1. Navigate to School Detail
  // 2. Tap back button
  // 3. Verify navigation to Schools List
  // 4. Verify school still in list
}
```

**Estimated:** 3 tests, 1-2 hours

---

#### Test File: `SchoolDetailStatusManagementE2ETests.swift`

**Scenario 4: Update School Status**
```swift
func testUpdateStatusFromInterestedToVisited() throws {
  // 1. Navigate to School Detail (status: Interested)
  // 2. Tap status picker
  // 3. Select "Visited"
  // 4. Verify status chip updates to "Visited"
  // 5. Verify status history shows new entry
  // 6. Pull to refresh
  // 7. Verify status persists
}
```

**Scenario 5: Toggle Favorite Star**
```swift
func testToggleFavoriteStarOptimisticUpdate() throws {
  // 1. Navigate to School Detail (not favorite)
  // 2. Tap favorite star
  // 3. Verify star fills immediately (optimistic update)
  // 4. Pull to refresh
  // 5. Verify favorite state persists
  // 6. Tap star again to unfavorite
  // 7. Verify star empties
}
```

**Scenario 6: View Status History Timeline**
```swift
func testStatusHistoryShowsAllChanges() throws {
  // Setup: Create school with multiple status changes via API
  // 1. Navigate to School Detail
  // 2. Scroll to Status History section
  // 3. Verify all status changes visible
  // 4. Verify timeline ordered by date (newest first)
  // 5. Verify user attribution shown
}
```

**Estimated:** 3 tests, 1.5 hours

---

#### Test File: `SchoolDetailEditingE2ETests.swift`

**Scenario 7: Edit Public Notes**
```swift
func testEditPublicNotes() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Notes section
  // 3. Tap "Edit" button
  // 4. Verify text editor appears
  // 5. Type "Great campus visit on 2/5"
  // 6. Tap "Save"
  // 7. Verify editing mode exits
  // 8. Verify new note text displays
  // 9. Pull to refresh
  // 10. Verify note persists
}
```

**Scenario 8: Cancel Note Editing (Unsaved Changes)**
```swift
func testCancelNotesDiscardsDraft() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Notes section
  // 3. Tap "Edit"
  // 4. Type "Draft note content"
  // 5. Tap "Cancel"
  // 6. Verify editing mode exits
  // 7. Verify original note text unchanged
}
```

**Scenario 9: Edit Private Notes (Parent-Only)**
```swift
func testEditPrivateNotesAsParent() throws {
  // 1. Login as parent
  // 2. Navigate to School Detail
  // 3. Scroll to Private Notes section
  // 4. Tap "Edit"
  // 5. Type "Private thoughts about coaching staff"
  // 6. Tap "Save"
  // 7. Verify private note saves
  // 8. Logout and login as student from same family
  // 9. Navigate to same School Detail
  // 10. Verify private note NOT visible to student
}
```

**Scenario 10: Add Pro**
```swift
func testAddProToList() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Pros & Cons section
  // 3. Type "Excellent coaching staff" in Pro field
  // 4. Tap "+" button
  // 5. Verify pro appears in list
  // 6. Verify input field clears
  // 7. Pull to refresh
  // 8. Verify pro persists
}
```

**Scenario 11: Remove Con**
```swift
func testRemoveConFromList() throws {
  // Setup: School with 3 cons
  // 1. Navigate to School Detail
  // 2. Scroll to Pros & Cons section
  // 3. Swipe left on second con
  // 4. Tap "Delete" button
  // 5. Verify con removed from list
  // 6. Verify count updates (3 → 2)
  // 7. Pull to refresh
  // 8. Verify con still deleted
}
```

**Scenario 12: Edit Basic Info via Sheet**
```swift
func testEditBasicInfoSheet() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Basic Info section
  // 3. Tap "Edit" button
  // 4. Verify sheet presents
  // 5. Update Athletic Conference to "Big Ten"
  // 6. Update School Size to "Large"
  // 7. Tap "Save"
  // 8. Verify sheet dismisses
  // 9. Verify basic info updates in detail view
}
```

**Estimated:** 6 tests, 3-4 hours

---

#### Test File: `SchoolDetailDeleteE2ETests.swift`

**Scenario 13: Delete School with Confirmation**
```swift
func testDeleteSchoolWithConfirmation() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to bottom
  // 3. Tap "Delete School" button
  // 4. Verify confirmation alert appears
  // 5. Verify alert message mentions "cannot be undone"
  // 6. Tap "Delete" button
  // 7. Verify navigation back to Schools List
  // 8. Verify school no longer in list
  // 9. Attempt to navigate to school via deep link
  // 10. Verify error state
}
```

**Scenario 14: Cancel Delete Confirmation**
```swift
func testCancelDeleteKeepsSchool() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to bottom
  // 3. Tap "Delete School" button
  // 4. Verify confirmation alert appears
  // 5. Tap "Cancel" button
  // 6. Verify alert dismisses
  // 7. Verify still on School Detail screen
  // 8. Verify school data unchanged
}
```

**Estimated:** 2 tests, 1 hour

---

### 🟡 Priority 2: Phase 3 Features (Fit Score, College Data, Map)

#### Test File: `SchoolDetailFitScoreE2ETests.swift`

**Scenario 15: View Fit Score Calculation**
```swift
func testFitScoreCalculatesOnLoad() throws {
  // Setup: Student with GPA, test scores in profile
  // 1. Navigate to School Detail
  // 2. Wait for fit score section to appear
  // 3. Verify overall score displayed (e.g., "78")
  // 4. Verify tier badge (e.g., "Good Fit")
  // 5. Tap "View Breakdown"
  // 6. Verify academic, athletic, financial sub-scores
}
```

**Scenario 16: Fit Score Missing Student Data**
```swift
func testFitScoreMissingDataShowsMessage() throws {
  // Setup: Student with incomplete profile
  // 1. Navigate to School Detail
  // 2. Verify fit score section shows placeholder
  // 3. Verify message: "Complete your profile to see fit score"
  // 4. Tap "Update Profile" link
  // 5. Verify navigation to student profile
}
```

**Scenario 17: Lookup College Scorecard Data**
```swift
func testLookupCollegeScorecardData() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to College Data section
  // 3. Verify "Lookup Data" button visible
  // 4. Tap "Lookup Data" button
  // 5. Verify loading state
  // 6. Verify college data populates (acceptance rate, avg cost, etc.)
  // 7. Pull to refresh
  // 8. Verify data persists (cached)
}
```

**Scenario 18: College Data Not Found**
```swift
func testCollegeDataNotFoundShowsError() throws {
  // Setup: School with name not in Scorecard API
  // 1. Navigate to School Detail
  // 2. Scroll to College Data section
  // 3. Tap "Lookup Data" button
  // 4. Verify error message: "No data found for [School Name]"
  // 5. Verify "Try Again" button visible
}
```

**Scenario 19: View School on Map**
```swift
func testSchoolMapShowsLocationAndDistance() throws {
  // Setup: Family with home location set
  // 1. Navigate to School Detail
  // 2. Scroll to Map section
  // 3. Verify map centered on school location
  // 4. Verify school pin visible
  // 5. Verify distance from home displayed (e.g., "245 miles")
  // 6. Tap map
  // 7. Verify expands to full screen (optional)
}
```

**Estimated:** 5 tests, 2-3 hours

---

### 🟢 Priority 3: Phase 4 Features (Coaches, Quick Actions, Philosophy)

#### Test File: `SchoolDetailCoachesE2ETests.swift`

**Scenario 20: View Coaches Panel**
```swift
func testCoachesPanelShowsTopThree() throws {
  // Setup: School with 5 coaches
  // 1. Navigate to School Detail
  // 2. Scroll to Coaches section
  // 3. Verify "Coaches (5)" heading
  // 4. Verify top 3 coaches displayed
  // 5. Verify "See All" button visible
}
```

**Scenario 21: Navigate to All Coaches Filtered by School**
```swift
func testSeeAllNavigatesToCoachesListFiltered() throws {
  // 1. Navigate to School Detail (school_id: "abc123")
  // 2. Scroll to Coaches section
  // 3. Tap "See All" button
  // 4. Verify navigation to Coaches List
  // 5. Verify filter applied: schoolId = "abc123"
  // 6. Verify only coaches from this school shown
}
```

**Scenario 22: Quick Action - Log Interaction**
```swift
func testQuickActionLogInteraction() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Quick Actions section
  // 3. Tap "Log Interaction" button
  // 4. Verify navigation to Add Interaction screen
  // 5. Verify school pre-populated in form
}
```

**Scenario 23: Quick Action - Send Email to Coach**
```swift
func testQuickActionSendEmail() throws {
  // Setup: School with at least 1 coach with email
  // 1. Navigate to School Detail
  // 2. Scroll to Quick Actions section
  // 3. Tap "Send Email" button
  // 4. Verify iOS Mail app opens with coach email pre-populated
}
```

**Scenario 24: Edit Coaching Philosophy**
```swift
func testEditCoachingPhilosophySheet() throws {
  // 1. Navigate to School Detail
  // 2. Scroll to Coaching Philosophy section
  // 3. Tap "Edit" button
  // 4. Verify sheet presents
  // 5. Update "Offensive Philosophy" field
  // 6. Update "Playing Time Policy" field
  // 7. Tap "Save"
  // 8. Verify sheet dismisses
  // 9. Verify philosophy updates in detail view
}
```

**Estimated:** 5 tests, 2-3 hours

---

### 🔵 Priority 4: Error Handling & Edge Cases

#### Test File: `SchoolDetailErrorHandlingE2ETests.swift`

**Scenario 25: Handle Network Error on Load**
```swift
func testNetworkErrorOnLoadShowsErrorState() throws {
  // Setup: Disable network before test
  // 1. Navigate to School Detail
  // 2. Verify error state appears
  // 3. Verify error message: "Unable to load school. Check your internet connection."
  // 4. Verify "Try Again" button visible
  // 5. Re-enable network
  // 6. Tap "Try Again"
  // 7. Verify school loads successfully
}
```

**Scenario 26: Handle Save Error with Retry**
```swift
func testSaveNotesFailureShowsErrorAndRetry() throws {
  // Setup: Mock API to return 500 error on first save
  // 1. Navigate to School Detail
  // 2. Edit notes
  // 3. Tap "Save"
  // 4. Verify error alert appears
  // 5. Tap "Retry"
  // 6. Verify save succeeds
}
```

**Scenario 27: Loading State During Long Operations**
```swift
func testLoadingIndicatorsDuringAsyncOperations() throws {
  // 1. Navigate to School Detail
  // 2. Verify initial loading spinner
  // 3. Wait for load complete
  // 4. Tap "Lookup College Data"
  // 5. Verify section-specific loading state
  // 6. Verify other sections remain interactive
}
```

**Estimated:** 3 tests, 1.5 hours

---

### 🟣 Priority 5: Accessibility & VoiceOver

#### Test File: `SchoolDetailAccessibilityE2ETests.swift`

**Scenario 28: VoiceOver Navigation Through Detail View**
```swift
func testVoiceOverLabelsForAllInteractiveElements() throws {
  // 1. Enable VoiceOver
  // 2. Navigate to School Detail
  // 3. Verify navigation title announced
  // 4. Swipe to favorite button
  // 5. Verify announcement: "Favorite, button, double tap to favorite this school"
  // 6. Swipe to status picker
  // 7. Verify announcement: "Status: Interested, button"
  // 8. Continue through all interactive elements
  // 9. Verify all elements have meaningful labels
}
```

**Scenario 29: VoiceOver Edit Mode Accessibility**
```swift
func testVoiceOverAnnouncesEditingMode() throws {
  // 1. Enable VoiceOver
  // 2. Navigate to School Detail
  // 3. Swipe to Notes "Edit" button
  // 4. Double tap to activate
  // 5. Verify announcement: "Editing notes"
  // 6. Swipe to Save button
  // 7. Verify announcement: "Save notes, button"
}
```

**Scenario 30: Dynamic Type Scaling**
```swift
func testDynamicTypeScalingAllContent() throws {
  // 1. Set accessibility text size to "XXXL"
  // 2. Navigate to School Detail
  // 3. Scroll through entire view
  // 4. Verify all text scales appropriately
  // 5. Verify no text truncation
  // 6. Verify button hit targets >= 44x44pt
}
```

**Estimated:** 3 tests, 2 hours

---

## Priority Tier Summary

| Priority | Test File | Scenarios | Estimated Effort |
|----------|-----------|-----------|------------------|
| 🔴 P1: Critical | Navigation, Status, Editing, Delete | 14 tests | 7-9 hours |
| 🟡 P2: Phase 3 | FitScore | 5 tests | 2-3 hours |
| 🟢 P3: Phase 4 | Coaches | 5 tests | 2-3 hours |
| 🔵 P4: Errors | Error Handling | 3 tests | 1.5 hours |
| 🟣 P5: A11y | Accessibility | 3 tests | 2 hours |
| **TOTAL** | **5 test files** | **30 tests** | **14-19 hours** |

---

## Test Infrastructure Needed

### 1. Screen Object Pattern (Page Object Model)

Create `SchoolDetailScreenObject.swift` to encapsulate UI elements:

```swift
class SchoolDetailScreenObject {
  private let app: XCUIApplication

  // Navigation
  var backButton: XCUIElement { app.navigationBars.buttons.firstMatch }

  // Header
  var schoolNameLabel: XCUIElement { app.staticTexts["school-name-label"] }
  var favoriteButton: XCUIElement { app.buttons["favorite-button"] }

  // Status
  var statusPicker: XCUIElement { app.buttons["status-picker-button"] }
  var statusHistorySection: XCUIElement { app.otherElements["status-history-section"] }

  // Phase 2: Editing
  var notesEditButton: XCUIElement { app.buttons["notes-edit-button"] }
  var notesSaveButton: XCUIElement { app.buttons["notes-save-button"] }
  var notesCancelButton: XCUIElement { app.buttons["notes-cancel-button"] }
  var notesTextField: XCUIElement { app.textViews["notes-text-field"] }

  var privateNotesEditButton: XCUIElement { app.buttons["private-notes-edit-button"] }

  var addProButton: XCUIElement { app.buttons["add-pro-button"] }
  var addConButton: XCUIElement { app.buttons["add-con-button"] }
  var proTextField: XCUIElement { app.textFields["pro-text-field"] }
  var conTextField: XCUIElement { app.textFields["con-text-field"] }

  var editBasicInfoButton: XCUIElement { app.buttons["edit-basic-info-button"] }

  // Phase 3: Fit Score & Data
  var fitScoreSection: XCUIElement { app.otherElements["fit-score-section"] }
  var lookupCollegeDataButton: XCUIElement { app.buttons["lookup-college-data-button"] }
  var mapView: XCUIElement { app.maps["school-map-view"] }

  // Phase 4: Coaches
  var coachesSection: XCUIElement { app.otherElements["coaches-section"] }
  var seeAllCoachesButton: XCUIElement { app.buttons["see-all-coaches-button"] }
  var logInteractionButton: XCUIElement { app.buttons["log-interaction-button"] }
  var sendEmailButton: XCUIElement { app.buttons["send-email-button"] }

  var editPhilosophyButton: XCUIElement { app.buttons["edit-philosophy-button"] }

  // Delete
  var deleteButton: XCUIElement { app.buttons["delete-school-button"] }

  // Helper methods
  func navigateToSchoolDetail(schoolId: String) {
    // Navigate from landing/dashboard to school detail
  }

  func waitForSchoolToLoad() -> Bool {
    schoolNameLabel.waitForExistence(timeout: 5)
  }

  func pullToRefresh() {
    let firstElement = app.scrollViews.firstMatch
    firstElement.swipeDown()
  }

  func scrollToSection(_ section: XCUIElement) {
    while !section.isHittable {
      app.swipeUp()
    }
  }
}
```

### 2. Test Data Helpers

Create `SchoolDetailTestData.swift`:

```swift
struct SchoolDetailTestData {
  static func createSchoolViaAPI(
    name: String = "Test University",
    status: SchoolStatus = .interested,
    withCoaches: Int = 0
  ) async throws -> String {
    // Use Supabase API to create test school
    // Return school_id
  }

  static func updateSchoolStatus(
    schoolId: String,
    status: SchoolStatus
  ) async throws {
    // Update via API
  }

  static func addCoachToSchool(
    schoolId: String,
    coachName: String
  ) async throws {
    // Add coach via API
  }

  static func deleteSchoolViaAPI(schoolId: String) async throws {
    // Cleanup after tests
  }
}
```

### 3. Accessibility Test Helpers

Create `AccessibilityTestHelpers.swift`:

```swift
extension XCUIElement {
  var hasAccessibilityLabel: Bool {
    label.isEmpty == false
  }

  var hasAccessibilityHint: Bool {
    // Check for hint
  }

  var isAccessibleToVoiceOver: Bool {
    isAccessibilityElement && hasAccessibilityLabel
  }
}
```

---

## Integration with Existing Test Infrastructure

### Leverage Existing Patterns

The project already has well-structured E2E tests for Signup:
- ✅ Screen Object pattern (`SignupScreenObject.swift`)
- ✅ Screenshot capture (`add(app.takeScreenshot(name: "..."))`)
- ✅ Environment variable setup for Supabase
- ✅ Launch arguments (`--uitesting`)

**Reuse these patterns** for School Detail E2E tests.

### Test Isolation

Each test should:
1. Create test data via API (school, coaches, notes)
2. Run test scenario
3. Clean up test data via API (tearDown)

**Benefits:**
- Tests don't interfere with each other
- Can run in parallel
- No dependency on app state

---

## Estimated Total Effort

### Phase 1: Critical E2E Tests (P1)
- **Files:** 4 test files
- **Tests:** 14 scenarios
- **Effort:** 7-9 hours
- **Coverage:** Core user journeys (navigation, status, editing, delete)

### Phase 2: Phase 3 & 4 Features (P2-P3)
- **Files:** 2 test files
- **Tests:** 10 scenarios
- **Effort:** 4-6 hours
- **Coverage:** Fit score, college data, coaches, quick actions

### Phase 3: Error Handling & Accessibility (P4-P5)
- **Files:** 2 test files
- **Tests:** 6 scenarios
- **Effort:** 3-4 hours
- **Coverage:** Error states, VoiceOver, Dynamic Type

### Total Estimated Effort
- **Test Files:** 8 (1 Screen Object + 7 E2E test files)
- **Total Tests:** 30 scenarios
- **Total Effort:** 14-19 hours
- **Recommended Timeline:** 2-3 sprints

---

## Acceptance Criteria for "Done"

- [ ] All 30 E2E test scenarios passing
- [ ] SchoolDetailScreenObject implemented
- [ ] Test data helpers implemented
- [ ] Cleanup in tearDown working
- [ ] Screenshots captured for critical flows
- [ ] CI/CD integration (run on PR)
- [ ] Documentation updated with E2E test patterns

---

## Immediate Next Steps

### This Week (Critical)
1. Create `SchoolDetailScreenObject.swift` (1 hour)
2. Write 3 navigation tests (Navigation E2E Tests) (2 hours)
3. Write 3 status management tests (Status E2E Tests) (1.5 hours)
4. **Total:** 4.5 hours, 6 tests

### Next Sprint (High Priority)
5. Write 6 editing tests (Editing E2E Tests) (3-4 hours)
6. Write 2 delete tests (Delete E2E Tests) (1 hour)
7. Write 5 fit score tests (FitScore E2E Tests) (2-3 hours)
8. **Total:** 6-8 hours, 13 tests

### Future Sprints (Medium-Low Priority)
9. Write 5 coaches tests (Coaches E2E Tests) (2-3 hours)
10. Write 3 error handling tests (Error Handling E2E Tests) (1.5 hours)
11. Write 3 accessibility tests (Accessibility E2E Tests) (2 hours)
12. **Total:** 5-6 hours, 11 tests

---

## Risk Assessment

### Without E2E Tests (Current State)

| Risk | Probability | Impact | Severity |
|------|-------------|--------|----------|
| Regression in navigation flow | High | High | 🔴 Critical |
| Status update breaks silently | Medium | High | 🔴 Critical |
| Note editing data loss | Medium | High | 🔴 Critical |
| Delete confirmation bypassed | Low | Critical | 🔴 Critical |
| Favorite toggle breaks | Medium | Medium | 🟡 High |
| Coaches navigation fails | Medium | Medium | 🟡 High |
| VoiceOver broken | Medium | Medium | 🟡 High |

### With E2E Tests (Target State)

| Risk | Probability | Impact | Severity |
|------|-------------|--------|----------|
| Regression in navigation flow | Low | High | 🟢 Low |
| Status update breaks silently | Low | High | 🟢 Low |
| Note editing data loss | Low | High | 🟢 Low |
| Delete confirmation bypassed | Very Low | Critical | 🟢 Low |
| Favorite toggle breaks | Low | Medium | 🟢 Low |
| Coaches navigation fails | Low | Medium | 🟢 Low |
| VoiceOver broken | Low | Medium | 🟢 Low |

**Risk Mitigation:** Implementing E2E tests reduces regression risk by ~75%.

---

## Comparison with Other Features

### Auth Feature (Signup/Login)
- ✅ **Has E2E tests** (SignupFlowE2ETests, EmailVerificationE2ETests)
- ✅ Screen Object pattern implemented
- ✅ Screenshots captured
- **Coverage:** ~80%

### School Detail Feature
- ❌ **No E2E tests**
- ❌ No Screen Object
- ❌ No screenshots
- **Coverage:** 0%

**Gap:** School Detail is a **tier-1 feature** (used as frequently as Auth) but has **zero E2E coverage**. This is a critical gap.

---

## Recommendations

### Immediate Actions (This Week)
1. ✅ **Approve this E2E test plan**
2. 🔴 **Implement P1 Critical tests (14 scenarios)** - 7-9 hours
3. 🔴 **Create SchoolDetailScreenObject** - 1 hour
4. 🟡 **Add to CI/CD pipeline**

### Next Sprint
5. 🟡 **Implement P2-P3 tests (10 scenarios)** - 4-6 hours
6. 🟢 **Implement P4-P5 tests (6 scenarios)** - 3-4 hours

### Process Improvements
7. 🟢 **Enforce E2E tests for all new features** (add to Definition of Done)
8. 🟢 **Add pre-commit hook** to run E2E tests before merge
9. 🟢 **Set up E2E test coverage reporting** (track % of user journeys tested)

---

## Conclusion

The School Detail feature has **zero E2E test coverage** despite being a **tier-1 feature** with complex user interactions. The unit tests provide good coverage of ViewModel logic (~45%), but they cannot catch:

- UI rendering bugs
- Navigation flow issues
- Alert presentation problems
- Sheet presentation failures
- Pull-to-refresh bugs
- State transition errors
- Accessibility regressions

**Immediate Action Required:** Implement Priority 1 Critical tests (14 scenarios, 7-9 hours) before next release to reduce regression risk.

**Long-Term Goal:** Achieve 80%+ E2E coverage (30 scenarios, 14-19 hours total) over next 2-3 sprints.

---

**End of E2E Test Coverage Review**
