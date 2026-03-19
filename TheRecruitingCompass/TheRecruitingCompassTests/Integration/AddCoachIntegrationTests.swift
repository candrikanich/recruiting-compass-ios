//
//  AddCoachIntegrationTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Integration tests for Add Coach feature
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddCoachIntegrationTests: XCTestCase {
  nonisolated deinit {}

  var mockService: MockCoachesService!
  var viewModel: AddCoachViewModel!

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

  // MARK: - Full Submission Flow Tests

  func testFullAddCoachFlow_withAllFields_succeeds() async {
    // Given: Schools loaded
    mockService.mockSchools = [
      School.mock(id: "school-1", name: "Test University")
    ]
    await viewModel.loadSchools()
    XCTAssertEqual(viewModel.schools.count, 1)

    // Given: Form filled with all fields
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formState.email = "john.smith@university.edu"
    viewModel.formState.phone = "(555) 123-4567"
    viewModel.formState.twitterHandle = "@coachsmith"
    viewModel.formState.instagramHandle = "@coach.smith"
    viewModel.formState.notes = "Excellent recruiter"

    // Given: Mock successful creation
    let mockCoach = Coach.mock(
      id: "new-coach-123",
      firstName: "John",
      lastName: "Smith",
      role: .head
    )
    mockService.mockCreatedCoach = mockCoach

    // When: Submit
    let result = await viewModel.submitCoach()

    // Then: Success
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-coach-123")
    XCTAssertEqual(result?.firstName, "John")
    XCTAssertEqual(result?.lastName, "Smith")
    XCTAssertNil(viewModel.submitError)
    XCTAssertFalse(viewModel.formErrors.hasErrors)
  }

  func testFullAddCoachFlow_withRequiredFieldsOnly_succeeds() async {
    // Given: Schools loaded
    mockService.mockSchools = [School.mock(id: "school-1", name: "Test University")]
    await viewModel.loadSchools()

    // Given: Form filled with only required fields
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .assistant
    viewModel.formState.firstName = "Jane"
    viewModel.formState.lastName = "Doe"

    // Given: Mock successful creation
    mockService.mockCreatedCoach = Coach.mock(
      id: "new-coach-456",
      firstName: "Jane",
      lastName: "Doe",
      role: .assistant
    )

    // When: Submit
    let result = await viewModel.submitCoach()

    // Then: Success
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.firstName, "Jane")
    XCTAssertEqual(result?.lastName, "Doe")
    XCTAssertNil(viewModel.submitError)
  }

  func testFullAddCoachFlow_withOptionalFieldsMixed_succeeds() async {
    // Given: Schools loaded
    mockService.mockSchools = [School.mock(id: "school-1", name: "Test University")]
    await viewModel.loadSchools()

    // Given: Form with some optional fields
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .recruiting
    viewModel.formState.firstName = "Bob"
    viewModel.formState.lastName = "Johnson"
    viewModel.formState.email = "bob@example.com"
    viewModel.formState.twitterHandle = "@bobjohnson"
    // Leave phone, instagram, notes empty

    // Given: Mock successful creation
    mockService.mockCreatedCoach = Coach.mock(
      id: "new-coach-789",
      firstName: "Bob",
      lastName: "Johnson",
      role: .recruiting
    )

    // When: Submit
    let result = await viewModel.submitCoach()

    // Then: Success
    XCTAssertNotNil(result)
    XCTAssertEqual(mockService.lastCreateCoachRequest?.email, "bob@example.com")
    XCTAssertEqual(mockService.lastCreateCoachRequest?.twitterHandle, "bobjohnson")
    XCTAssertNil(mockService.lastCreateCoachRequest?.phone)
    XCTAssertNil(mockService.lastCreateCoachRequest?.instagramHandle)
  }

  // MARK: - Validation Error Handling Tests

  func testSubmissionWithValidationErrors_showsErrorsAndPreventsSubmission() async {
    // Given: Schools loaded
    mockService.mockSchools = [School.mock(id: "school-1", name: "Test University")]
    await viewModel.loadSchools()

    // Given: Form with validation errors
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""  // Invalid: required
    viewModel.formState.lastName = ""  // Invalid: required
    viewModel.formState.email = "notanemail"  // Invalid: bad format

    // When: Attempt submit
    let result = await viewModel.submitCoach()

    // Then: Submission prevented
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertEqual(viewModel.formErrors.allErrors.count, 3)
    XCTAssertNotNil(viewModel.formErrors.firstName)
    XCTAssertNotNil(viewModel.formErrors.lastName)
    XCTAssertNotNil(viewModel.formErrors.email)
    XCTAssertEqual(mockService.createCoachCallCount, 0)  // Should not call service
  }

  func testFixingValidationErrors_clearsErrors() async {
    // Given: Form with errors
    viewModel.formState.firstName = ""
    viewModel.validateField(\.firstName, value: "")
    XCTAssertNotNil(viewModel.formErrors.firstName)

    // When: Fix error
    viewModel.formState.firstName = "John"
    viewModel.validateField(\.firstName, value: "John")

    // Then: Error cleared
    XCTAssertNil(viewModel.formErrors.firstName)
  }

  func testValidationErrors_preventSubmissionUntilFixed() async {
    // Given: Schools loaded
    mockService.mockSchools = [School.mock(id: "school-1", name: "Test University")]
    await viewModel.loadSchools()

    // Given: Form with one error
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = ""  // Invalid
    viewModel.formState.lastName = "Smith"

    // When: Attempt submit
    let result1 = await viewModel.submitCoach()

    // Then: Submission prevented
    XCTAssertNil(result1)
    XCTAssertEqual(mockService.createCoachCallCount, 0)

    // When: Fix error and resubmit
    viewModel.formState.firstName = "John"
    mockService.mockCreatedCoach = Coach.mock(
      id: "new-coach",
      firstName: "John",
      lastName: "Smith"
    )
    let result2 = await viewModel.submitCoach()

    // Then: Submission succeeds
    XCTAssertNotNil(result2)
    XCTAssertEqual(mockService.createCoachCallCount, 1)
  }

  // MARK: - Network Error Handling Tests

  func testNetworkTimeout_duringSchoolLoad_showsError() async {
    // Given
    mockService.shouldThrowError = true

    // When
    await viewModel.loadSchools()

    // Then
    XCTAssertTrue(viewModel.schools.isEmpty)
    XCTAssertEqual(viewModel.submitError, "Failed to load schools. Please try again.")
  }

  func testNetworkTimeout_duringSubmit_showsErrorAndPreservesForm() async {
    // Given: Form filled
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formState.email = "john@example.com"

    // Given: Network error
    mockService.shouldThrowError = true

    // When: Submit
    let result = await viewModel.submitCoach()

    // Then: Error shown, form preserved
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.submitError, "Failed to create coach. Please try again.")
    XCTAssertEqual(viewModel.formState.firstName, "John")  // Form data preserved
    XCTAssertEqual(viewModel.formState.lastName, "Smith")
    XCTAssertEqual(viewModel.formState.email, "john@example.com")
  }

  // MARK: - Success Navigation Tests

  func testSuccessfulCreation_returnsCoachWithId() async {
    // Given
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"

    let expectedCoach = Coach.mock(
      id: "new-coach-123",
      firstName: "John",
      lastName: "Smith"
    )
    mockService.mockCreatedCoach = expectedCoach

    // When
    let result = await viewModel.submitCoach()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-coach-123")
    XCTAssertFalse(result?.id.isEmpty ?? true)
  }

  func testFormStatePreserved_onNetworkError() async {
    // Given: Form filled
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formState.email = "john@example.com"
    viewModel.formState.phone = "(555) 123-4567"
    viewModel.formState.twitterHandle = "@coachsmith"
    viewModel.formState.notes = "Great coach"

    // Given: Network error
    mockService.shouldThrowError = true

    // When: Submit fails
    _ = await viewModel.submitCoach()

    // Then: All form data preserved for retry
    XCTAssertEqual(viewModel.formState.selectedSchoolId, "school-1")
    XCTAssertEqual(viewModel.formState.role, .head)
    XCTAssertEqual(viewModel.formState.firstName, "John")
    XCTAssertEqual(viewModel.formState.lastName, "Smith")
    XCTAssertEqual(viewModel.formState.email, "john@example.com")
    XCTAssertEqual(viewModel.formState.phone, "(555) 123-4567")
    XCTAssertEqual(viewModel.formState.twitterHandle, "@coachsmith")
    XCTAssertEqual(viewModel.formState.notes, "Great coach")
  }

  // MARK: - Cancel Flow Tests

  func testResetForm_beforeSchoolSelection_clearsState() {
    // Given: Some initial state
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formErrors.firstName = "Error"
    viewModel.submitError = "Some error"

    // When
    viewModel.resetForm()

    // Then
    XCTAssertNil(viewModel.formState.selectedSchoolId)
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }

  func testResetForm_afterFillingForm_clearsAllData() {
    // Given: Form fully filled
    viewModel.formState.selectedSchoolId = "school-1"
    viewModel.formState.role = .head
    viewModel.formState.firstName = "John"
    viewModel.formState.lastName = "Smith"
    viewModel.formState.email = "john@example.com"
    viewModel.formState.phone = "(555) 123-4567"
    viewModel.formErrors.email = "Error"
    viewModel.submitError = "Submit error"

    // When
    viewModel.resetForm()

    // Then: Everything cleared
    XCTAssertNil(viewModel.formState.selectedSchoolId)
    XCTAssertNil(viewModel.formState.role)
    XCTAssertEqual(viewModel.formState.firstName, "")
    XCTAssertEqual(viewModel.formState.lastName, "")
    XCTAssertEqual(viewModel.formState.email, "")
    XCTAssertEqual(viewModel.formState.phone, "")
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }
}
