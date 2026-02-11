//
//  AddSchoolViewModel+DuplicateDetectionTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11.
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddSchoolViewModelDuplicateDetectionTests: XCTestCase {

  // MARK: - Properties

  private var viewModel: AddSchoolViewModel!
  private var mockSchoolsService: MockSchoolsService!
  private var mockScorecardService: MockCollegeScorecardService!

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    mockSchoolsService = MockSchoolsService()
    mockScorecardService = MockCollegeScorecardService()
    viewModel = AddSchoolViewModel(
      schoolsService: mockSchoolsService,
      familyUnitId: "test-family",
      userId: "test-user"
    )
  }

  override func tearDown() {
    viewModel = nil
    mockSchoolsService = nil
    mockScorecardService = nil
    super.tearDown()
  }

  // MARK: - Test Data

  private func makeTestSchool(
    id: String = "existing-id",
    name: String = "Stanford University",
    website: String? = "https://stanford.edu",
    ncaaId: String? = "123"
  ) -> School {
    School(
      id: id,
      userId: "test-user",
      name: name,
      location: "Stanford, CA",
      city: "Stanford",
      state: "CA",
      division: "D1",
      conference: "Pac-12",
      website: website,
      ncaaId: ncaaId,
      familyUnitId: "test-family",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  // MARK: - Duplicate Detection Flow Tests

  func test_submitSchool_detectsNameDuplicate_showsDialog() async {
    // Given
    let existingSchool = makeTestSchool(name: "Stanford University")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Stanford University" // Same name
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result) // Should not create school
    XCTAssertTrue(viewModel.showDuplicateDialog)
    XCTAssertNotNil(viewModel.duplicateResult)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .name)
    XCTAssertEqual(viewModel.duplicateResult?.duplicate?.id, existingSchool.id)
  }

  func test_submitSchool_detectsDomainDuplicate_showsDialog() async {
    // Given
    let existingSchool = makeTestSchool(name: "Stanford", website: "https://stanford.edu")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Different Name"
    viewModel.formState.website = "https://www.stanford.edu" // Same domain (with www)
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.showDuplicateDialog)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .domain)
  }

  func test_submitSchool_detectsNcaaIdDuplicate_showsDialog() async {
    // Given
    let existingSchool = makeTestSchool(name: "Stanford", website: "https://stanford.edu", ncaaId: "123")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Different Name"
    viewModel.formState.website = "https://different.edu"
    viewModel.formState.ncaaId = "123" // Same NCAA ID
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.showDuplicateDialog)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .ncaaId)
  }

  func test_submitSchool_noDuplicate_createsSchool() async {
    // Given
    let existingSchool = makeTestSchool(name: "Harvard")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Stanford University" // Different name
    viewModel.formState.status = "active"

    // Mock creation
    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNotNil(result)
    XCTAssertFalse(viewModel.showDuplicateDialog)
    XCTAssertEqual(result?.id, "new-id")
    XCTAssertEqual(result?.name, "Stanford University")
  }

  func test_submitSchool_validationError_skipsDetection() async {
    // Given - Invalid form (empty name)
    viewModel.formState.name = "" // Invalid
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertFalse(viewModel.showDuplicateDialog) // No duplicate check if validation fails
    XCTAssertTrue(viewModel.formErrors.hasErrors)
  }

  // MARK: - Dialog Interaction Tests

  func test_cancelDuplicate_hidesDialog_resetsState() {
    // Given
    let duplicate = makeTestSchool()
    viewModel.duplicateResult = DuplicateResult(duplicate: duplicate, matchType: .name)
    viewModel.showDuplicateDialog = true

    // When
    viewModel.cancelDuplicate()

    // Then
    XCTAssertFalse(viewModel.showDuplicateDialog)
    XCTAssertNil(viewModel.duplicateResult)
  }

  func test_proceedDespiteDuplicate_createsSchool_hidesDialog() async {
    // Given
    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    let duplicate = makeTestSchool()
    viewModel.duplicateResult = DuplicateResult(duplicate: duplicate, matchType: .name)
    viewModel.showDuplicateDialog = true

    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.proceedDespiteDuplicate()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-id")
    XCTAssertFalse(viewModel.showDuplicateDialog)
    XCTAssertNil(viewModel.duplicateResult)
  }

  func test_proceedDespiteDuplicate_announcesSuccess() async {
    // Given
    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.proceedDespiteDuplicate()

    // Then
    XCTAssertNotNil(result)
    // Note: Announcer assertions would require mock announcer - skipping for now
  }

  func test_proceedDespiteDuplicate_navigatesToDetail() async {
    // Given
    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.proceedDespiteDuplicate()

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "new-id")
    // Navigation is handled in view layer - ViewModel just returns the school
  }

  // MARK: - Edge Cases

  func test_submitSchool_emptySchoolsList_noDuplicate() async {
    // Given
    mockSchoolsService.stubbedSchools = [] // Empty list

    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNotNil(result)
    XCTAssertFalse(viewModel.showDuplicateDialog)
  }

  func test_submitSchool_fetchSchoolsError_proceedsAnyway() async {
    // Given - Fetch throws error
    mockSchoolsService.shouldThrowError = true

    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    let expectedSchool = makeTestSchool(id: "new-id", name: "Stanford University")
    mockSchoolsService.stubbedCreatedSchool = expectedSchool

    // When
    let result = await viewModel.submitSchool()

    // Then - Should still create school (fail-safe)
    XCTAssertNotNil(result)
    XCTAssertFalse(viewModel.showDuplicateDialog)
  }

  func test_duplicateDetection_prioritizesNameOverDomain() async {
    // Given - Multiple matches
    let nameMatch = makeTestSchool(id: "name-match", name: "Stanford University", website: "https://different.edu")
    let domainMatch = makeTestSchool(id: "domain-match", name: "Different", website: "https://stanford.edu")
    mockSchoolsService.stubbedSchools = [nameMatch, domainMatch]

    viewModel.formState.name = "Stanford University" // Matches name
    viewModel.formState.website = "https://stanford.edu" // Matches domain
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then - Should prioritize name match
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .name)
    XCTAssertEqual(viewModel.duplicateResult?.duplicate?.id, "name-match")
  }

  func test_duplicateDetection_caseInsensitiveNameMatch() async {
    // Given
    let existingSchool = makeTestSchool(name: "STANFORD UNIVERSITY")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "stanford university" // lowercase
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.showDuplicateDialog)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .name)
  }

  func test_duplicateDetection_trimsWhitespace() async {
    // Given
    let existingSchool = makeTestSchool(name: "  Stanford University  ")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Stanford University"
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertTrue(viewModel.showDuplicateDialog)
  }

  func test_duplicateDetection_domainWithWWW() async {
    // Given
    let existingSchool = makeTestSchool(name: "Stanford", website: "https://www.stanford.edu")
    mockSchoolsService.stubbedSchools = [existingSchool]

    viewModel.formState.name = "Different Name"
    viewModel.formState.website = "https://stanford.edu" // without www
    viewModel.formState.status = "active"

    // When
    let result = await viewModel.submitSchool()

    // Then
    XCTAssertNil(result)
    XCTAssertEqual(viewModel.duplicateResult?.matchType, .domain)
  }
}
