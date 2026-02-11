//
//  AddSchoolViewModel+NcaaLookup.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 1: NCAA Database Integration
//

import Foundation
import OSLog
import SwiftUI

private let ncaaLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel.NcaaLookup"
)

// MARK: - NCAA Database Lookup Extension

extension AddSchoolViewModel {

  /// Performs NCAA database lookup to auto-fill division and conference
  /// Triggered when user enters school name (only if division is not already set)
  /// - Parameter schoolName: The school name to search for
  func performNcaaLookup(for schoolName: String) {
    // Only perform lookup if:
    // 1. School name is not empty
    // 2. Division is not already manually set
    guard !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    guard formState.division == nil else {
      ncaaLogger.debug("NCAA lookup skipped: division already set manually")
      return
    }

    ncaaLogger.debug("Performing NCAA lookup for: \(schoolName)")

    // Perform lookup (synchronous, local database)
    if let result = ncaaDatabase.lookup(schoolName: schoolName) {
      ncaaLogger.info("NCAA match found: \(result.division.rawValue) - \(result.conference)")

      // Auto-fill division and conference
      formState.division = result.division
      formState.conference = result.conference

      // Announce for accessibility
      let announcement = "Auto-filled: \(result.division.displayName), \(result.conference)"
      announcer.announce(announcement)

    } else {
      ncaaLogger.debug("No NCAA match found for: \(schoolName)")
    }
  }
}
