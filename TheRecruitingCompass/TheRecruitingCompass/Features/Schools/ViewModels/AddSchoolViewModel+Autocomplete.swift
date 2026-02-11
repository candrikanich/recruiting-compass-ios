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

  // MARK: - Autocomplete State (stored in associated object pattern)

  /// Search query for college autocomplete
  var searchQuery: String {
    get { autocompleteState.searchQuery }
    set { autocompleteState.searchQuery = newValue }
  }

  /// Search results from College Scorecard API
  var searchResults: [CollegeSearchResult] {
    get { autocompleteState.searchResults }
    set { autocompleteState.searchResults = newValue }
  }

  /// Loading state for search
  var isSearching: Bool {
    get { autocompleteState.isSearching }
    set { autocompleteState.isSearching = newValue }
  }

  /// Selected college from autocomplete
  var selectedCollege: CollegeSearchResult? {
    get { autocompleteState.selectedCollege }
    set { autocompleteState.selectedCollege = newValue }
  }

  /// Search error message
  var searchError: String? {
    get { autocompleteState.searchError }
    set { autocompleteState.searchError = newValue }
  }

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
      let service = CollegeScorecardService()
      let results = try await service.searchColleges(query: query)

      searchResults = results
      autocompleteLogger.info("Found \(results.count) colleges for query: \(query)")

    } catch let error as CollegeDataError {
      autocompleteLogger.error("Autocomplete search failed: \(error.localizedDescription)")

      switch error {
      case .apiKeyMissing:
        searchError = "College search is not configured. Please enter the school manually."
      case .nameTooShort:
        searchError = nil // Silent - just clear results
      case .rateLimited:
        searchError = "Too many requests. Please try again in a moment."
      case .invalidApiKey:
        searchError = "College search is not configured correctly."
      case .networkError:
        searchError = "Unable to search colleges. Check your internet connection."
      case .serverError:
        searchError = "College search service is temporarily unavailable."
      default:
        searchError = "Unable to search colleges. Please try again."
      }

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
    UIAccessibility.post(notification: .announcement, argument: announcement)

    // Trigger NCAA lookup for division/conference
    performNcaaLookup(for: college.name)

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
    UIAccessibility.post(notification: .announcement, argument: "Selection cleared")
  }
}

// MARK: - Autocomplete State Storage

/// Internal state storage for autocomplete (since we can't add @Published to extensions)
private class AutocompleteState: ObservableObject {
  @Published var searchQuery: String = ""
  @Published var searchResults: [CollegeSearchResult] = []
  @Published var isSearching: Bool = false
  @Published var selectedCollege: CollegeSearchResult? = nil
  @Published var searchError: String? = nil
}

/// Associated object key for autocomplete state
private var autocompleteStateKey: UInt8 = 0

extension AddSchoolViewModel {
  /// Get or create autocomplete state
  private var autocompleteState: AutocompleteState {
    if let state = objc_getAssociatedObject(self, &autocompleteStateKey) as? AutocompleteState {
      return state
    }

    let state = AutocompleteState()
    objc_setAssociatedObject(self, &autocompleteStateKey, state, .OBJC_ASSOCIATION_RETAIN)
    return state
  }
}
