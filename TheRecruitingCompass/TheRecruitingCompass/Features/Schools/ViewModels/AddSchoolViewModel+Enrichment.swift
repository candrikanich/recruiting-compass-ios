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

  // MARK: - Enrichment State (stored in associated object pattern)

  /// College Scorecard enrichment data
  var scorecardData: CollegeDataResult? {
    get { enrichmentState.scorecardData }
    set { enrichmentState.scorecardData = newValue }
  }

  /// Loading state for enrichment
  var isEnrichmentLoading: Bool {
    get { enrichmentState.isEnrichmentLoading }
    set { enrichmentState.isEnrichmentLoading = newValue }
  }

  /// Enrichment error message (silent failures)
  var enrichmentError: String? {
    get { enrichmentState.enrichmentError }
    set { enrichmentState.enrichmentError = newValue }
  }

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
      let service = CollegeScorecardService()

      if let data = try await service.lookupCollege(name: collegeName) {
        scorecardData = data
        enrichmentLogger.info("Enrichment successful: \(data.name)")

        // Announce for accessibility
        UIAccessibility.post(
          notification: .announcement,
          argument: "College data loaded"
        )
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

// MARK: - Enrichment State Storage

/// Internal state storage for enrichment (since we can't add @Published to extensions)
@MainActor
private final class EnrichmentState: ObservableObject {
  @Published var scorecardData: CollegeDataResult? = nil
  @Published var isEnrichmentLoading: Bool = false
  @Published var enrichmentError: String? = nil
}

/// Associated object key for enrichment state
private var enrichmentStateKey: UInt8 = 0

extension AddSchoolViewModel {
  /// Get or create enrichment state
  private var enrichmentState: EnrichmentState {
    if let state = objc_getAssociatedObject(self, &enrichmentStateKey) as? EnrichmentState {
      return state
    }

    let state = EnrichmentState()
    objc_setAssociatedObject(self, &enrichmentStateKey, state, .OBJC_ASSOCIATION_RETAIN)
    return state
  }
}
