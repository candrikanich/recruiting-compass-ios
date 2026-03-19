//
//  AddCoachAccessibilityTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Accessibility tests for Add Coach feature
//

import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AddCoachAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - ViewModel Accessibility Tests

  func testSubmitButton_titleReflectsState() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Not submitting
    XCTAssertEqual(viewModel.submitButtonTitle, "Add Coach", "Button title should be 'Add Coach' when not submitting")

    // Note: isSubmitting is internal to async operation
    // Actual loading state is tested in integration tests
  }

  func testSubmitButton_disabledWhenNoSchoolSelected() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: No school selected
    viewModel.formState.selectedSchoolId = nil

    // Then: Submit button should be disabled
    XCTAssertTrue(viewModel.isSubmitDisabled, "Submit button should be disabled when school not selected")
  }

  func testSubmitButton_disabledWhenRequiredFieldsMissing() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: School selected but required fields empty
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = nil
    viewModel.formState.firstName = ""
    viewModel.formState.lastName = ""

    // Then: Submit button should be disabled
    XCTAssertTrue(viewModel.isSubmitDisabled, "Submit button should be disabled when required fields are empty")
  }

  func testSubmitButton_enabledWhenAllRequiredFieldsFilled() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: All required fields filled
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    // Then: Submit button should be enabled
    XCTAssertFalse(viewModel.isSubmitDisabled, "Submit button should be enabled when all required fields are filled")
  }

  // MARK: - Form Validation Tests

  func testValidationErrors_reported() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Form with errors
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""  // Invalid
    viewModel.formState.lastName = ""  // Invalid

    // When: Submit
    _ = await viewModel.submitCoach()

    // Then: Errors should be reported
    XCTAssertTrue(viewModel.formErrors.hasErrors, "Form errors should be present")
    XCTAssertEqual(viewModel.formErrors.allErrors.count, 2, "Should have 2 validation errors")
    XCTAssertNotNil(viewModel.formErrors.firstName, "Should have first name error")
    XCTAssertNotNil(viewModel.formErrors.lastName, "Should have last name error")
  }

  func testValidationErrors_cleared() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Set errors manually (simulate validation failure)
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""
    viewModel.formState.lastName = ""
    _ = await viewModel.submitCoach()

    // Verify errors exist
    XCTAssertTrue(viewModel.formErrors.hasErrors)

    // When: Clear errors
    viewModel.clearErrors()

    // Then: Errors should be cleared
    XCTAssertFalse(viewModel.formErrors.hasErrors, "Errors should be cleared")
    XCTAssertEqual(viewModel.formErrors.allErrors.count, 0, "Should have no errors")
  }

  func testErrorMessages_descriptive() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Submit with empty required fields
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""
    viewModel.formState.lastName = ""

    _ = await viewModel.submitCoach()

    // Then: Error messages should be descriptive
    XCTAssertEqual(viewModel.formErrors.firstName, "First name is required")
    XCTAssertEqual(viewModel.formErrors.lastName, "Last name is required")
  }

  func testEmailValidation_invalidFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Invalid email
    viewModel.formState.email = "invalid-email"
    viewModel.validateField(\.email, value: "invalid-email")

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.email, "Please enter a valid email address")
  }

  func testEmailValidation_validFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Valid email
    viewModel.formState.email = "john@example.com"
    viewModel.validateField(\.email, value: "john@example.com")

    // Then: No error
    XCTAssertNil(viewModel.formErrors.email)
  }

  func testPhoneValidation_invalidFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Invalid phone
    viewModel.formState.phone = "123"
    viewModel.validateField(\.phone, value: "123")

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.phone, "Please enter a valid phone number")
  }

  func testPhoneValidation_validFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Valid phone
    viewModel.formState.phone = "(555) 123-4567"
    viewModel.validateField(\.phone, value: "(555) 123-4567")

    // Then: No error
    XCTAssertNil(viewModel.formErrors.phone)
  }

  func testTwitterHandleValidation_invalidFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Invalid twitter handle (contains invalid characters)
    viewModel.formState.twitterHandle = "handle-with-dash"
    viewModel.validateField(\.twitterHandle, value: "handle-with-dash")

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.twitterHandle, "Invalid Twitter handle (1-15 characters, letters/numbers/underscore)")
  }

  func testTwitterHandleValidation_validFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Valid twitter handle
    viewModel.formState.twitterHandle = "@handle"
    viewModel.validateField(\.twitterHandle, value: "@handle")

    // Then: No error
    XCTAssertNil(viewModel.formErrors.twitterHandle)
  }

  func testInstagramHandleValidation_invalidFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Invalid instagram handle (contains invalid characters)
    viewModel.formState.instagramHandle = "handle-with-dash"
    viewModel.validateField(\.instagramHandle, value: "handle-with-dash")

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.instagramHandle, "Invalid Instagram handle (1-30 characters, letters/numbers/dots/underscore)")
  }

  func testInstagramHandleValidation_validFormat() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Valid instagram handle
    viewModel.formState.instagramHandle = "@handle"
    viewModel.validateField(\.instagramHandle, value: "@handle")

    // Then: No error
    XCTAssertNil(viewModel.formErrors.instagramHandle)
  }

  func testNotesValidation_withinLimit() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Notes within limit
    let notes = String(repeating: "a", count: CoachFormState.notesCharacterLimit)
    viewModel.formState.notes = notes
    viewModel.validateField(\.notes, value: notes)

    // Then: No error
    XCTAssertNil(viewModel.formErrors.notes)
  }

  func testNotesValidation_exceedsLimit() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Notes exceed limit
    let notes = String(repeating: "a", count: CoachFormState.notesCharacterLimit + 1)
    viewModel.formState.notes = notes
    viewModel.validateField(\.notes, value: notes)

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.notes, "Notes must not exceed 5000 characters")
  }

  func testRoleValidation_required() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: No role selected
    viewModel.formState.role = nil
    viewModel.validateRole(nil)

    // Then: Error should be set
    XCTAssertEqual(viewModel.formErrors.role, "Please select a role")
  }

  func testRoleValidation_valid() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Role selected
    viewModel.formState.role = .head
    viewModel.validateRole(.head)

    // Then: No error
    XCTAssertNil(viewModel.formErrors.role)
  }

  // MARK: - Integration: Full Flow

  func testFullAccessibilityFlow_success() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // Load schools
    mockService.mockSchools = [School.mock(id: "1", name: "Test University")]
    await viewModel.loadSchools()

    // When: Fill valid form
    viewModel.formState.selectedSchoolId = "1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formState.email = "john@test.edu"
    viewModel.formState.phone = "(555) 123-4567"

    // Submit
    mockService.mockCreatedCoach = Coach.mock(
      id: "new",
      firstName: "John",
      lastName: "Smith"
    )
    let result = await viewModel.submitCoach()

    // Then: Success
    XCTAssertNotNil(result, "Should create coach successfully")
    XCTAssertFalse(viewModel.isSubmitting, "Should not be submitting after completion")
    XCTAssertFalse(viewModel.formErrors.hasErrors, "Should have no errors")
    XCTAssertNil(viewModel.submitError, "Should have no submit error")
  }

  func testFullAccessibilityFlow_validationFailure() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // When: Fill invalid form
    viewModel.formState.selectedSchoolId = "1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""  // Invalid
    viewModel.formState.lastName = ""   // Invalid
    viewModel.formState.email = "invalid-email"  // Invalid

    // Submit
    let result = await viewModel.submitCoach()

    // Then: Validation failure
    XCTAssertNil(result, "Should not create coach with validation errors")
    XCTAssertTrue(viewModel.formErrors.hasErrors, "Should have validation errors")
    XCTAssertGreaterThan(viewModel.formErrors.allErrors.count, 0, "Should have multiple errors")
  }

  func testFullAccessibilityFlow_serviceFailure() async {
    // Given
    let mockService = MockCoachesService()
    let mockAnnouncer = MockAccessibilityAnnouncer()
    let viewModel = AddCoachViewModel(
      coachesService: mockService,
      familyUnitId: "test-family",
      userId: "test-user",
      announcer: mockAnnouncer
    )

    // Load schools
    mockService.mockSchools = [School.mock(id: "1", name: "Test University")]
    await viewModel.loadSchools()

    // When: Fill valid form but service fails
    viewModel.formState.selectedSchoolId = "1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    mockService.shouldThrowError = true
    let result = await viewModel.submitCoach()

    // Then: Service failure
    XCTAssertNil(result, "Should not create coach when service fails")
    XCTAssertNotNil(viewModel.submitError, "Should have submit error")
    XCTAssertFalse(viewModel.isSubmitting, "Should not be submitting after error")
  }
}
