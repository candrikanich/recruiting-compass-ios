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

// MARK: - Duplicate Detection State

@MainActor
final class DuplicateDetectionState: ObservableObject {
  @Published var showDuplicateDialog = false
  @Published var duplicateResult: DuplicateResult? = nil
  @Published var isCheckingDuplicates = false

  func reset() {
    showDuplicateDialog = false
    duplicateResult = nil
    isCheckingDuplicates = false
  }
}

// MARK: - ViewModel Extension

extension AddSchoolViewModel {

  // Associated object pattern (same as Enrichment/Autocomplete)
  private static var duplicateStateKey: UInt8 = 0

  var duplicateState: DuplicateDetectionState {
    if let state = objc_getAssociatedObject(self, &Self.duplicateStateKey) as? DuplicateDetectionState {
      return state
    }
    let state = DuplicateDetectionState()
    objc_setAssociatedObject(self, &Self.duplicateStateKey, state, .OBJC_ASSOCIATION_RETAIN)
    return state
  }

  var showDuplicateDialog: Bool {
    get { duplicateState.showDuplicateDialog }
    set { duplicateState.showDuplicateDialog = newValue }
  }

  var duplicateResult: DuplicateResult? {
    get { duplicateState.duplicateResult }
    set { duplicateState.duplicateResult = newValue }
  }

  // MARK: - Duplicate Detection Logic

  /// Check for duplicate schools before creating
  func checkForDuplicates(request: SchoolCreateRequest) async -> DuplicateResult {
    duplicateLogger.debug("Checking for duplicate schools")
    duplicateState.isCheckingDuplicates = true
    defer { duplicateState.isCheckingDuplicates = false }

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
    duplicateState.reset()
    announcer.announce("Cancelled")
  }

  /// Proceed with creating school despite duplicate warning
  func proceedDespiteDuplicate() async -> School? {
    duplicateLogger.debug("User chose to proceed despite duplicate")

    guard let request = buildCurrentRequest() else {
      duplicateLogger.error("Failed to build request")
      return nil
    }

    duplicateState.reset()
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
