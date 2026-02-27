//
//  AddSchoolViewModel+Enrichment.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 3: College Scorecard Enrichment Integration
//

import Foundation
import OSLog
import SwiftUI

private let enrichmentLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel.Enrichment"
)

// MARK: - Enrichment State Extension

extension AddSchoolViewModel {

  // Note: Enrichment state properties (scorecardData, isEnrichmentLoading, enrichmentError)
  // are defined directly in AddSchoolViewModel as observable properties (@Observable).

  // MARK: - Enrichment Actions

  /// Performs College Scorecard enrichment to fetch full academic data
  /// Uses college ID when available for exact match; falls back to name lookup
  /// - Parameter college: The selected college from autocomplete (provides id and name)
  func performScorecardEnrichment(for college: CollegeSearchResult) async {
    guard !college.name.isEmpty else {
      enrichmentLogger.debug("Enrichment skipped: empty college name")
      return
    }

    enrichmentLogger.debug("Performing College Scorecard enrichment for: \(college.name) (id: \(college.id))")
    isEnrichmentLoading = true
    enrichmentError = nil
    defer { isEnrichmentLoading = false }

    do {
      // Prefer lookup by ID for exact match (avoids Ohio U → Ohio State wrong match)
      let data: CollegeDataResult?
      if !college.id.isEmpty {
        data = try await collegeScorecardService.lookupCollege(id: college.id)
      } else {
        data = try await collegeScorecardService.lookupCollege(name: college.name)
      }
      if let data {
        scorecardData = data
        enrichmentLogger.info("Enrichment successful: \(data.name)")

        // Announce for accessibility
        announcer.announce("College data loaded")
      } else {
        enrichmentLogger.info("No College Scorecard data found for: \(college.name)")
        scorecardData = nil
        enrichmentError = nil // Silent failure per spec
      }

    } catch let error as CollegeDataError {
      enrichmentLogger.error("Enrichment failed: \(error.localizedDescription)")

      // Silent failures per spec - don't show errors to user
      enrichmentError = nil
      scorecardData = nil

      // Log for debugging
      switch error {
      case .apiKeyMissing:
        enrichmentLogger.warning("College Scorecard API key not configured")
      case .networkError:
        enrichmentLogger.warning("Network error during enrichment")
      case .rateLimited:
        enrichmentLogger.warning("Rate limited during enrichment")
      case .serverError(let code):
        enrichmentLogger.warning("Server error \(code) during enrichment")
      default:
        enrichmentLogger.warning("Enrichment error: \(error.localizedDescription)")
      }

    } catch {
      enrichmentLogger.error("Unexpected enrichment error: \(error.localizedDescription)")
      enrichmentError = nil // Silent failure
      scorecardData = nil
    }
  }

  /// Clears enrichment data
  func clearEnrichment() {
    enrichmentLogger.debug("Clearing enrichment data")
    scorecardData = nil
    enrichmentError = nil
    isEnrichmentLoading = false
  }
}

// Note: Enrichment state lives in AddSchoolViewModel as observable properties (@Observable).
