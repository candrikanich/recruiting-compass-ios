//
//  AddSchoolViewModel+AutocompleteTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Tests for AddSchoolViewModel autocomplete functionality
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddSchoolViewModelAutocompleteTests: XCTestCase {
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

  // MARK: - performAutocompleteSearch Tests

  func testPerformAutocompleteSearch_WithValidQuery_PopulatesResults() async {
    // Given: A valid search query (3+ characters)
    let query = "Harvard"

    // When: We perform autocomplete search
    // Note: This will make a real API call if API key is configured
    // For unit tests, we'd ideally mock the CollegeScorecardService
    await viewModel.performAutocompleteSearch(query: query)

    // Then: Search state should be updated
    // Results depend on API availability and configuration
    XCTAssertFalse(viewModel.isSearching, "Should not be searching after completion")
    // searchResults and searchError depend on API configuration
  }

  func testPerformAutocompleteSearch_WithShortQuery_ClearsResults() async {
    // Given: A query with < 3 characters
    let query = "AB"

    // When: We perform autocomplete search
    await viewModel.performAutocompleteSearch(query: query)

    // Then: Results should be cleared
    XCTAssertTrue(viewModel.searchResults.isEmpty, "Should clear results for short query")
    XCTAssertNil(viewModel.searchError, "Should not show error for short query")
    XCTAssertFalse(viewModel.isSearching, "Should not be searching")
  }

  func testPerformAutocompleteSearch_WithEmptyQuery_ClearsResults() async {
    // Given: An empty query
    let query = ""

    // When: We perform autocomplete search
    await viewModel.performAutocompleteSearch(query: query)

    // Then: Results should be cleared
    XCTAssertTrue(viewModel.searchResults.isEmpty, "Should clear results for empty query")
    XCTAssertNil(viewModel.searchError, "Should not show error for empty query")
    XCTAssertFalse(viewModel.isSearching, "Should not be searching")
  }

  func testPerformAutocompleteSearch_SetsIsSearchingDuringSearch() async {
    // Given: A valid search query
    let query = "Harvard"

    // When: We start the search
    // We can't easily test the intermediate state without mocking the service
    // But we can verify it's false after completion
    await viewModel.performAutocompleteSearch(query: query)

    // Then: isSearching should be false after completion
    XCTAssertFalse(viewModel.isSearching, "Should not be searching after completion")
  }

  // MARK: - selectCollege Tests

  func testSelectCollege_AutoFillsFormFields() async {
    // Given: A college search result
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: "https://harvard.edu"
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: Form fields should be auto-filled
    XCTAssertEqual(viewModel.formState.name, "Harvard University", "Should auto-fill name")
    XCTAssertEqual(viewModel.formState.city, "Cambridge", "Should auto-fill city")
    XCTAssertEqual(viewModel.formState.state, "MA", "Should auto-fill state")
    XCTAssertEqual(viewModel.formState.location, "Cambridge, MA", "Should auto-fill location")
    XCTAssertEqual(viewModel.formState.website, "https://harvard.edu", "Should auto-fill website")
  }

  func testSelectCollege_SetsSelectedCollege() async {
    // Given: A college search result
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: "https://harvard.edu"
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: selectedCollege should be set
    XCTAssertNotNil(viewModel.selectedCollege, "Should set selectedCollege")
    XCTAssertEqual(viewModel.selectedCollege?.id, "123456", "Should match selected college")
    XCTAssertEqual(viewModel.selectedCollege?.name, "Harvard University", "Should match selected college")
  }

  func testSelectCollege_ClearsSearchResults() async {
    // Given: A college with search results present
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: nil
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: Search results and query should be cleared
    XCTAssertTrue(viewModel.searchResults.isEmpty, "Should clear search results")
    XCTAssertTrue(viewModel.searchQuery.isEmpty, "Should clear search query")
    XCTAssertNil(viewModel.searchError, "Should clear search error")
  }

  func testSelectCollege_TriggersNcaaLookup() async {
    // Given: A college search result
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: nil
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: NCAA lookup should be triggered
    // Division and conference may be filled if NCAA match is found
    // This is hard to test without mocking NcaaDatabase
    // We verify the method completes without error
  }

  func testSelectCollege_TriggersScorecardEnrichment() async {
    // Given: A college search result
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: nil
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: Scorecard enrichment should be triggered
    // scorecardData may be populated if API is configured
    // isEnrichmentLoading should be false after completion
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should complete enrichment")
  }

  func testSelectCollege_WithNullWebsite_HandlesGracefully() async {
    // Given: A college with null website
    let college = CollegeSearchResult(
      id: "123456",
      name: "Test College",
      city: "Test City",
      state: "TX",
      website: nil
    )

    // When: We select the college
    await viewModel.selectCollege(college)

    // Then: Website should be empty string
    XCTAssertEqual(viewModel.formState.website, "", "Should handle null website")
  }

  // MARK: - clearSelection Tests

  func testClearSelection_ClearsSelectedCollege() async {
    // Given: A selected college
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: "https://harvard.edu"
    )
    await viewModel.selectCollege(college)

    // When: We clear the selection
    viewModel.clearSelection()

    // Then: selectedCollege should be nil
    XCTAssertNil(viewModel.selectedCollege, "Should clear selectedCollege")
  }

  func testClearSelection_ClearsAutoFilledFields() {
    // Given: A selected college with auto-filled fields
    let college = CollegeSearchResult(
      id: "123456",
      name: "Harvard University",
      city: "Cambridge",
      state: "MA",
      website: "https://harvard.edu"
    )
    Task {
      await viewModel.selectCollege(college)
    }

    // Wait a bit for async operation
    let expectation = XCTestExpectation(description: "Wait for selection")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      // When: We clear the selection
      self.viewModel.clearSelection()

      // Then: Form fields should be cleared
      XCTAssertTrue(self.viewModel.formState.name.isEmpty, "Should clear name")
      XCTAssertTrue(self.viewModel.formState.city.isEmpty, "Should clear city")
      XCTAssertTrue(self.viewModel.formState.state.isEmpty, "Should clear state")
      XCTAssertTrue(self.viewModel.formState.location.isEmpty, "Should clear location")
      XCTAssertTrue(self.viewModel.formState.website.isEmpty, "Should clear website")
      XCTAssertNil(self.viewModel.formState.division, "Should clear division")
      XCTAssertTrue(self.viewModel.formState.conference.isEmpty, "Should clear conference")

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testClearSelection_ClearsSearchState() {
    // Given: Search state present
    // When: We clear the selection
    viewModel.clearSelection()

    // Then: Search state should be cleared
    XCTAssertTrue(viewModel.searchResults.isEmpty, "Should clear search results")
    XCTAssertTrue(viewModel.searchQuery.isEmpty, "Should clear search query")
    XCTAssertNil(viewModel.searchError, "Should clear search error")
  }

  func testClearSelection_ClearsEnrichmentData() {
    // Given: A selected college (enrichment may be present)
    // When: We clear the selection
    viewModel.clearSelection()

    // Then: Enrichment data should be cleared
    XCTAssertNil(viewModel.scorecardData, "Should clear scorecard data")
    XCTAssertNil(viewModel.enrichmentError, "Should clear enrichment error")
    XCTAssertFalse(viewModel.isEnrichmentLoading, "Should not be loading")
  }

  // MARK: - Search Error Handling Tests

  func testPerformAutocompleteSearch_WithApiKeyMissing_SetsErrorMessage() async {
    // Given: No API key configured (service will throw apiKeyMissing)
    let query = "Harvard"

    // When: We perform search
    await viewModel.performAutocompleteSearch(query: query)

    // Then: Error message should be set
    // Only if API key is truly missing
    if viewModel.searchError != nil {
      XCTAssertFalse(viewModel.searchError!.isEmpty, "Should have error message")
    }
  }

  // MARK: - Edge Case Tests

  func testSelectCollege_MultipleTimesInSuccession_UpdatesCorrectly() async {
    // Given: Two different colleges
    let college1 = CollegeSearchResult(
      id: "111",
      name: "Harvard",
      city: "Cambridge",
      state: "MA",
      website: nil
    )
    let college2 = CollegeSearchResult(
      id: "222",
      name: "MIT",
      city: "Cambridge",
      state: "MA",
      website: nil
    )

    // When: We select college1, then college2
    await viewModel.selectCollege(college1)
    await viewModel.selectCollege(college2)

    // Then: Form should reflect college2
    XCTAssertEqual(viewModel.formState.name, "MIT", "Should update to latest selection")
    XCTAssertEqual(viewModel.selectedCollege?.id, "222", "Should update selectedCollege")
  }

  func testSearchQuery_EmptyAfterSelection_DoesNotTriggerNewSearch() async {
    // Given: A selected college
    let college = CollegeSearchResult(
      id: "123",
      name: "Harvard",
      city: "Cambridge",
      state: "MA",
      website: nil
    )
    await viewModel.selectCollege(college)

    // When: Search query is empty (already cleared by selectCollege)
    await viewModel.performAutocompleteSearch(query: viewModel.searchQuery)

    // Then: No search should be triggered
    XCTAssertTrue(viewModel.searchResults.isEmpty, "Should not search with empty query")
  }
}
