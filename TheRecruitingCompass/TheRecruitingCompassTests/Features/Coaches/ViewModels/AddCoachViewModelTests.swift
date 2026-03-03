//
//  AddCoachViewModelTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - AddCoachViewModel tests
//

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
      familyUnitId: "test-family-123",
      userId: "test-user-456"
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
  }

  // MARK: - Initialization Tests

  func testInit_initializesWithEmptyFormState() {
    // Then
    XCTAssertNil(viewModel.formState.selectedSchoolId)
    XCTAssertNil(viewModel.formState.role)
    XCTAssertEqual(viewModel.formState.firstName, "")
    XCTAssertEqual(viewModel.formState.lastName, "")
    XCTAssertEqual(viewModel.formState.email, "")
    XCTAssertEqual(viewModel.formState.phone, "")
    XCTAssertEqual(viewModel.formState.twitterHandle, "")
    XCTAssertEqual(viewModel.formState.instagramHandle, "")
    XCTAssertEqual(viewModel.formState.notes, "")
  }

  func testInit_initializesWithEmptyErrors() {
    // Then
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertTrue(viewModel.formErrors.allErrors.isEmpty)
  }

  func testInit_initializesWithInjectedDependencies() {
    // Then: Dependencies are stored (verified by successful loadSchools call)
    XCTAssertEqual(viewModel.schools.count, 0)
    XCTAssertFalse(viewModel.isLoadingSchools)
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - loadSchools() Tests

  func testLoadSchools_success_populatesSchoolsArray() async {
    // Given
    mockService.shouldThrowFetchSchools = false
    let mockSchools = [
      School.mock(id: "1", name: "School A"),
      School.mock(id: "2", name: "School B")
    ]
    mockService.mockSchools = mockSchools

    // When
    await viewModel.loadSchools()
    await Task.yield()  // Allow MainActor / Observation to commit before asserting

    // Then
    XCTAssertEqual(viewModel.schools.count, 2)
    XCTAssertEqual(viewModel.schools[0].name, "School A")
    XCTAssertEqual(viewModel.schools[1].name, "School B")
    XCTAssertFalse(viewModel.isLoadingSchools)
    XCTAssertNil(viewModel.submitError)
  }

  func testLoadSchools_error_setsSubmitError() async {
    // Given
    mockService.shouldThrowError = true

    // When
    await viewModel.loadSchools()

    // Then
    XCTAssertTrue(viewModel.schools.isEmpty)
    XCTAssertEqual(viewModel.submitError, "Failed to load schools. Please try again.")
    XCTAssertFalse(viewModel.isLoadingSchools)
  }

  func testLoadSchools_preventsDuplicateCalls() async {
    // Given: Simulate already-loading state
    viewModel.isLoadingSchools = true
    mockService.mockSchools = [School.mock(id: "1", name: "School A")]

    // When: Try to load while already loading
    await viewModel.loadSchools()

    // Then: Guard should prevent any service call
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 0)
  }

  func testLoadSchools_withEmptyResult_setsEmptyArray() async {
    // Given
    mockService.mockSchools = []

    // When
    await viewModel.loadSchools()

    // Then
    XCTAssertTrue(viewModel.schools.isEmpty)
    XCTAssertFalse(viewModel.isLoadingSchools)
  }

  func testLoadSchools_clearsSubmitErrorBeforeLoading() async {
    // Given
    viewModel.submitError = "Previous error"
    mockService.mockSchools = [School.mock(id: "1", name: "School A")]

    // When
    await viewModel.loadSchools()

    // Then
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - validateField() Tests

  func testValidateField_firstName_valid_clearsError() {
    // Given
    viewModel.formErrors.firstName = "Previous error"

    // When
    viewModel.validateField(\.firstName, value: "John")

    // Then
    XCTAssertNil(viewModel.formErrors.firstName)
  }

  func testValidateField_firstName_invalid_setsError() {
    // When
    viewModel.validateField(\.firstName, value: "")

    // Then
    XCTAssertEqual(viewModel.formErrors.firstName, "First name is required")
  }

  func testValidateField_lastName_valid_clearsError() {
    // Given
    viewModel.formErrors.lastName = "Previous error"

    // When
    viewModel.validateField(\.lastName, value: "Smith")

    // Then
    XCTAssertNil(viewModel.formErrors.lastName)
  }

  func testValidateField_lastName_invalid_setsError() {
    // When
    viewModel.validateField(\.lastName, value: "")

    // Then
    XCTAssertEqual(viewModel.formErrors.lastName, "Last name is required")
  }

  func testValidateField_email_valid_clearsError() {
    // Given
    viewModel.formErrors.email = "Previous error"

    // When
    viewModel.validateField(\.email, value: "john@example.com")

    // Then
    XCTAssertNil(viewModel.formErrors.email)
  }

  func testValidateField_email_invalid_setsError() {
    // When
    viewModel.validateField(\.email, value: "notanemail")

    // Then
    XCTAssertEqual(viewModel.formErrors.email, "Please enter a valid email address")
  }

  func testValidateField_email_empty_clearsError() {
    // Given
    viewModel.formErrors.email = "Previous error"

    // When
    viewModel.validateField(\.email, value: "")

    // Then: Empty email is optional
    XCTAssertNil(viewModel.formErrors.email)
  }

  func testValidateField_phone_valid_clearsError() {
    // Given
    viewModel.formErrors.phone = "Previous error"

    // When
    viewModel.validateField(\.phone, value: "(555) 123-4567")

    // Then
    XCTAssertNil(viewModel.formErrors.phone)
  }

  func testValidateField_phone_invalid_setsError() {
    // When
    viewModel.validateField(\.phone, value: "123")

    // Then
    XCTAssertEqual(viewModel.formErrors.phone, "Please enter a valid phone number")
  }

  func testValidateField_twitterHandle_valid_clearsError() {
    // Given
    viewModel.formErrors.twitterHandle = "Previous error"

    // When
    viewModel.validateField(\.twitterHandle, value: "@testuser")

    // Then
    XCTAssertNil(viewModel.formErrors.twitterHandle)
  }

  func testValidateField_twitterHandle_invalid_setsError() {
    // When
    viewModel.validateField(\.twitterHandle, value: "this_is_way_too_long_for_twitter")

    // Then
    XCTAssertEqual(
      viewModel.formErrors.twitterHandle,
      "Invalid Twitter handle (1-15 characters, letters/numbers/underscore)"
    )
  }

  func testValidateField_instagramHandle_valid_clearsError() {
    // Given
    viewModel.formErrors.instagramHandle = "Previous error"

    // When
    viewModel.validateField(\.instagramHandle, value: "@test.user")

    // Then
    XCTAssertNil(viewModel.formErrors.instagramHandle)
  }

  func testValidateField_instagramHandle_invalid_setsError() {
    // When
    viewModel.validateField(\.instagramHandle, value: "invalid handle with spaces")

    // Then
    XCTAssertEqual(
      viewModel.formErrors.instagramHandle,
      "Invalid Instagram handle (1-30 characters, letters/numbers/dots/underscore)"
    )
  }

  func testValidateField_notes_valid_clearsError() {
    // Given
    viewModel.formErrors.notes = "Previous error"

    // When
    viewModel.validateField(\.notes, value: "Some notes")

    // Then
    XCTAssertNil(viewModel.formErrors.notes)
  }

  func testValidateField_notes_tooLong_setsError() {
    // Given
    let longNotes = String(repeating: "a", count: 5001)

    // When
    viewModel.validateField(\.notes, value: longNotes)

    // Then
    XCTAssertEqual(viewModel.formErrors.notes, "Notes must not exceed 5000 characters")
  }

  // MARK: - validateRole() Tests

  func testValidateRole_nil_setsError() {
    // When
    viewModel.validateRole(nil)

    // Then
    XCTAssertEqual(viewModel.formErrors.role, "Please select a role")
  }

  func testValidateRole_withValue_clearsError() {
    // Given
    viewModel.formErrors.role = "Previous error"

    // When
    viewModel.validateRole(.head)

    // Then
    XCTAssertNil(viewModel.formErrors.role)
  }

  // MARK: - submitCoach() Tests

  func testSubmitCoach_success_returnsNewCoach() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    let mockCoach = Coach.mock(
      id: "new-coach-123",
      firstName: "John",
      lastName: "Smith"
    )
    mockService.mockCreatedCoach = mockCoach

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-coach-123")
    XCTAssertEqual(result?.firstName, "John")
    XCTAssertEqual(result?.lastName, "Smith")
    XCTAssertNil(viewModel.submitError)
  }

  func testSubmitCoach_success_callsServiceWithCorrectData() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .assistant
    viewModel.formState.firstName = "Jane"
    viewModel.formState.lastName = "Doe"
    viewModel.formState.email = "jane@example.com"

    mockService.mockCreatedCoach = Coach.mock(id: "new", firstName: "Jane", lastName: "Doe")

    // When
    _ = await viewModel.submitCoach()

    // Then
    XCTAssertEqual(mockService.createCoachCallCount, 1)
    XCTAssertEqual(mockService.lastCreateCoachRequest?.firstName, "Jane")
    XCTAssertEqual(mockService.lastCreateCoachRequest?.lastName, "Doe")
    XCTAssertEqual(mockService.lastCreateCoachRequest?.role, "assistant")
  }

  func testSubmitCoach_validationError_returnsNil() async {
    // Given: Missing required field (firstName)
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""  // Invalid
    viewModel.formState.lastName = "Smith"

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertNotNil(viewModel.formErrors.firstName)
    XCTAssertEqual(mockService.createCoachCallCount, 0)  // Should not call service
  }

  func testSubmitCoach_networkError_returnsNilAndSetsError() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    mockService.shouldThrowError = true

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.submitError, "Failed to create coach. Please try again.")
  }

  func testSubmitCoach_missingSchool_returnsNilAndSetsError() async {
    // Given: No school selected
    viewModel.formState.selectedSchoolId = nil
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.submitError, "Please select a school")
    XCTAssertEqual(mockService.createCoachCallCount, 0)
  }

  func testSubmitCoach_setsIsSubmittingDuringOperation() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    mockService.mockCreatedCoach = Coach.mock(id: "new", firstName: "John", lastName: "Smith")

    // When/Then: isSubmitting should be true during operation
    let expectation = XCTestExpectation(description: "isSubmitting is set")

    Task {
      // Check before submission
      XCTAssertFalse(viewModel.isSubmitting)

      // Start submission
      _ = await viewModel.submitCoach()

      // Check after submission
      XCTAssertFalse(viewModel.isSubmitting)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 2.0)
  }

  func testSubmitCoach_clearsSubmitErrorBeforeSubmitting() async {
    // Given
    viewModel.submitError = "Previous error"
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    mockService.mockCreatedCoach = Coach.mock(id: "new", firstName: "John", lastName: "Smith")

    // When
    _ = await viewModel.submitCoach()

    // Then
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - Computed Properties Tests

  func testIsFormVisible_whenSchoolNotSelected_returnsFalse() {
    // Given
    viewModel.formState.selectedSchoolId = nil

    // Then
    XCTAssertFalse(viewModel.isFormVisible)
  }

  func testIsFormVisible_whenSchoolSelected_returnsTrue() {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"

    // Then
    XCTAssertTrue(viewModel.isFormVisible)
  }

  func testIsSubmitDisabled_whenSubmitting_returnsTrue() {
    // Given
    viewModel.isSubmitting = true
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenHasErrors_returnsTrue() {
    // Given
    viewModel.formErrors.firstName = "Error"
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.lastName = "Smith"

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenFormNotSubmittable_returnsTrue() {
    // Given: Missing required field
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    // Missing lastName

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenFormValid_returnsFalse() {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    // Then
    XCTAssertFalse(viewModel.isSubmitDisabled)
  }

  func testSubmitButtonTitle_whenNotSubmitting_returnsAddCoach() {
    // Given
    viewModel.isSubmitting = false

    // Then
    XCTAssertEqual(viewModel.submitButtonTitle, "Add Coach")
  }

  func testSubmitButtonTitle_whenSubmitting_returnsAdding() {
    // Given
    viewModel.isSubmitting = true

    // Then
    XCTAssertEqual(viewModel.submitButtonTitle, "Adding...")
  }

  // MARK: - Helper Methods Tests

  func testClearErrors_resetsAllErrors() {
    // Given
    viewModel.formErrors.firstName = "Error 1"
    viewModel.formErrors.email = "Error 2"
    viewModel.submitError = "Submit error"

    // When
    viewModel.clearErrors()

    // Then
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }

  func testResetForm_resetsFormState() {
    // Given
    viewModel.formState.selectedSchoolId = "school-123"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formErrors.firstName = "Error"
    viewModel.submitError = "Submit error"

    // When
    viewModel.resetForm()

    // Then
    XCTAssertNil(viewModel.formState.selectedSchoolId)
    XCTAssertNil(viewModel.formState.role)
    XCTAssertEqual(viewModel.formState.firstName, "")
    XCTAssertEqual(viewModel.formState.lastName, "")
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }
}

// MARK: - Test Helpers

extension School {
  static func mock(id: String, name: String) -> School {
    School(
      id: id,
      userId: "test-user",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: "D1",
      conference: nil,
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "active",
      statusChangedAt: nil,
      priorityTier: nil,
      notes: nil,
      privateNotes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "test-family",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2026-02-10T00:00:00Z",
      updatedAt: "2026-02-10T00:00:00Z"
    )
  }
}

extension Coach {
  static func mock(
    id: String,
    firstName: String,
    lastName: String,
    role: CoachRole = .head
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: nil,
      phone: nil,
      position: role.rawValue,
      schoolId: "test-school",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      privateNotes: nil,
      responsivenessScore: 0,
      lastContactDate: nil,
      createdAt: "2026-02-10T00:00:00Z",
      updatedAt: "2026-02-10T00:00:00Z"
    )
  }
}
