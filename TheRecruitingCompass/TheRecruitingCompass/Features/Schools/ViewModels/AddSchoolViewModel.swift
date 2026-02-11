//
//  AddSchoolViewModel.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 5: ViewModel - Form state management and submission logic
//

import Foundation
import SwiftUI
import Combine
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel"
)

@MainActor
final class AddSchoolViewModel: ObservableObject {

  // MARK: - Published State

  @Published var formState = SchoolFormState()
  @Published var formErrors = SchoolFormErrors.empty
  @Published var isSubmitting = false
  @Published var submitError: String?

  // MARK: - Dependencies

  private let schoolsService: SchoolsManaging
  private let familyUnitId: String
  private let userId: String
  internal let announcer: AccessibilityAnnouncing

  // MARK: - Computed Properties

  var isSubmitDisabled: Bool {
    isSubmitting || formErrors.hasErrors || !formState.isSubmittable
  }

  var submitButtonTitle: String {
    isSubmitting ? "Adding..." : "Add School"
  }

  // MARK: - Init

  init(
    schoolsService: SchoolsManaging,
    familyUnitId: String,
    userId: String,
    announcer: AccessibilityAnnouncing = UIAccessibilityAnnouncer()
  ) {
    self.schoolsService = schoolsService
    self.familyUnitId = familyUnitId
    self.userId = userId
    self.announcer = announcer
  }

  // MARK: - Validation Lookup Table

  private typealias FieldValidation = (String) -> String?
  private typealias ErrorSetter = (inout SchoolFormErrors, String?) -> Void

  private lazy var fieldValidators: [PartialKeyPath<SchoolFormState>: (
    validator: FieldValidation,
    setError: ErrorSetter
  )] = [
    \SchoolFormState.name: (SchoolFieldValidator.validateName, { $0.name = $1 }),
    \SchoolFormState.location: (SchoolFieldValidator.validateLocation, { $0.location = $1 }),
    \SchoolFormState.city: (SchoolFieldValidator.validateCity, { $0.city = $1 }),
    \SchoolFormState.state: (SchoolFieldValidator.validateState, { $0.state = $1 }),
    \SchoolFormState.conference: (SchoolFieldValidator.validateConference, { $0.conference = $1 }),
    \SchoolFormState.website: (SchoolFieldValidator.validateWebsite, { $0.website = $1 }),
    \SchoolFormState.twitterHandle: (SchoolFieldValidator.validateTwitterHandle, { $0.twitterHandle = $1 }),
    \SchoolFormState.instagramHandle: (SchoolFieldValidator.validateInstagramHandle, { $0.instagramHandle = $1 }),
    \SchoolFormState.notes: (SchoolFieldValidator.validateNotes, { $0.notes = $1 })
  ]

  // MARK: - Actions

  /// Validates a single form field (called on blur/submit)
  /// - Parameters:
  ///   - field: KeyPath to the field in SchoolFormState
  ///   - value: The current field value
  func validateField(_ field: KeyPath<SchoolFormState, String>, value: String) {
    logger.debug("Validating field: \(String(describing: field))")

    guard let (validator, setError) = fieldValidators[field] else {
      logger.warning("Unhandled field validation: \(String(describing: field))")
      return
    }

    let error = validator(value)
    setError(&formErrors, error)

    if let error {
      logger.debug("Field validation failed: \(error)")
    }
  }

  /// Submits the school form after full validation
  /// - Returns: The newly created School on success, nil on failure
  func submitSchool() async -> School? {
    logger.debug("Submitting school form")

    // 1. Full validation
    formErrors = validateAllFields()

    guard !formErrors.hasErrors else {
      logger.warning("Form validation failed: \(self.formErrors.allErrors.count) errors")
      announceErrorsForAccessibility()
      return nil
    }

    // 2. Prepare data with sanitization
    let request = SchoolCreateRequest.from(
      form: formState,
      scorecardData: scorecardData, // Phase 3: Include College Scorecard data if available
      userId: userId,
      familyUnitId: familyUnitId
    )

    logger.debug("Prepared request: \(request.name) (\(request.status))")

    // 3. Submit to API
    isSubmitting = true
    submitError = nil
    defer { isSubmitting = false }

    do {
      let newSchool = try await schoolsService.createSchool(request: request)
      logger.info("School created successfully: \(newSchool.id)")

      // Success announcement with haptic feedback
      let announcement = "School \(newSchool.name) added successfully"
      announcer.announceWithFeedback(announcement, success: true)

      return newSchool

    } catch {
      logger.error("Failed to create school: \(error.localizedDescription)")
      submitError = "Failed to create school. Please try again."

      // Error announcement with haptic feedback
      announcer.announceWithFeedback(
        "Failed to create school. \(error.localizedDescription)",
        success: false
      )

      return nil
    }
  }

  // MARK: - Private Helpers

  /// Validates all form fields at once
  /// - Returns: SchoolFormErrors with all validation errors
  private func validateAllFields() -> SchoolFormErrors {
    SchoolFormErrors(
      name: SchoolFieldValidator.validateName(formState.name),
      location: SchoolFieldValidator.validateLocation(formState.location),
      city: SchoolFieldValidator.validateCity(formState.city),
      state: SchoolFieldValidator.validateState(formState.state),
      division: nil, // Optional field, no validation required
      conference: SchoolFieldValidator.validateConference(formState.conference),
      website: SchoolFieldValidator.validateWebsite(formState.website),
      twitterHandle: SchoolFieldValidator.validateTwitterHandle(formState.twitterHandle),
      instagramHandle: SchoolFieldValidator.validateInstagramHandle(formState.instagramHandle),
      notes: SchoolFieldValidator.validateNotes(formState.notes),
      status: nil // Always valid, required in form state
    )
  }

  /// Announces form errors for VoiceOver users
  private func announceErrorsForAccessibility() {
    let errorCount = formErrors.allErrors.count
    let errorList = formErrors.allErrors.joined(separator: ", ")
    let announcement = "Form has \(errorCount) error\(errorCount == 1 ? "" : "s"): \(errorList)"

    logger.debug("Announcing errors: \(announcement)")
    announcer.announce(announcement)
  }

  // MARK: - Public Helpers

  /// Clears all form errors
  func clearErrors() {
    logger.debug("Clearing all form errors")
    formErrors = SchoolFormErrors.empty
    submitError = nil
  }

  /// Resets the entire form to initial state
  func resetForm() {
    logger.debug("Resetting form to initial state")
    formState = SchoolFormState()
    formErrors = SchoolFormErrors.empty
    submitError = nil
  }
}
