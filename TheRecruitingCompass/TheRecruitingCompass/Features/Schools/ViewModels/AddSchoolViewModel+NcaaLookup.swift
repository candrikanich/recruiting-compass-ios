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
  func performNcaaLookup(for schoolName: String) async {
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

    // Perform primary lookup
    var result = await ncaaDatabase.lookup(schoolName: schoolName)

    // Fallback: College Scorecard appends " at [city]" for some campuses
    // (e.g. "Kent State University at Kent" vs NCAA "Kent State University").
    // If primary fails and the name contains " at ", retry with the base name.
    if result == nil, let atRange = schoolName.range(of: " at ") {
      let baseName = String(schoolName[..<atRange.lowerBound])
      if baseName.count > 8 {
        ncaaLogger.debug("NCAA fallback lookup (stripped ' at [city]'): \(baseName)")
        result = await ncaaDatabase.lookup(schoolName: baseName)
      }
    }

    if let result {
      // Ignore stale results: user may have selected a different college while lookup was in flight
      guard formState.name == schoolName else {
        ncaaLogger.debug("Discarding NCAA result for \(schoolName) — user selected different college")
        return
      }
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
