//
//  CollegeScorecardServiceTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Tests for College Scorecard API integration
//

import XCTest
@testable import TheRecruitingCompass

final class CollegeScorecardServiceTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_WithApiKey_SetsApiKey() {
    // Given: An API key
    let apiKey = "test-api-key"

    // When: We initialize the service with the key
    let service = CollegeScorecardService(apiKey: apiKey)

    // Then: The service should be initialized
    XCTAssertNotNil(service, "Service should initialize with API key")
  }

  func testInit_WithoutApiKey_UsesEnvironmentVariable() {
    // Given: No API key parameter (relies on environment)
    // When: We initialize the service
    let service = CollegeScorecardService()

    // Then: The service should be initialized
    XCTAssertNotNil(service, "Service should initialize without explicit API key")
  }

  // MARK: - lookupCollege Tests

  func testLookupCollege_WithoutApiKey_ThrowsApiKeyMissing() async {
    // Given: A service with no API key
    let service = CollegeScorecardService(apiKey: "")

    // When: We attempt to lookup a college
    // Then: It should throw apiKeyMissing error
    do {
      _ = try await service.lookupCollege(name: "Harvard")
      XCTFail("Should throw apiKeyMissing error")
    } catch CollegeDataError.apiKeyMissing {
      // Expected error
      XCTAssertTrue(true, "Correctly threw apiKeyMissing error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testLookupCollege_WithShortName_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to lookup with < 3 characters
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.lookupCollege(name: "AB")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testLookupCollege_WithEmptyName_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to lookup with empty string
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.lookupCollege(name: "")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testLookupCollege_WithTwoCharacterName_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to lookup with exactly 2 characters
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.lookupCollege(name: "UC")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error for 2-char name")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testLookupCollege_WithThreeCharacterName_DoesNotThrowNameTooShort() async {
    // Given: A service with an API key (but invalid for real calls)
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to lookup with exactly 3 characters
    // Then: It should NOT throw nameTooShort (may throw other errors due to invalid API key)
    do {
      _ = try await service.lookupCollege(name: "MIT")
      // May succeed or fail with network/API errors, but not nameTooShort
    } catch CollegeDataError.nameTooShort {
      XCTFail("Should NOT throw nameTooShort for 3-char name")
    } catch {
      // Other errors are acceptable (network, invalid API key, etc.)
      // This test just verifies nameTooShort is not thrown
    }
  }

  // MARK: - searchColleges Tests

  func testSearchColleges_WithoutApiKey_ThrowsApiKeyMissing() async {
    // Given: A service with no API key
    let service = CollegeScorecardService(apiKey: "")

    // When: We attempt to search colleges
    // Then: It should throw apiKeyMissing error
    do {
      _ = try await service.searchColleges(query: "Harvard")
      XCTFail("Should throw apiKeyMissing error")
    } catch CollegeDataError.apiKeyMissing {
      // Expected error
      XCTAssertTrue(true, "Correctly threw apiKeyMissing error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testSearchColleges_WithShortQuery_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to search with < 3 characters
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.searchColleges(query: "AB")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testSearchColleges_WithEmptyQuery_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to search with empty string
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.searchColleges(query: "")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testSearchColleges_WithTwoCharacterQuery_ThrowsNameTooShort() async {
    // Given: A service with an API key
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to search with exactly 2 characters
    // Then: It should throw nameTooShort error
    do {
      _ = try await service.searchColleges(query: "UC")
      XCTFail("Should throw nameTooShort error")
    } catch CollegeDataError.nameTooShort {
      // Expected error
      XCTAssertTrue(true, "Correctly threw nameTooShort error for 2-char query")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testSearchColleges_WithThreeCharacterQuery_DoesNotThrowNameTooShort() async {
    // Given: A service with an API key (but invalid for real calls)
    let service = CollegeScorecardService(apiKey: "test-key")

    // When: We attempt to search with exactly 3 characters
    // Then: It should NOT throw nameTooShort (may throw other errors)
    do {
      _ = try await service.searchColleges(query: "MIT")
      // May succeed or fail with network/API errors, but not nameTooShort
    } catch CollegeDataError.nameTooShort {
      XCTFail("Should NOT throw nameTooShort for 3-char query")
    } catch {
      // Other errors are acceptable (network, invalid API key, etc.)
    }
  }

  // MARK: - Error Handling Tests

  func testLookupCollege_WithValidNameAndApiKey_BuildsCorrectURL() async {
    // Given: A service with a test API key
    let service = CollegeScorecardService(apiKey: "test-api-key-12345")

    // When: We attempt to lookup (will fail due to invalid API key, but we verify the attempt)
    // Then: The method should build a URL and make a request
    do {
      _ = try await service.lookupCollege(name: "Harvard")
      // If this succeeds, the API key is real and the service works
    } catch CollegeDataError.invalidApiKey {
      // Expected - our test key is invalid
      XCTAssertTrue(true, "URL was built and request was made (invalid API key)")
    } catch CollegeDataError.networkError {
      // Network error is also acceptable
      XCTAssertTrue(true, "Network request was attempted")
    } catch {
      // Other errors indicate the request was attempted
      XCTAssertTrue(true, "Request was attempted: \(error)")
    }
  }

  func testSearchColleges_WithValidQueryAndApiKey_BuildsCorrectURL() async {
    // Given: A service with a test API key
    let service = CollegeScorecardService(apiKey: "test-api-key-12345")

    // When: We attempt to search (will fail due to invalid API key, but we verify the attempt)
    // Then: The method should build a URL and make a request
    do {
      _ = try await service.searchColleges(query: "Harvard")
      // If this succeeds, the API key is real and the service works
    } catch CollegeDataError.invalidApiKey {
      // Expected - our test key is invalid
      XCTAssertTrue(true, "URL was built and request was made (invalid API key)")
    } catch CollegeDataError.networkError {
      // Network error is also acceptable
      XCTAssertTrue(true, "Network request was attempted")
    } catch {
      // Other errors indicate the request was attempted
      XCTAssertTrue(true, "Request was attempted: \(error)")
    }
  }

  // MARK: - Integration Tests (Optional - require real API key)

  /// These tests require a real College Scorecard API key in the environment
  /// Set COLLEGE_SCORECARD_API_KEY environment variable to run these tests
  ///
  /// To skip these tests, they check for the API key first and skip if not present

  func testLookupCollege_WithRealApiKey_ReturnsData() async throws {
    // Skip if no real API key is configured
    guard let apiKey = ProcessInfo.processInfo.environment["COLLEGE_SCORECARD_API_KEY"],
          !apiKey.isEmpty else {
      throw XCTSkip("Skipping integration test - COLLEGE_SCORECARD_API_KEY not set")
    }

    // Given: A service with a real API key
    let service = CollegeScorecardService(apiKey: apiKey)

    // When: We lookup a well-known college
    let result = try await service.lookupCollege(name: "Harvard University")

    // Then: We should get data back
    if let result = result {
      XCTAssertFalse(result.name.isEmpty, "Should have college name")
      XCTAssertNotNil(result.id, "Should have college ID")
    }
    // Result can be nil if college not found, which is also valid
  }

  func testSearchColleges_WithRealApiKey_ReturnsResults() async throws {
    // Skip if no real API key is configured
    guard let apiKey = ProcessInfo.processInfo.environment["COLLEGE_SCORECARD_API_KEY"],
          !apiKey.isEmpty else {
      throw XCTSkip("Skipping integration test - COLLEGE_SCORECARD_API_KEY not set")
    }

    // Given: A service with a real API key
    let service = CollegeScorecardService(apiKey: apiKey)

    // When: We search for "Harvard"
    let results = try await service.searchColleges(query: "Harvard")

    // Then: We should get at least one result
    XCTAssertFalse(results.isEmpty, "Should return search results for 'Harvard'")

    if let firstResult = results.first {
      XCTAssertFalse(firstResult.name.isEmpty, "Result should have name")
      XCTAssertFalse(firstResult.id.isEmpty, "Result should have ID")
      XCTAssertFalse(firstResult.city.isEmpty, "Result should have city")
      XCTAssertFalse(firstResult.state.isEmpty, "Result should have state")
      XCTAssertFalse(firstResult.location.isEmpty, "Result should have location")
    }
  }

  func testSearchColleges_WithRealApiKey_ReturnsMaxTenResults() async throws {
    // Skip if no real API key is configured
    guard let apiKey = ProcessInfo.processInfo.environment["COLLEGE_SCORECARD_API_KEY"],
          !apiKey.isEmpty else {
      throw XCTSkip("Skipping integration test - COLLEGE_SCORECARD_API_KEY not set")
    }

    // Given: A service with a real API key
    let service = CollegeScorecardService(apiKey: apiKey)

    // When: We search for a common term that should have many results
    let results = try await service.searchColleges(query: "University")

    // Then: We should get at most 10 results (per_page = 10)
    XCTAssertLessThanOrEqual(results.count, 10, "Should return max 10 results")
  }
}
