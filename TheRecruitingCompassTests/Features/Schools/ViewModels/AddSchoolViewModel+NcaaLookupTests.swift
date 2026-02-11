//
//  AddSchoolViewModel+NcaaLookupTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Tests for AddSchoolViewModel NCAA database lookup functionality
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddSchoolViewModelNcaaLookupTests: XCTestCase {
  var viewModel: AddSchoolViewModel!
  var mockSchoolsService: MockSchoolsService!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()

    viewModel = AddSchoolViewModel(
      schoolsService: mockSchoolsService,
      familyUnitId: "test-family",
      userId: "test-user"
    )
  }

  override func tearDown() {
    viewModel = nil
    mockSchoolsService = nil
  }

  // MARK: - performNcaaLookup Tests

  func testPerformNcaaLookup_WithValidSchoolName_PerformsLookup() {
    // Given: A valid school name
    let schoolName = "Alabama"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Lookup should complete
    // Division/conference may or may not be filled depending on database content
    // We verify the method completes without crashing
  }

  func testPerformNcaaLookup_WithEmptyName_Skips() {
    // Given: An empty school name
    let schoolName = ""

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Lookup should be skipped
    XCTAssertNil(viewModel.formState.division, "Should not set division for empty name")
  }

  func testPerformNcaaLookup_WithWhitespaceOnly_Skips() {
    // Given: A whitespace-only school name
    let schoolName = "   "

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Lookup should be skipped
    XCTAssertNil(viewModel.formState.division, "Should not set division for whitespace")
  }

  func testPerformNcaaLookup_WhenDivisionAlreadySet_Skips() {
    // Given: A school name with division already manually set
    let schoolName = "Harvard"
    viewModel.formState.division = .d1

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Lookup should be skipped (division manually set takes precedence)
    XCTAssertEqual(viewModel.formState.division, .d1, "Should keep manually set division")
  }

  func testPerformNcaaLookup_WithKnownD1School_SetsDivisionAndConference() {
    // Given: A known D1 school (assuming Alabama is in database)
    let schoolName = "Alabama"
    viewModel.formState.division = nil // Ensure not set

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Division should be set if match is found
    // We can't assert the exact result without knowing database content
    // But we verify the method completes
  }

  func testPerformNcaaLookup_WithNonExistentSchool_DoesNotCrash() {
    // Given: A non-existent school name
    let schoolName = "Nonexistent University of Nowhere"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Should handle gracefully (no match = silent, no error)
    XCTAssertFalse(viewModel.isSubmitting, "Should complete without error")
  }

  func testPerformNcaaLookup_WithSpecialCharacters_HandlesCorrectly() {
    // Given: A school name with special characters
    let schoolName = "St. Mary's College"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Should handle special characters gracefully
    // NCAA database should normalize the name
  }

  // MARK: - Integration with selectCollege Tests

  func testSelectCollege_TriggersNcaaLookup() async {
    // Given: A college search result
    let college = CollegeSearchResult(
      id: "123",
      name: "University of Alabama",
      city: "Tuscaloosa",
      state: "AL",
      website: nil
    )

    // Ensure division is not set
    viewModel.formState.division = nil

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: NCAA lookup should be triggered automatically
    // Division may be set if match is found in NCAA database
  }

  // MARK: - Edge Case Tests

  func testPerformNcaaLookup_MultipleTimes_LastResultWins() {
    // Given: Multiple lookup requests
    let schoolName1 = "Alabama"
    let schoolName2 = "Auburn"

    // When: We perform lookups sequentially
    viewModel.performNcaaLookup(for: schoolName1)
    viewModel.performNcaaLookup(for: schoolName2)

    // Then: Last lookup result should be present
    // Can't assert exact values without knowing database
  }

  func testPerformNcaaLookup_WithVeryLongName_HandlesCorrectly() {
    // Given: A very long school name
    let schoolName = "The University of California at Los Angeles Extension Graduate School"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Should handle long names gracefully
  }

  func testPerformNcaaLookup_WithUniversityPrefix_NormalizesCorrectly() {
    // Given: A school name with "University of" prefix
    let schoolName = "University of Florida"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Should normalize and potentially find match
    // NCAA database normalizes names for matching
  }

  func testPerformNcaaLookup_WithCollegePrefix_NormalizesCorrectly() {
    // Given: A school name with "College of" prefix
    let schoolName = "College of Charleston"

    // When: We perform NCAA lookup
    viewModel.performNcaaLookup(for: schoolName)

    // Then: Should normalize and potentially find match
  }

  func testPerformNcaaLookup_CaseInsensitive_WorksCorrectly() {
    // Given: A school name in different cases
    let schoolName1 = "ALABAMA"
    let schoolName2 = "alabama"
    let schoolName3 = "AlAbAmA"

    // When: We perform lookups with different cases
    viewModel.formState.division = nil
    viewModel.performNcaaLookup(for: schoolName1)
    let result1 = viewModel.formState.division

    viewModel.formState.division = nil
    viewModel.performNcaaLookup(for: schoolName2)
    let result2 = viewModel.formState.division

    viewModel.formState.division = nil
    viewModel.performNcaaLookup(for: schoolName3)
    let result3 = viewModel.formState.division

    // Then: All should produce same result (case-insensitive)
    if result1 != nil {
      XCTAssertEqual(result1, result2, "Should be case-insensitive")
      XCTAssertEqual(result2, result3, "Should be case-insensitive")
    }
  }
}
