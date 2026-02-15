import Foundation
@testable import TheRecruitingCompass

@MainActor
final class MockCollegeScorecardService: CollegeScorecardManaging {
  // MARK: - Stubbed Results

  var stubbedResult: CollegeDataResult? // Backward compatibility
  var stubbedSearchResults: [CollegeSearchResult] = []
  var shouldThrowError = false
  var errorToThrow: Error = CollegeDataError.schoolNotFound

  // MARK: - Call Tracking

  var lookupCollegeCallCount = 0
  var lastLookupName: String?

  var searchCollegesCallCount = 0
  var lastSearchQuery: String?

  // MARK: - CollegeScorecardManaging

  nonisolated func lookupCollege(name: String) async throws -> CollegeDataResult? {
    let (shouldThrow, error, result) = await MainActor.run {
      lookupCollegeCallCount += 1
      lastLookupName = name
      return (shouldThrowError, errorToThrow, stubbedResult)
    }
    if shouldThrow {
      throw error
    }
    return result
  }

  nonisolated func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    let (shouldThrow, error, results) = await MainActor.run {
      searchCollegesCallCount += 1
      lastSearchQuery = query
      return (shouldThrowError, errorToThrow, stubbedSearchResults)
    }
    if shouldThrow {
      throw error
    }
    return results
  }

  // MARK: - Test Helpers

  func reset() {
    stubbedResult = nil
    stubbedSearchResults = []
    shouldThrowError = false
    errorToThrow = CollegeDataError.schoolNotFound
    lookupCollegeCallCount = 0
    lastLookupName = nil
    searchCollegesCallCount = 0
    lastSearchQuery = nil
  }
}
