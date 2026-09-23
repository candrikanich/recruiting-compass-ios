//
//  AddSchoolViewModel+Autocomplete.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 2: College Scorecard Autocomplete Integration
//

import Foundation
import Combine
import OSLog
import SwiftUI

private let autocompleteLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel.Autocomplete"
)

// MARK: - Autocomplete State Extension

extension AddSchoolViewModel {

  // Note: Autocomplete state properties (searchQuery, searchResults, isSearching, etc.)
  // are defined directly in AddSchoolViewModel as observable properties (@Observable).

  // MARK: - Autocomplete Actions

  /// Performs autocomplete search via College Scorecard API
  /// - Parameter query: Search query (minimum 3 characters)
  func performAutocompleteSearch(query: String) async {
    guard query.count >= 3 else {
      searchResults = []
      searchError = nil
      return
    }

    autocompleteLogger.debug("Performing autocomplete search: \(query)")
    isSearching = true
    searchError = nil
    // A cancelled search was superseded; the newer search owns the loading state.
    defer { if !Task.isCancelled { isSearching = false } }

    do {
      var results = try await collegeScorecardService.searchColleges(query: query)
      if results.isEmpty {
        results = try await searchWithSpellingCorrection(for: query)
      }

      searchResults = results
      autocompleteLogger.info("Found \(results.count) colleges for query: \(query)")

      // Announce results for accessibility
      let resultCount = results.count
      let announcement = "\(resultCount) college\(resultCount == 1 ? "" : "s") found"
      announcer.announce(announcement)

    } catch is CancellationError {
      autocompleteLogger.debug("Autocomplete search cancelled: \(query)")

    } catch let error as CollegeDataError {
      autocompleteLogger.error("Autocomplete search failed: \(error.localizedDescription)")
      searchError = mapCollegeDataError(error)
      searchResults = []

    } catch {
      autocompleteLogger.error("Unexpected error: \(error.localizedDescription)")
      searchError = String(localized: "Unable to search colleges. Please try again.")
      searchResults = []
    }
  }

  /// Scorecard matches names literally, so a typo yields nothing. Retry with the closest
  /// known NCAA spellings; the first one that returns results wins.
  private func searchWithSpellingCorrection(for query: String) async throws -> [CollegeSearchResult] {
    let corrections = await ncaaDatabase.suggestNames(for: query)
      .filter { $0.caseInsensitiveCompare(query) != .orderedSame }
      .prefix(2)

    for correction in corrections {
      autocompleteLogger.debug("No results for \(query); retrying as \(correction)")
      let results = try await collegeScorecardService.searchColleges(query: correction)
      if !results.isEmpty { return results }
    }
    return []
  }

  /// Selects a college from autocomplete results
  /// - Parameter college: The selected college
  func selectCollege(_ college: CollegeSearchResult) async {
    autocompleteLogger.info("College selected: \(college.name)")

    selectedCollege = college

    // Auto-fill basic fields
    formState.name = college.name
    formState.city = college.city
    formState.state = college.state
    formState.location = college.location
    formState.website = college.website ?? ""

    // Reset division and conference so NCAA lookup always runs for the new selection
    formState.division = nil
    formState.conference = ""

    // Clear search results
    searchResults = []
    searchQuery = ""
    searchError = nil

    // Announce for accessibility
    let announcement = "Selected: \(college.name), \(college.location)"
    announcer.announce(announcement)

    // Run NCAA lookup and College Scorecard enrichment in parallel.
    // Use college ID for exact lookup when available (avoids wrong match e.g. Ohio U vs Ohio State).
    async let ncaaTask: () = performNcaaLookup(for: college.name)
    async let enrichmentTask: () = performScorecardEnrichment(for: college)
    _ = await (ncaaTask, enrichmentTask)
  }

  /// Clears the selected college and auto-filled fields
  func clearSelection() {
    autocompleteLogger.debug("Clearing college selection")

    selectedCollege = nil
    searchResults = []
    searchQuery = ""
    searchError = nil

    // Clear auto-filled fields
    formState.name = ""
    formState.city = ""
    formState.state = ""
    formState.location = ""
    formState.website = ""
    formState.division = nil
    formState.conference = ""

    // Phase 3: Clear enrichment data
    clearEnrichment()

    // Announce for accessibility
    announcer.announce("Selection cleared")
  }
}

// Note: Autocomplete state lives in AddSchoolViewModel as observable properties (@Observable).
