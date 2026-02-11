//
//  AddSchoolViewModel+Enrichment.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 3: College Scorecard Enrichment Integration
//

import Foundation
import Combine
import OSLog
import SwiftUI

private let enrichmentLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel.Enrichment"
)

// MARK: - Enrichment State Extension

extension AddSchoolViewModel {

  // Note: Enrichment state properties (scorecardData, isEnrichmentLoading, enrichmentError)
  // are now defined directly in AddSchoolViewModel as @Published properties

  // MARK: - Enrichment Actions

  /// Performs College Scorecard enrichment to fetch full academic data
  /// - Parameter collegeName: The college name to enrich
  func performScorecardEnrichment(collegeName: String) async {
    guard !collegeName.isEmpty else {
      enrichmentLogger.debug("Enrichment skipped: empty college name")
      return
    }

    enrichmentLogger.debug("Performing College Scorecard enrichment for: \(collegeName)")
    isEnrichmentLoading = true
    enrichmentError = nil
    defer { isEnrichmentLoading = false }

    do {
      if let data = try await collegeScorecardService.lookupCollege(name: collegeName) {
        scorecardData = data
        enrichmentLogger.info("Enrichment successful: \(data.name)")

        // Announce for accessibility
        announcer.announce("College data loaded")
      } else {
        enrichmentLogger.info("No College Scorecard data found for: \(collegeName)")
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

// Note: Enrichment state now lives directly in AddSchoolViewModel as @Published properties
// This ensures proper SwiftUI observation and eliminates the need for associated objects
