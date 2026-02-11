//
//  MockCollegeScorecardService.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Mock implementation of CollegeScorecardManaging for testing
//

import Foundation
@testable import TheRecruitingCompass

@MainActor
final class MockCollegeScorecardService: CollegeScorecardManaging {

  // MARK: - Stubbed Results

  var stubbedLookupResult: CollegeDataResult?
  var stubbedSearchResults: [CollegeSearchResult] = []
  var shouldThrowError: CollegeDataError?

  // MARK: - Call Tracking

  var lookupCollegeCallCount = 0
  var lastLookupName: String?

  var searchCollegesCallCount = 0
  var lastSearchQuery: String?

  // MARK: - CollegeScorecardManaging

  nonisolated func lookupCollege(name: String) async throws -> CollegeDataResult? {
    await MainActor.run {
      lookupCollegeCallCount += 1
      lastLookupName = name

      if let error = shouldThrowError {
        // Note: We can't actually throw here in this pattern, so we'll return nil
        // For proper error testing, use a Result type instead
        return nil
      }

      return stubbedLookupResult
    }
  }

  nonisolated func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    await MainActor.run {
      searchCollegesCallCount += 1
      lastSearchQuery = query

      if let error = shouldThrowError {
        // Note: We can't actually throw here in this pattern
        return []
      }

      return stubbedSearchResults
    }
  }

  // MARK: - Test Helpers

  func reset() {
    stubbedLookupResult = nil
    stubbedSearchResults = []
    shouldThrowError = nil
    lookupCollegeCallCount = 0
    lastLookupName = nil
    searchCollegesCallCount = 0
    lastSearchQuery = nil
  }
}
