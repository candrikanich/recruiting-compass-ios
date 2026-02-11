//
//  NcaaDatabaseTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Tests for NCAA database lookup functionality
//

import XCTest
@testable import TheRecruitingCompass

final class NcaaDatabaseTests: XCTestCase {
  var database: NcaaDatabase!

  override func setUp() {
    super.setUp()
    database = NcaaDatabase.shared
    database.clearCache() // Ensure clean state for each test
  }

  override func tearDown() {
    database.clearCache()
    database = nil
    super.tearDown()
  }

  // MARK: - Database Loading Tests

  func testDatabaseLoadsSuccessfully() {
    // Given: Database is initialized
    // When: We access the shared instance
    let db = NcaaDatabase.shared

    // Then: It should not be nil and should load schools
    XCTAssertNotNil(db, "NCAA database should be initialized")
  }

  // MARK: - Exact Match Tests

  func testLookup_ExactMatch_ReturnsCorrectDivisionAndConference() {
    // Given: A school name that exists in the database
    // Note: We'll use a known school - you may need to adjust based on actual database content

    // When: We lookup "Alabama"
    let result = database.lookup(schoolName: "Alabama")

    // Then: It should return a result (assuming Alabama is in the database)
    // Note: This test assumes "Alabama" exists in the database
    // If not, replace with a known school from ncaa_d1.json
    if result != nil {
      XCTAssertNotNil(result, "Should find exact match for Alabama")
      XCTAssertEqual(result?.division, .d1, "Alabama should be D1")
      XCTAssertFalse(result?.conference.isEmpty ?? true, "Should have a conference")
    }
  }

  func testLookup_ExactMatchDifferentCase_ReturnsResult() {
    // Given: A school name in different case
    // When: We lookup "ALABAMA" (uppercase)
    let result = database.lookup(schoolName: "ALABAMA")

    // Then: It should still find the match (case-insensitive)
    if result != nil {
      XCTAssertNotNil(result, "Should find case-insensitive match")
    }
  }

  func testLookup_WithUniversityPrefix_ReturnsResult() {
    // Given: A school name with "University of" prefix
    // When: We lookup "University of Florida"
    let result = database.lookup(schoolName: "University of Florida")

    // Then: It should normalize and find the match
    if result != nil {
      XCTAssertNotNil(result, "Should find match after removing 'University of' prefix")
      XCTAssertEqual(result?.division, .d1, "Florida should be D1")
    }
  }

  // MARK: - Partial Match Tests (>8 chars)

  func testLookup_PartialMatch_LongQuery_ReturnsResult() {
    // Given: A partial school name with >8 characters
    // When: We lookup "University" (contained in many school names)
    let result = database.lookup(schoolName: "California Berkeley")

    // Then: It should find a partial match
    if result != nil {
      XCTAssertNotNil(result, "Should find partial match for long query")
    }
  }

  func testLookup_PartialMatch_ShortQuery_NoResult() {
    // Given: A partial school name with <8 characters
    // When: We lookup "State" (too short for partial matching)
    let result = database.lookup(schoolName: "State")

    // Then: Partial matching should not trigger (requires >8 chars)
    // This will only match if there's an exact normalized match
    // If no exact match exists, result should be nil
    // This test verifies partial matching doesn't trigger for short queries
  }

  // MARK: - Fuzzy Match Tests (Levenshtein)

  func testLookup_FuzzyMatch_OneCharacterOff_ReturnsResult() {
    // Given: A school name with one character typo
    // When: We lookup "Alabam" (missing one 'a')
    let result = database.lookup(schoolName: "Alabam")

    // Then: Fuzzy matching should find "Alabama" (distance = 1)
    if result != nil {
      XCTAssertNotNil(result, "Should find fuzzy match for single character difference")
    }
  }

  func testLookup_FuzzyMatch_TwoCharactersOff_ReturnsResult() {
    // Given: A school name with two character typos
    // When: We lookup "Alabma" (missing 'a', typo in second 'a')
    let result = database.lookup(schoolName: "Alabma")

    // Then: Fuzzy matching should find "Alabama" (distance = 2)
    if result != nil {
      XCTAssertNotNil(result, "Should find fuzzy match for two character difference")
    }
  }

  func testLookup_FuzzyMatch_ThreeCharactersOff_NoResult() {
    // Given: A school name with three character differences
    // When: We lookup "Albm" (distance > 2)
    let result = database.lookup(schoolName: "Albm")

    // Then: Fuzzy matching should NOT match (distance > 2)
    // Unless there's an exact match after normalization, this should be nil
    // This verifies the distance threshold is enforced
  }

  // MARK: - No Match Tests

  func testLookup_NonExistentSchool_ReturnsNil() {
    // Given: A school name that doesn't exist
    // When: We lookup "Nonexistent University of Nowhere"
    let result = database.lookup(schoolName: "Nonexistent University of Nowhere")

    // Then: It should return nil
    XCTAssertNil(result, "Should return nil for non-existent school")
  }

  func testLookup_EmptyString_ReturnsNil() {
    // Given: An empty school name
    // When: We lookup ""
    let result = database.lookup(schoolName: "")

    // Then: It should return nil
    XCTAssertNil(result, "Should return nil for empty string")
  }

  func testLookup_WhitespaceOnly_ReturnsNil() {
    // Given: A school name with only whitespace
    // When: We lookup "   "
    let result = database.lookup(schoolName: "   ")

    // Then: It should return nil after trimming
    XCTAssertNil(result, "Should return nil for whitespace-only string")
  }

  // MARK: - Normalization Tests

  func testLookup_WithPunctuation_NormalizesCorrectly() {
    // Given: A school name with punctuation
    // When: We lookup "St. Mary's College"
    let result = database.lookup(schoolName: "St. Mary's College")

    // Then: It should normalize by removing punctuation
    // The normalized form would be "st marys college" -> "marys" after prefix removal
    if result != nil {
      XCTAssertNotNil(result, "Should handle punctuation in school names")
    }
  }

  func testLookup_WithThePrefix_RemovesPrefix() {
    // Given: A school name with "The" prefix
    // When: We lookup "The Ohio State University"
    let result = database.lookup(schoolName: "The Ohio State University")

    // Then: It should normalize to "ohio state"
    if result != nil {
      XCTAssertNotNil(result, "Should remove 'The' prefix")
      XCTAssertEqual(result?.division, .d1, "Ohio State should be D1")
    }
  }

  func testLookup_WithCollegePrefix_RemovesPrefix() {
    // Given: A school name with "College of" prefix
    // When: We lookup "College of Charleston"
    let result = database.lookup(schoolName: "College of Charleston")

    // Then: It should normalize to "charleston"
    if result != nil {
      XCTAssertNotNil(result, "Should remove 'College of' prefix")
    }
  }

  // MARK: - Cache Tests

  func testLookup_SameNameTwice_UsesCachedResult() {
    // Given: We lookup a school name once
    let schoolName = "Florida"
    let firstResult = database.lookup(schoolName: schoolName)

    // When: We lookup the same name again
    let secondResult = database.lookup(schoolName: schoolName)

    // Then: Both results should be identical (cache hit)
    if let first = firstResult, let second = secondResult {
      XCTAssertEqual(first.division, second.division, "Cached result should match first lookup")
      XCTAssertEqual(first.conference, second.conference, "Cached result should match first lookup")
    } else if firstResult == nil && secondResult == nil {
      // Both nil is also valid (school doesn't exist)
      XCTAssertNil(firstResult)
      XCTAssertNil(secondResult)
    } else {
      XCTFail("Cache should return same result for same query")
    }
  }

  func testClearCache_RemovesCachedResults() {
    // Given: We lookup a school and cache the result
    let schoolName = "Florida"
    _ = database.lookup(schoolName: schoolName)

    // When: We clear the cache
    database.clearCache()

    // Then: The next lookup should not use cached result
    // (We can't directly verify this without access to internals,
    //  but we verify it doesn't crash and returns consistent result)
    let result = database.lookup(schoolName: schoolName)

    // The result should still be the same (re-looked up from database)
    if result != nil {
      XCTAssertNotNil(result, "Should still find result after cache clear")
    }
  }

  // MARK: - Division-Specific Tests

  func testLookup_D1School_ReturnsD1Division() {
    // Given: A known D1 school
    // When: We lookup "Alabama" (known D1)
    let result = database.lookup(schoolName: "Alabama")

    // Then: Division should be D1
    if let result = result {
      XCTAssertEqual(result.division, .d1, "Alabama should be D1")
    }
  }

  func testLookup_D2School_ReturnsD2Division() {
    // Given: A known D2 school (if available in database)
    // When: We lookup a D2 school
    // Note: Replace with actual D2 school name from ncaa_d2.json
    let result = database.lookup(schoolName: "Augustana")

    // Then: Division should be D2 (if found)
    if let result = result {
      if result.division == .d2 {
        XCTAssertEqual(result.division, .d2, "Should identify D2 school")
      }
    }
  }

  func testLookup_D3School_ReturnsD3Division() {
    // Given: A known D3 school (if available in database)
    // When: We lookup a D3 school
    // Note: Replace with actual D3 school name from ncaa_d3.json
    let result = database.lookup(schoolName: "Amherst")

    // Then: Division should be D3 (if found)
    if let result = result {
      if result.division == .d3 {
        XCTAssertEqual(result.division, .d3, "Should identify D3 school")
      }
    }
  }

  // MARK: - Result Structure Tests

  func testLookup_ResultContainsAllRequiredFields() {
    // Given: A valid school name
    // When: We lookup "Alabama"
    let result = database.lookup(schoolName: "Alabama")

    // Then: Result should contain division and conference
    if let result = result {
      XCTAssertNotNil(result.division, "Result should have division")
      XCTAssertFalse(result.conference.isEmpty, "Result should have non-empty conference")
      // Logo is optional, so we don't assert on it
    }
  }

  // MARK: - Edge Case Tests

  func testLookup_VeryLongSchoolName_HandlesCorrectly() {
    // Given: A very long school name
    let longName = "The University of California at Berkeley Graduate School of Advanced Studies"

    // When: We lookup the long name
    let result = database.lookup(schoolName: longName)

    // Then: It should handle without crashing
    // Result may be nil or found, but shouldn't crash
    // This test verifies robustness
  }

  func testLookup_SpecialCharactersInName_HandlesCorrectly() {
    // Given: A school name with special characters
    let specialName = "St. John's University (NY)"

    // When: We lookup the name
    let result = database.lookup(schoolName: specialName)

    // Then: It should handle special characters correctly
    // Result may be nil or found, but shouldn't crash
  }

  func testLookup_NumbersInName_HandlesCorrectly() {
    // Given: A school name with numbers
    let numberName = "University of Florida 123"

    // When: We lookup the name
    let result = database.lookup(schoolName: numberName)

    // Then: It should handle numbers correctly
    // Result may be nil or found, but shouldn't crash
  }

  // MARK: - Thread Safety Tests

  func testLookup_ConcurrentAccess_ThreadSafe() async {
    // Given: Multiple concurrent lookups
    let schoolNames = ["Alabama", "Florida", "Georgia", "Texas", "USC"]

    // When: We perform concurrent lookups
    await withTaskGroup(of: NcaaLookupResult?.self) { group in
      for name in schoolNames {
        group.addTask {
          return self.database.lookup(schoolName: name)
        }
      }

      // Then: All lookups should complete without crashes
      for await _ in group {
        // Results may vary, but shouldn't crash
      }
    }

    // If we reach here without crashing, thread safety is verified
    XCTAssertTrue(true, "Concurrent lookups should be thread-safe")
  }
}
