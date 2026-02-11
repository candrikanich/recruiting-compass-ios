# Implementation Plan: Complete Add Coach Feature

**Created:** February 10, 2026
**Status:** PHASE 7 TESTING COMPLETION + NAVIGATION FIX
**Spec Compliance:** 93% → 100%
**Priority:** HIGH

---

## Executive Summary

The Add Coach feature is 93% complete. All production code (Phases 1-6) is implemented and building successfully. Phase 7 testing is 50% complete (135+ unit tests done). This plan completes:

1. Fix pre-existing TestUserSetup.swift error blocking test execution
2. Complete remaining Phase 7 tests (80-100 additional tests)
3. Fix navigation to coach detail after successful creation
4. Achieve 80%+ test coverage and full spec compliance

**Estimated Time:** 6-8 hours

---

## Phase 1: Fix Test Build Error (1 hour)

### Issue

**File:** `TheRecruitingCompassUITests/Helpers/TestUserSetup.swift:72`

**Error:**
```
error: type 'Any' cannot conform to 'Encodable'
```

**Additional Warnings:**
- Line 122: Cast from 'Void' to '[String : Any]' always fails
- Line 166: Cast from 'Void' to '[String : Any]' always fails
- Line 196: Cast from 'Void' to '[String : Any]' always fails
- Line 230: Cast from 'Void' to '[[String : Any]]' always fails

### Tasks

1. **Read TestUserSetup.swift** to understand the error context
2. **Fix type conformance issue** at line 72
3. **Fix cast warnings** at lines 122, 166, 196, 230
4. **Verify build** with `xcodebuild build-for-testing`
5. **Run existing tests** to ensure no regressions

### Success Criteria

- ✅ Test build succeeds (0 errors)
- ✅ All 135+ existing unit tests pass
- ✅ No new warnings introduced

---

## Phase 2: CoachCreateRequest+Preparation Tests (1 hour)

### Test File

`TheRecruitingCompassTests/Features/Coaches/Models/CoachCreateRequest+PreparationTests.swift`

### Test Coverage (15-20 tests)

**Initialization Tests (3 tests):**
- Test `from()` factory with all fields
- Test `from()` factory with required fields only
- Test `from()` factory with mixed required/optional fields

**Field Transformation Tests (8 tests):**
- Test email is lowercased and trimmed
- Test empty email converts to nil
- Test phone empty converts to nil
- Test Twitter handle strips leading @
- Test Instagram handle strips leading @
- Test notes HTML tags stripped
- Test first/last name trimmed
- Test empty strings become nil

**Edge Case Tests (4 tests):**
- Test @ stripping when no @ present
- Test @ stripping when multiple @ present (only strips first)
- Test HTML stripping with nested tags
- Test HTML stripping with self-closing tags

**Integration Tests (2 tests):**
- Test full form state to request conversion
- Test minimal form state to request conversion

### Example Test

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoachCreateRequestPreparationTests: XCTestCase {

  func testFrom_withAllFields_createsRequestCorrectly() {
    // Given
    var formState = CoachFormState()
    formState.role = .head
    formState.firstName = " John "
    formState.lastName = " Smith "
    formState.email = " JOHN.SMITH@EXAMPLE.COM "
    formState.phone = "(555) 123-4567"
    formState.twitterHandle = "@coachsmith"
    formState.instagramHandle = "@coach.smith"
    formState.notes = "<p>Great coach</p>"

    // When
    let request = CoachCreateRequest.from(
      formState,
      schoolId: "school-123",
      userId: "user-456",
      familyUnitId: "family-789"
    )

    // Then
    XCTAssertEqual(request.firstName, "John")
    XCTAssertEqual(request.lastName, "Smith")
    XCTAssertEqual(request.email, "john.smith@example.com")
    XCTAssertEqual(request.twitterHandle, "coachsmith")
    XCTAssertEqual(request.instagramHandle, "coach.smith")
    XCTAssertEqual(request.notes, "Great coach")
  }
}
```

### Success Criteria

- ✅ 15-20 tests created
- ✅ All field transformations tested
- ✅ Edge cases covered
- ✅ All tests passing

---

## Phase 3: AddCoachViewModel Tests (2 hours)

### Test File

`TheRecruitingCompassTests/Features/Coaches/ViewModels/AddCoachViewModelTests.swift`

### Test Coverage (30-40 tests)

**Initialization Tests (3 tests):**
- Test ViewModel initializes with empty form state
- Test ViewModel initializes with empty errors
- Test ViewModel initializes with injected dependencies

**loadSchools() Tests (5 tests):**
- Test loadSchools success populates schools array
- Test loadSchools error sets submitError
- Test loadSchools prevents duplicate calls (loading state)
- Test loadSchools with empty result
- Test loadSchools logs correctly

**validateField() Tests (7 tests):**
- Test validateField for firstName (valid, invalid)
- Test validateField for lastName (valid, invalid)
- Test validateField for email (valid, invalid)
- Test validateField for phone (valid, invalid)
- Test validateField for twitterHandle (valid, invalid)
- Test validateField for instagramHandle (valid, invalid)
- Test validateField for notes (valid, invalid)

**validateRole() Tests (2 tests):**
- Test validateRole with nil returns error
- Test validateRole with value clears error

**submitCoach() Tests (8 tests):**
- Test submitCoach success returns new coach
- Test submitCoach success calls service with correct data
- Test submitCoach validation error returns nil
- Test submitCoach network error returns nil and sets submitError
- Test submitCoach with missing school returns nil
- Test submitCoach sets isSubmitting during operation
- Test submitCoach triggers success haptic on success
- Test submitCoach triggers error haptic on error

**Computed Properties Tests (3 tests):**
- Test isFormVisible when school selected/not selected
- Test isSubmitDisabled when form valid/invalid/submitting
- Test submitButtonTitle when submitting/not submitting

**Helper Methods Tests (2 tests):**
- Test clearErrors resets all errors
- Test resetForm resets form state

**Accessibility Tests (2 tests):**
- Test announceErrorsForAccessibility posts notification
- Test error announcement format

### Example Test

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddCoachViewModelTests: XCTestCase {

  var viewModel: AddCoachViewModel!
  var mockService: MockCoachesService!

  override func setUp() async throws {
    mockService = MockCoachesService()
    viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "family-123",
      userId: "user-456"
    )
  }

  func testLoadSchools_success_populatesSchoolsArray() async {
    // Given
    let mockSchools = [
      School(id: "1", name: "School A", ...),
      School(id: "2", name: "School B", ...)
    ]
    mockService.mockSchools = mockSchools

    // When
    await viewModel.loadSchools()

    // Then
    XCTAssertEqual(viewModel.schools.count, 2)
    XCTAssertEqual(viewModel.schools[0].name, "School A")
    XCTAssertFalse(viewModel.isLoadingSchools)
  }

  func testSubmitCoach_validationError_returnsNilAndSetsErrors() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "" // Invalid: required
    viewModel.formState.lastName = "Smith"

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNil(result)
    XCTAssertNotNil(viewModel.formErrors.firstName)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
  }
}
```

### Success Criteria

- ✅ 30-40 tests created
- ✅ All ViewModel methods tested
- ✅ Async operations tested correctly
- ✅ MockCoachesService used properly
- ✅ All tests passing

---

## Phase 4: Integration Tests (1 hour)

### Test File

`TheRecruitingCompassTests/Integration/AddCoachIntegrationTests.swift`

### Test Coverage (10-15 tests)

**Full Submission Flow Tests (3 tests):**
- Test complete add coach flow (load schools → select school → fill form → submit → success)
- Test add coach flow with only required fields
- Test add coach flow with all optional fields

**Validation Error Handling Tests (3 tests):**
- Test submission with validation errors shows errors and prevents submission
- Test fixing validation errors clears errors
- Test validation errors announced for accessibility

**Network Error Handling Tests (2 tests):**
- Test network timeout during school load
- Test network error during coach creation

**Success Navigation Tests (2 tests):**
- Test successful creation returns coach with ID
- Test form state preserved on network error

**Cancel Flow Tests (2 tests):**
- Test cancel before school selection
- Test cancel after filling form

### Example Test

```swift
@MainActor
final class AddCoachIntegrationTests: XCTestCase {

  func testFullAddCoachFlow_success() async {
    // Given
    let mockService = MockCoachesService()
    mockService.mockSchools = [School(id: "1", name: "Test School", ...)]
    mockService.shouldSucceed = true

    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "family-123",
      userId: "user-456"
    )

    // When: Load schools
    await viewModel.loadSchools()
    XCTAssertEqual(viewModel.schools.count, 1)

    // When: Fill form
    viewModel.formState.selectedSchoolId = "1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    // When: Submit
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.firstName, "John")
    XCTAssertEqual(result?.lastName, "Smith")
    XCTAssertNil(viewModel.submitError)
  }
}
```

### Success Criteria

- ✅ 10-15 integration tests created
- ✅ End-to-end flows tested
- ✅ Error recovery tested
- ✅ All tests passing

---

## Phase 5: Accessibility Tests (1 hour)

### Test File

`TheRecruitingCompassTests/Accessibility/AddCoachAccessibilityTests.swift`

### Test Coverage (20-30 tests)

**VoiceOver Label Tests (10 tests):**
- Test school picker has "required" in label
- Test role picker has "required" in label
- Test first name field has "required" in label
- Test last name field has "required" in label
- Test email field has "optional" in label
- Test phone field has "optional" in label
- Test Twitter handle field has "optional" in label
- Test Instagram handle field has "optional" in label
- Test notes field has "optional" in label
- Test submit button label reflects loading state

**VoiceOver Hint Tests (8 tests):**
- Test school picker hint
- Test role picker hint
- Test submit button hint when disabled
- Test submit button hint when enabled
- Test cancel button hint
- Test empty state "Add School" button hint
- Test error summary has accessible value
- Test field errors have "Error:" prefix

**Dynamic Type Support Tests (5 tests):**
- Test form scales with large text
- Test buttons remain tappable at large sizes
- Test labels don't truncate at extra large sizes
- Test section headers scale correctly
- Test error messages scale correctly

**Touch Target Tests (4 tests):**
- Test submit button meets 44x44pt minimum
- Test cancel button meets 44x44pt minimum
- Test school picker meets minimum
- Test role picker meets minimum

**Error Announcement Tests (3 tests):**
- Test validation errors announced
- Test error count announced
- Test error list announced

### Example Test

```swift
final class AddCoachAccessibilityTests: XCTestCase {

  func testSchoolPicker_hasRequiredLabel() {
    // Given
    let picker = SchoolPicker(
      selectedSchoolId: .constant(nil),
      schools: [],
      isDisabled: false
    )

    // When
    let accessibilityLabel = picker.accessibilityLabel

    // Then
    XCTAssertTrue(accessibilityLabel?.contains("required") == true)
    XCTAssertTrue(accessibilityLabel?.contains("School") == true)
  }

  func testSubmitButton_meetsMinimumTouchTarget() {
    // Given
    let view = AddCoachView(
      coachesService: MockCoachesService(),
      familyUnitId: "family-123",
      userId: "user-456"
    )

    // When
    let button = view.submitButton

    // Then
    XCTAssertGreaterThanOrEqual(button.frame.height, 44)
    // Note: This is a conceptual test - actual implementation
    // would use ViewInspector or similar testing library
  }
}
```

### Success Criteria

- ✅ 20-30 accessibility tests created
- ✅ All VoiceOver labels tested
- ✅ Dynamic Type support verified
- ✅ Touch targets verified
- ✅ All tests passing

---

## Phase 6: E2E UI Tests (1 hour, Optional)

### Test File

`TheRecruitingCompassUITests/E2E/AddCoachE2ETests.swift`

### Test Coverage (5-10 tests)

**Happy Path Tests (2 tests):**
- Test add coach with all fields
- Test add coach with only required fields

**Validation Tests (2 tests):**
- Test validation errors prevent submission
- Test fixing errors enables submission

**Empty State Tests (1 test):**
- Test empty state when no schools exist

**Error Handling Tests (1 test):**
- Test network error shows error message

**Cancel Flow Tests (1 test):**
- Test cancel returns to coaches list

### Example Test

```swift
final class AddCoachE2ETests: XCTestCase {

  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
    // Navigate to coaches list, tap "Add Coach"
  }

  func testAddCoach_happyPath_createsCoach() {
    // When: Select school
    app.buttons["Select School"].tap()
    app.buttons["Test University"].tap()

    // When: Fill form
    app.buttons["Select Role"].tap()
    app.buttons["Head Coach"].tap()

    app.textFields["First Name"].tap()
    app.textFields["First Name"].typeText("John")

    app.textFields["Last Name"].tap()
    app.textFields["Last Name"].typeText("Smith")

    // When: Submit
    app.buttons["Add Coach"].tap()

    // Then: Navigate to coach detail
    XCTAssertTrue(app.navigationBars["John Smith"].exists)
  }
}
```

### Success Criteria

- ✅ 5-10 E2E tests created
- ✅ Critical user flows tested
- ✅ All tests passing

---

## Phase 7: Fix Navigation (30 minutes)

### Issue

**File:** `AddCoachView.swift:178`

**Current Code:**
```swift
if await viewModel.submitCoach() != nil {
  // TODO: Navigate to coach detail
  // For now, just dismiss
  dismiss()
}
```

**Spec Requirement:**
> "On success, user navigates to the newly created coach's detail page"

### Solution

**Update:** `AddCoachView.swift`

```swift
@Binding var navigationPath: NavigationPath  // Add parameter

private var submitButton: some View {
  Button {
    Task {
      if let newCoach = await viewModel.submitCoach() {
        // Navigate to coach detail
        navigationPath.append(CoachDestination.detail(id: newCoach.id))
      }
    }
  } label: {
    // ... existing label code
  }
}
```

**Update:** `CoachesListView.swift`

Pass `navigationPath` to `AddCoachView`:

```swift
case .add:
  AddCoachView(
    coachesService: viewModel.coachesService,
    familyUnitId: familyManager.familyUnitId ?? "",
    userId: authManager.user?.id ?? "",
    navigationPath: $navigationPath  // NEW
  )
```

### Success Criteria

- ✅ Navigation to coach detail after successful creation
- ✅ Coach detail page shows newly created coach
- ✅ Build succeeds

---

## Phase 8: Verification & Documentation (30 minutes)

### Tasks

1. **Run all tests** and verify 80%+ coverage
2. **Run build** and verify 0 errors, 0 warnings
3. **Update MEMORY.md** with Add Coach feature complete status
4. **Create handoff document** summarizing all work
5. **Commit all changes** with proper commit message

### Commit Message

```
feat(coaches): complete Add Coach feature - Phase 7 testing + navigation

- Fix TestUserSetup.swift type conformance error
- Add 80-100 tests for Phase 7 (ViewModel, Integration, Accessibility, E2E)
- Wire navigation to coach detail after successful creation
- Achieve 80%+ test coverage
- All 215+ tests passing
- 100% spec compliance

Closes #[issue-number]
```

### Success Criteria

- ✅ All tests passing (215+ total)
- ✅ 80%+ code coverage
- ✅ Build clean (0 errors, 0 warnings)
- ✅ Documentation updated
- ✅ Feature committed and ready for PR

---

## File Structure After Completion

```
TheRecruitingCompass/
├── Features/Coaches/
│   ├── Models/
│   │   ├── CoachCreateRequest.swift (existing)
│   │   ├── CoachCreateRequest+Preparation.swift (existing)
│   │   └── ... (other models)
│   ├── ViewModels/
│   │   └── AddCoachViewModel.swift (existing)
│   └── Views/
│       └── AddCoachView.swift (UPDATE - navigation)

TheRecruitingCompassTests/
├── Features/Coaches/
│   ├── Models/
│   │   ├── CoachFormStateTests.swift (existing - 10 tests)
│   │   ├── CoachFormErrorsTests.swift (existing - 11 tests)
│   │   └── CoachCreateRequest+PreparationTests.swift (NEW - 15-20 tests)
│   └── ViewModels/
│       └── AddCoachViewModelTests.swift (NEW - 30-40 tests)
├── Shared/Utilities/Validators/
│   ├── FieldValidatorTests.swift (existing - 90+ tests)
│   └── DataSanitizerTests.swift (existing - 24 tests)
├── Integration/
│   └── AddCoachIntegrationTests.swift (NEW - 10-15 tests)
└── Accessibility/
    └── AddCoachAccessibilityTests.swift (NEW - 20-30 tests)

TheRecruitingCompassUITests/
├── Helpers/
│   └── TestUserSetup.swift (FIX)
└── E2E/
    └── AddCoachE2ETests.swift (NEW - 5-10 tests)
```

---

## Summary

**Total Time:** 6-8 hours

**Test Count:**
- Existing: 135 tests
- New: 80-100 tests
- **Total: 215-235 tests**

**Coverage:** 50% → 80%+

**Spec Compliance:** 93% → 100%

**Phases:**
1. Fix TestUserSetup.swift (1 hour)
2. CoachCreateRequest+Preparation tests (1 hour)
3. AddCoachViewModel tests (2 hours)
4. Integration tests (1 hour)
5. Accessibility tests (1 hour)
6. E2E tests (1 hour, optional)
7. Fix navigation (30 minutes)
8. Verification & documentation (30 minutes)

---

## Risk Assessment

### Low Risks

1. **Test complexity** - Following established test patterns from existing tests
2. **TestUserSetup.swift fix** - Likely straightforward type conformance issue
3. **Navigation fix** - Simple parameter addition

### Mitigation

- Follow existing test patterns from Phases 1-6
- Use MockCoachesService (already exists)
- Test incrementally (run after each phase)
- Leverage AI assistance for test generation

---

## Dependencies

**Internal:**
- ✅ MockCoachesService (existing)
- ✅ Test utilities (existing)
- ✅ XCTest framework (existing)

**External:**
- ✅ None

---

## Success Metrics

1. ✅ All 215+ tests passing
2. ✅ 80%+ code coverage on Add Coach feature
3. ✅ Build clean (0 errors, 0 warnings)
4. ✅ Navigation to coach detail working
5. ✅ 100% spec compliance
6. ✅ All accessibility requirements met
7. ✅ Feature ready for code review and PR

---

## Next Steps

1. **Approve this plan**
2. **Begin Phase 1** (Fix TestUserSetup.swift)
3. **Execute phases sequentially** (Phases 2-8)
4. **Daily check-ins** to review progress
5. **Code review** before merging to main

---

## Sign-Off

**Plan Created By:** Claude Code
**Plan Created:** February 10, 2026
**Ready for Execution:** Yes
**Estimated Completion:** 6-8 hours
**Blocking Issues:** None
