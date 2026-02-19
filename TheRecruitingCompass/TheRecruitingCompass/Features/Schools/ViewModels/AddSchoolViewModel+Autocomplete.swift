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
    defer { isSearching = false }

    do {
      let results = try await collegeScorecardService.searchColleges(query: query)

      searchResults = results
      autocompleteLogger.info("Found \(results.count) colleges for query: \(query)")

      // Announce results for accessibility
      let resultCount = results.count
      let announcement = "\(resultCount) college\(resultCount == 1 ? "" : "s") found"
      announcer.announce(announcement)

    } catch let error as CollegeDataError {
      autocompleteLogger.error("Autocomplete search failed: \(error.localizedDescription)")
      searchError = mapCollegeDataError(error)
      searchResults = []

    } catch {
      autocompleteLogger.error("Unexpected error: \(error.localizedDescription)")
      searchError = "Unable to search colleges. Please try again."
      searchResults = []
    }
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

    // Clear search results
    searchResults = []
    searchQuery = ""
    searchError = nil

    // Announce for accessibility
    let announcement = "Selected: \(college.name), \(college.location)"
    announcer.announce(announcement)

    // Trigger NCAA lookup for division/conference
    await performNcaaLookup(for: college.name)

    // Phase 3: Trigger College Scorecard enrichment
    await performScorecardEnrichment(collegeName: college.name)
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
