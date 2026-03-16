//
//  AddSchoolViewModelTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 5: ViewModel - AddSchoolViewModel tests
//

import XCTest
@testable import TheRecruitingCompass

// MARK: - Test Helpers

private final class MockNcaaDatabase: NcaaDatabaseManaging, @unchecked Sendable {
  var mockResult: NcaaLookupResult?
  var lookupCallCount = 0
  var lastLookedUpName: String?

  func lookup(schoolName: String) async -> NcaaLookupResult? {
    lookupCallCount += 1
    lastLookedUpName = schoolName
    return mockResult
  }
}

private final class MockSchoolFaviconService: SchoolFaviconManaging, @unchecked Sendable {
  func fetchAndPersist(school: School) async {}
}

// MARK: - Tests

@MainActor
final class AddSchoolViewModelTests: XCTestCase {

  var viewModel: AddSchoolViewModel!
  var mockService: MockSchoolsService!

  override func setUp() async throws {
    mockService = MockSchoolsService()
    viewModel = AddSchoolViewModel(
      schoolsService: mockService,
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
    XCTAssertEqual(viewModel.formState.name, "")
    XCTAssertEqual(viewModel.formState.location, "")
    XCTAssertEqual(viewModel.formState.city, "")
    XCTAssertEqual(viewModel.formState.state, "")
    XCTAssertNil(viewModel.formState.division)
    XCTAssertEqual(viewModel.formState.conference, "")
    XCTAssertEqual(viewModel.formState.website, "")
    XCTAssertEqual(viewModel.formState.twitterHandle, "")
    XCTAssertEqual(viewModel.formState.instagramHandle, "")
    XCTAssertEqual(viewModel.formState.notes, "")
    XCTAssertEqual(viewModel.formState.status, .interested)
  }

  func testInit_initializesWithEmptyErrors() {
    // Then
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertTrue(viewModel.formErrors.allErrors.isEmpty)
  }

  func testInit_initializesWithInjectedDependencies() {
    // Then
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - validateField() Tests - Name

  func testValidateField_name_valid_clearsError() {
    // Given
    viewModel.formErrors.name = "Previous error"

    // When
    viewModel.validateField(\.name, value: "Harvard University")

    // Then
    XCTAssertNil(viewModel.formErrors.name)
  }

  func testValidateField_name_empty_setsError() {
    // When
    viewModel.validateField(\.name, value: "")

    // Then
    XCTAssertEqual(viewModel.formErrors.name, "School name is required")
  }

  func testValidateField_name_tooShort_setsError() {
    // When
    viewModel.validateField(\.name, value: "A")

    // Then
    XCTAssertEqual(viewModel.formErrors.name, "School name must be at least 2 characters")
  }

  func testValidateField_name_tooLong_setsError() {
    // When
    viewModel.validateField(\.name, value: String(repeating: "a", count: 256))

    // Then
    XCTAssertEqual(viewModel.formErrors.name, "School name must not exceed 255 characters")
  }

  // MARK: - validateField() Tests - Location

  func testValidateField_location_valid_clearsError() {
    // Given
    viewModel.formErrors.location = "Previous error"

    // When
    viewModel.validateField(\.location, value: "Cambridge, MA")

    // Then
    XCTAssertNil(viewModel.formErrors.location)
  }

  func testValidateField_location_empty_clearsError() {
    // Given
    viewModel.formErrors.location = "Previous error"

    // When
    viewModel.validateField(\.location, value: "")

    // Then
    XCTAssertNil(viewModel.formErrors.location)
  }

  func testValidateField_location_tooLong_setsError() {
    // When
    viewModel.validateField(\.location, value: String(repeating: "a", count: 256))

    // Then
    XCTAssertEqual(viewModel.formErrors.location, "Location must not exceed 255 characters")
  }

  // MARK: - validateField() Tests - City

  func testValidateField_city_valid_clearsError() {
    // Given
    viewModel.formErrors.city = "Previous error"

    // When
    viewModel.validateField(\.city, value: "Cambridge")

    // Then
    XCTAssertNil(viewModel.formErrors.city)
  }

  func testValidateField_city_tooLong_setsError() {
    // When
    viewModel.validateField(\.city, value: String(repeating: "a", count: 101))

    // Then
    XCTAssertEqual(viewModel.formErrors.city, "City must not exceed 100 characters")
  }

  // MARK: - validateField() Tests - State

  func testValidateField_state_valid_clearsError() {
    // Given
    viewModel.formErrors.state = "Previous error"

    // When
    viewModel.validateField(\.state, value: "Massachusetts")

    // Then
    XCTAssertNil(viewModel.formErrors.state)
  }

  func testValidateField_state_tooLong_setsError() {
    // When
    viewModel.validateField(\.state, value: String(repeating: "a", count: 101))

    // Then
    XCTAssertEqual(viewModel.formErrors.state, "State must not exceed 100 characters")
  }

  // MARK: - validateField() Tests - Conference

  func testValidateField_conference_valid_clearsError() {
    // Given
    viewModel.formErrors.conference = "Previous error"

    // When
    viewModel.validateField(\.conference, value: "Ivy League")

    // Then
    XCTAssertNil(viewModel.formErrors.conference)
  }

  func testValidateField_conference_tooLong_setsError() {
    // When
    viewModel.validateField(\.conference, value: String(repeating: "a", count: 101))

    // Then
    XCTAssertEqual(viewModel.formErrors.conference, "Conference must not exceed 100 characters")
  }

  // MARK: - validateField() Tests - Website

  func testValidateField_website_validHTTP_clearsError() {
    // Given
    viewModel.formErrors.website = "Previous error"

    // When
    viewModel.validateField(\.website, value: "http://harvard.edu")

    // Then
    XCTAssertNil(viewModel.formErrors.website)
  }

  func testValidateField_website_validHTTPS_clearsError() {
    // Given
    viewModel.formErrors.website = "Previous error"

    // When
    viewModel.validateField(\.website, value: "https://harvard.edu")

    // Then
    XCTAssertNil(viewModel.formErrors.website)
  }

  func testValidateField_website_nonHttpScheme_setsError() {
    // Bare domains like "harvard.edu" are accepted; non-http schemes are not
    viewModel.validateField(\.website, value: "ftp://harvard.edu")

    XCTAssertNotNil(viewModel.formErrors.website)
  }

  func testValidateField_website_bareDomain_clearsError() {
    viewModel.formErrors.website = "Previous error"

    viewModel.validateField(\.website, value: "harvard.edu")

    XCTAssertNil(viewModel.formErrors.website)
  }

  func testValidateField_website_empty_clearsError() {
    // Given
    viewModel.formErrors.website = "Previous error"

    // When
    viewModel.validateField(\.website, value: "")

    // Then
    XCTAssertNil(viewModel.formErrors.website)
  }

  // MARK: - validateField() Tests - Twitter

  func testValidateField_twitter_valid_clearsError() {
    // Given
    viewModel.formErrors.twitterHandle = "Previous error"

    // When
    viewModel.validateField(\.twitterHandle, value: "Harvard")

    // Then
    XCTAssertNil(viewModel.formErrors.twitterHandle)
  }

  func testValidateField_twitter_invalid_setsError() {
    // When
    viewModel.validateField(\.twitterHandle, value: "@1234567890123456") // 16 chars (max 15)

    // Then
    XCTAssertNotNil(viewModel.formErrors.twitterHandle)
  }

  // MARK: - validateField() Tests - Instagram

  func testValidateField_instagram_valid_clearsError() {
    // Given
    viewModel.formErrors.instagramHandle = "Previous error"

    // When
    viewModel.validateField(\.instagramHandle, value: "harvard")

    // Then
    XCTAssertNil(viewModel.formErrors.instagramHandle)
  }

  func testValidateField_instagram_invalid_setsError() {
    // When
    viewModel.validateField(\.instagramHandle, value: "@" + String(repeating: "a", count: 31)) // 31 chars (max 30)

    // Then
    XCTAssertNotNil(viewModel.formErrors.instagramHandle)
  }

  // MARK: - validateField() Tests - Notes

  func testValidateField_notes_valid_clearsError() {
    // Given
    viewModel.formErrors.notes = "Previous error"

    // When
    viewModel.validateField(\.notes, value: "Great academic school")

    // Then
    XCTAssertNil(viewModel.formErrors.notes)
  }

  func testValidateField_notes_tooLong_setsError() {
    // When
    viewModel.validateField(\.notes, value: String(repeating: "a", count: 5001))

    // Then
    XCTAssertEqual(viewModel.formErrors.notes, "Notes must not exceed 5000 characters")
  }

  // MARK: - submitSchool() Tests - Success

  func testSubmitSchool_success_returnsSchool() async {
    // Given
    viewModel.formState.name = "Harvard University"
    viewModel.formState.status = .recruited
    let mockSchool = School.mock(id: "new-school-123", name: "Harvard University")
    mockService.stubbedCreatedSchool = mockSchool

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-school-123")
    XCTAssertEqual(result?.name, "Harvard University")
    XCTAssertEqual(mockService.createSchoolCallCount, 1)
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertNil(viewModel.submitError)
  }

  func testSubmitSchool_success_clearsSubmitError() async {
    // Given
    viewModel.formState.name = "Harvard"
    viewModel.submitError = "Previous error"
    mockService.stubbedCreatedSchool = School.mock(id: "1", name: "Harvard")

    // When
    _ = await viewModel.submitSchool()

    // Then
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - submitSchool() Tests - Validation Errors

  func testSubmitSchool_invalidName_returnsNil() async {
    // Given
    viewModel.formState.name = "" // Invalid: required

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertNotNil(viewModel.formErrors.name)
    XCTAssertEqual(mockService.createSchoolCallCount, 0)
  }

  func testSubmitSchool_nameTooShort_returnsNil() async {
    // Given
    viewModel.formState.name = "A" // Invalid: too short

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertEqual(viewModel.formErrors.name, "School name must be at least 2 characters")
  }

  func testSubmitSchool_invalidWebsite_returnsNil() async {
    // Given
    viewModel.formState.name = "Harvard"
    viewModel.formState.website = "ftp://harvard.edu" // Invalid: non-http scheme

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertNotNil(viewModel.formErrors.website)
  }

  func testSubmitSchool_multipleErrors_returnsNilWithAllErrors() async {
    // Given
    viewModel.formState.name = "" // Invalid: required
    viewModel.formState.website = "ftp://bad.edu" // Invalid: non-http scheme
    viewModel.formState.notes = String(repeating: "a", count: 5001) // Invalid: too long

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.formErrors.hasErrors)
    XCTAssertEqual(viewModel.formErrors.allErrors.count, 3)
  }

  // MARK: - submitSchool() Tests - Service Errors

  func testSubmitSchool_serviceError_returnsNilWithError() async {
    // Given
    viewModel.formState.name = "Harvard"
    mockService.shouldThrowError = true

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.submitError, "Failed to create school. Please try again.")
    XCTAssertFalse(viewModel.isSubmitting)
  }

  // MARK: - submitSchool() Tests - Loading State

  func testSubmitSchool_setsIsSubmittingDuringSubmission() async {
    // Given
    viewModel.formState.name = "Harvard"
    mockService.stubbedCreatedSchool = School.mock(id: "1", name: "Harvard")

    // When
    let submitTask = Task {
      _ = await viewModel.submitSchool()
    }

    // Then: Check loading state (might already be done, so check call was made)
    await submitTask.value
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertEqual(mockService.createSchoolCallCount, 1)
  }

  // MARK: - Computed Properties Tests

  func testIsSubmitDisabled_whenSubmitting_returnsTrue() {
    // Given
    viewModel.formState.name = "Harvard"
    viewModel.isSubmitting = true

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenHasErrors_returnsTrue() {
    // Given
    viewModel.formState.name = "Harvard"
    viewModel.formErrors.name = "Some error"

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenNotSubmittable_returnsTrue() {
    // Given
    viewModel.formState.name = "" // Not submittable

    // Then
    XCTAssertTrue(viewModel.isSubmitDisabled)
  }

  func testIsSubmitDisabled_whenValid_returnsFalse() {
    // Given
    viewModel.formState.name = "Harvard" // Valid and submittable

    // Then
    XCTAssertFalse(viewModel.isSubmitDisabled)
  }

  func testSubmitButtonTitle_whenNotSubmitting_returnsAddSchool() {
    // Given
    viewModel.isSubmitting = false

    // Then
    XCTAssertEqual(viewModel.submitButtonTitle, "Add School")
  }

  func testSubmitButtonTitle_whenSubmitting_returnsAdding() {
    // Given
    viewModel.isSubmitting = true

    // Then
    XCTAssertEqual(viewModel.submitButtonTitle, "Adding...")
  }

  // MARK: - Helper Methods Tests

  func testClearErrors_clearsFormErrors() {
    // Given
    viewModel.formErrors.name = "Error 1"
    viewModel.formErrors.website = "Error 2"
    viewModel.submitError = "Submit error"

    // When
    viewModel.clearErrors()

    // Then
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }

  func testResetForm_resetsFormStateToInitial() {
    // Given
    viewModel.formState.name = "Harvard"
    viewModel.formState.location = "Cambridge"
    viewModel.formState.division = .d1
    viewModel.formErrors.name = "Error"
    viewModel.submitError = "Submit error"

    // When
    viewModel.resetForm()

    // Then
    XCTAssertEqual(viewModel.formState.name, "")
    XCTAssertEqual(viewModel.formState.location, "")
    XCTAssertNil(viewModel.formState.division)
    XCTAssertFalse(viewModel.formErrors.hasErrors)
    XCTAssertNil(viewModel.submitError)
  }

  // MARK: - selectCollege() NCAA Lookup Tests

  private func makeViewModelWithMockNcaa(result: NcaaLookupResult?) -> (AddSchoolViewModel, MockNcaaDatabase) {
    let mockNcaa = MockNcaaDatabase()
    mockNcaa.mockResult = result
    let vm = AddSchoolViewModel(
      schoolsService: mockService,
      collegeScorecardService: MockCollegeScorecardService(),
      ncaaDatabase: mockNcaa,
      schoolFaviconService: MockSchoolFaviconService(),
      familyUnitId: "test-family-123",
      userId: "test-user-456",
      announcer: MockAccessibilityAnnouncer()
    )
    return (vm, mockNcaa)
  }

  private func makeCollegeSearchResult(name: String = "University of Florida") -> CollegeSearchResult {
    CollegeSearchResult(
      id: "134130",
      name: name,
      city: "Gainesville",
      state: "FL",
      website: "https://ufl.edu"
    )
  }

  func testSelectCollege_populatesDivisionAndConference() async {
    // Given
    let (vm, _) = makeViewModelWithMockNcaa(result: NcaaLookupResult(division: .d1, conference: "SEC"))

    // When
    await vm.selectCollege(makeCollegeSearchResult())

    // Then
    XCTAssertEqual(vm.formState.division, .d1)
    XCTAssertEqual(vm.formState.conference, "SEC")
  }

  func testSelectCollege_callsNcaaLookupWithSchoolName() async {
    // Given
    let (vm, mockNcaa) = makeViewModelWithMockNcaa(result: NcaaLookupResult(division: .d1, conference: "Big Ten"))

    // When
    await vm.selectCollege(makeCollegeSearchResult(name: "University of Michigan"))

    // Then - NCAA lookup must be called with the college name
    XCTAssertGreaterThan(mockNcaa.lookupCallCount, 0)
    XCTAssertEqual(mockNcaa.lastLookedUpName, "University of Michigan")
  }

  func testSelectCollege_withNoNcaaMatch_leavesDivisionNil() async {
    // Given
    let (vm, _) = makeViewModelWithMockNcaa(result: nil)

    // When
    await vm.selectCollege(makeCollegeSearchResult(name: "Unknown Community College"))

    // Then
    XCTAssertNil(vm.formState.division)
    XCTAssertEqual(vm.formState.conference, "")
  }

  func testSelectCollege_secondSelection_populatesNewDivisionAndConference() async {
    // Given - first selection populates SEC
    let (vm, mockNcaa) = makeViewModelWithMockNcaa(result: NcaaLookupResult(division: .d1, conference: "SEC"))
    await vm.selectCollege(makeCollegeSearchResult(name: "University of Florida"))
    XCTAssertEqual(vm.formState.conference, "SEC")

    // Clear and select a second school
    vm.clearSelection()
    mockNcaa.mockResult = NcaaLookupResult(division: .d1, conference: "Big Ten")
    let michigan = CollegeSearchResult(
      id: "147767",
      name: "University of Michigan",
      city: "Ann Arbor",
      state: "MI",
      website: "https://umich.edu"
    )

    // When
    await vm.selectCollege(michigan)

    // Then - second selection must also populate division/conference
    XCTAssertEqual(vm.formState.division, .d1)
    XCTAssertEqual(vm.formState.conference, "Big Ten")
  }

  func testSelectCollege_alwaysCallsNcaaLookupRegardlessOfPreviousResult() async {
    // Regression: ensure NCAA lookup is called on every selection, not skipped after
    // a previous selection already populated the division.
    let (vm, mockNcaa) = makeViewModelWithMockNcaa(result: NcaaLookupResult(division: .d1, conference: "SEC"))

    // First selection
    await vm.selectCollege(makeCollegeSearchResult(name: "University of Florida"))
    let firstCallCount = mockNcaa.lookupCallCount
    XCTAssertGreaterThan(firstCallCount, 0)

    // Clear and select again
    vm.clearSelection()
    mockNcaa.mockResult = NcaaLookupResult(division: .d2, conference: "Some Conference")
    await vm.selectCollege(makeCollegeSearchResult(name: "University of Florida"))

    // Then - lookup was called again after clearing selection
    XCTAssertGreaterThan(mockNcaa.lookupCallCount, firstCallCount,
                         "NCAA lookup must be called again for each new college selection")
    XCTAssertEqual(vm.formState.division, .d2)
  }
}
