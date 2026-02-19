//
//  AddSchoolViewModel+DuplicateDetection.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11.
//

import Foundation
import Combine
import OSLog

private let duplicateLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel.DuplicateDetection"
)

// Note: Duplicate detection state lives in AddSchoolViewModel as observable properties (@Observable).

// MARK: - ViewModel Extension

extension AddSchoolViewModel {

  // Note: Duplicate state properties (showDuplicateDialog, duplicateResult, isCheckingDuplicates)
  // are defined directly in AddSchoolViewModel as observable properties (@Observable).

  // Helper to reset duplicate detection state
  func resetDuplicateState() {
    showDuplicateDialog = false
    duplicateResult = nil
    isCheckingDuplicates = false
  }

  // MARK: - Duplicate Detection Logic

  /// Check for duplicate schools before creating
  func checkForDuplicates(request: SchoolCreateRequest) async -> DuplicateResult {
    duplicateLogger.debug("Checking for duplicate schools")
    isCheckingDuplicates = true
    defer { isCheckingDuplicates = false }

    do {
      // Fetch all schools for this family unit
      let existingSchools = try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
      duplicateLogger.debug("Fetched \(existingSchools.count) existing schools for duplicate check")

      // Run duplicate detection
      let result = DuplicateDetector.findDuplicate(in: existingSchools, for: request)

      if result.isDuplicate, let duplicate = result.duplicate, let matchType = result.matchType {
        duplicateLogger.warning("Duplicate detected: \(duplicate.name) (match type: \(matchType.rawValue))")
        announcer.announce("Duplicate school detected: \(duplicate.name)")
      } else {
        duplicateLogger.debug("No duplicate found")
      }

      return result

    } catch {
      duplicateLogger.error("Failed to fetch schools for duplicate check: \(error.localizedDescription)")
      // If fetch fails, proceed without duplicate check (fail-safe)
      return DuplicateResult(duplicate: nil, matchType: nil)
    }
  }

  /// Cancel duplicate dialog
  func cancelDuplicate() {
    duplicateLogger.debug("User cancelled duplicate creation")
    resetDuplicateState()
    announcer.announce("Cancelled")
  }

  /// Proceed with creating school despite duplicate warning
  func proceedDespiteDuplicate() async -> School? {
    duplicateLogger.debug("User chose to proceed despite duplicate")

    guard let request = buildCurrentRequest() else {
      duplicateLogger.error("Failed to build request")
      return nil
    }

    resetDuplicateState()
    return await createSchoolInternal(request: request)
  }

  // MARK: - Helper Methods

  /// Build SchoolCreateRequest from current form state
  func buildCurrentRequest() -> SchoolCreateRequest? {
    SchoolCreateRequest.from(
      form: formState,
      scorecardData: scorecardData,
      userId: userId,
      familyUnitId: familyUnitId
    )
  }

  /// Internal creation logic (called after duplicate check or "Proceed Anyway")
  func createSchoolInternal(request: SchoolCreateRequest) async -> School? {
    isSubmitting = true
    submitError = nil
    defer { isSubmitting = false }

    do {
      let newSchool = try await schoolsService.createSchool(request: request)
      duplicateLogger.info("School created successfully: \(newSchool.id)")

      // Success announcement with haptic feedback
      let announcement = "School \(newSchool.name) added successfully"
      announcer.announceWithFeedback(announcement, success: true)

      return newSchool

    } catch {
      duplicateLogger.error("Failed to create school: \(error.localizedDescription)")
      submitError = "Failed to create school. Please try again."

      // Error announcement with haptic feedback
      announcer.announceWithFeedback(
        "Failed to create school. \(error.localizedDescription)",
        success: false
      )

      return nil
    }
  }
}
