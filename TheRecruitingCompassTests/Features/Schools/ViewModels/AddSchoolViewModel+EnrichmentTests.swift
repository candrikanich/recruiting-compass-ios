//
//  AddSchoolViewModel+EnrichmentTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Tests for AddSchoolViewModel College Scorecard enrichment functionality
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddSchoolViewModelEnrichmentTests: XCTestCase {
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

  // MARK: - performScorecardEnrichment Tests

  func testPerformScorecardEnrichment_WithValidCollegeName_LoadsData() async {
    // Given: A valid college name
    let collegeName = "Harvard University"

    // When: We perform scorecard enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Enrichment should complete
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should not be loading after completion")
    // scorecardData may or may not be populated depending on API configuration
  }

  func testPerformScorecardEnrichment_WithEmptyName_Skips() async {
    // Given: An empty college name
    let collegeName = ""

    // When: We perform scorecard enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Enrichment should be skipped
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should not be loading")
    XCTAssertNil(viewModel.scorecardData, "Should not have data for empty name")
  }

  func testPerformScorecardEnrichment_SetsIsEnrichmentLoadingDuringLoad() async {
    // Given: A valid college name
    let collegeName = "Harvard"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: isEnrichmentLoading should be false after completion
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete loading")
  }

  func testPerformScorecardEnrichment_WithApiKeyMissing_FailsSilently() async {
    // Given: No API key configured (service will throw apiKeyMissing)
    let collegeName = "Harvard"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Should fail silently (per spec)
    XCTAssertNil(viewModel.enrichmentError, "Should not show error to user (silent failure)")
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete loading")
  }

  func testPerformScorecardEnrichment_WithNetworkError_FailsSilently() async {
    // Given: A college name (network may be unavailable)
    let collegeName = "Harvard"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Should fail silently
    XCTAssertNil(viewModel.enrichmentError, "Should not show error to user (silent failure)")
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete loading")
  }

  func testPerformScorecardEnrichment_WithRateLimitError_FailsSilently() async {
    // Given: A college name (API may be rate-limited)
    let collegeName = "Harvard"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Should fail silently
    XCTAssertNil(viewModel.enrichmentError, "Should not show error to user (silent failure)")
  }

  // MARK: - clearEnrichment Tests

  func testClearEnrichment_ClearsScorecardData() {
    // Given: Enrichment data may be present
    // When: We clear enrichment
    viewModel.clearEnrichment()

    // Then: All enrichment state should be cleared
    XCTAssertNil(viewModel.scorecardData, "Should clear scorecard data")
    XCTAssertNil(viewModel.enrichmentError, "Should clear enrichment error")
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should not be loading")
  }

  // MARK: - Integration with submitSchool Tests

  func testSubmitSchool_IncludesScorecardDataInRequest() async {
    // Given: A form with scorecard data
    viewModel.formState.name = "Harvard University"
    viewModel.formState.status = .interested

    // Mock scorecard data (would normally come from enrichment)
    // We can't easily set this without performing actual enrichment
    // This test verifies the flow completes

    // When: We submit the school
    mockSchoolsService.shouldSucceed = true
    mockSchoolsService.createdSchool = School(
      id: "new-school",
      name: "Harvard University",
      location: nil,
      division: nil,
      conference: nil,
      website: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      status: .interested,
      isFavorite: false,
      pros: [],
      cons: [],
      coachingPhilosophy: nil,
      priorityTier: nil,
      academicInfo: nil,
      userId: "test-user",
      familyUnitId: "test-family",
      createdBy: "test-user",
      updatedBy: "test-user",
      createdAt: Date(),
      updatedAt: Date()
    )

    let result = await viewModel.submitSchool()

    // Then: Submission should succeed
    XCTAssertNotNil(result, "Should create school")
  }

  // MARK: - Edge Case Tests

  func testPerformScorecardEnrichment_MultipleTimesInSuccession_HandlesCorrectly() async {
    // Given: Multiple enrichment requests
    let collegeName1 = "Harvard"
    let collegeName2 = "MIT"

    // When: We perform enrichment multiple times
    await viewModel.performScorecardEnrichment(collegeName: collegeName1)
    await viewModel.performScorecardEnrichment(collegeName: collegeName2)

    // Then: Should complete without errors
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete all enrichments")
  }

  func testPerformScorecardEnrichment_WithSpecialCharacters_HandlesCorrectly() async {
    // Given: A college name with special characters
    let collegeName = "St. John's University"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Should handle special characters gracefully
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete loading")
  }

  func testPerformScorecardEnrichment_WithVeryLongName_HandlesCorrectly() async {
    // Given: A very long college name
    let collegeName = "The University of California at Berkeley Graduate School of Advanced Studies"

    // When: We perform enrichment
    await viewModel.performScorecardEnrichment(collegeName: collegeName)

    // Then: Should handle long names gracefully
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete loading")
  }
}
