//
//  AddCoachViewModel.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 3: ViewModel - Form state management and submission logic
//

import Foundation
import SwiftUI
import Combine
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddCoachViewModel"
)

@MainActor
final class AddCoachViewModel: ObservableObject {

  // MARK: - Published State

  @Published var formState = CoachFormState()
  @Published var formErrors = CoachFormErrors.empty
  @Published var schools: [School] = []
  @Published var isLoadingSchools = false
  @Published var isSubmitting = false
  @Published var submitError: String?

  // MARK: - Dependencies

  private let coachesService: CoachesManaging
  private let familyUnitId: String
  private let userId: String
  nonisolated(unsafe) private let announcer: AccessibilityAnnouncing

  // MARK: - Computed Properties

  var isFormVisible: Bool {
    formState.isSchoolSelected
  }

  var isSubmitDisabled: Bool {
    isSubmitting || formErrors.hasErrors || !formState.isSubmittable
  }

  var submitButtonTitle: String {
    isSubmitting ? "Adding..." : "Add Coach"
  }

  // MARK: - Init

  nonisolated init(
    coachesService: CoachesManaging,
    familyUnitId: String,
    userId: String,
    announcer: AccessibilityAnnouncing
  ) {
    self.coachesService = coachesService
    self.familyUnitId = familyUnitId
    self.userId = userId
    self.announcer = announcer
  }

  /// Convenience initializer with default announcer
  convenience init(
    coachesService: CoachesManaging,
    familyUnitId: String,
    userId: String
  ) {
    self.init(
      coachesService: coachesService,
      familyUnitId: familyUnitId,
      userId: userId,
      announcer: UIAccessibilityAnnouncer()
    )
  }

  // MARK: - Validation Lookup Table

  private typealias FieldValidation = (String) -> String?
  private typealias ErrorSetter = (inout CoachFormErrors, String?) -> Void

  private lazy var fieldValidators: [PartialKeyPath<CoachFormState>: (
    validator: FieldValidation,
    setError: ErrorSetter
  )] = [
    \CoachFormState.firstName: (FieldValidator.validateFirstName, { $0.firstName = $1 }),
    \CoachFormState.lastName: (FieldValidator.validateLastName, { $0.lastName = $1 }),
    \CoachFormState.email: (FieldValidator.validateEmail, { $0.email = $1 }),
    \CoachFormState.phone: (FieldValidator.validatePhone, { $0.phone = $1 }),
    \CoachFormState.twitterHandle: (FieldValidator.validateTwitterHandle, { $0.twitterHandle = $1 }),
    \CoachFormState.instagramHandle: (FieldValidator.validateInstagramHandle, { $0.instagramHandle = $1 }),
    \CoachFormState.notes: (FieldValidator.validateNotes, { $0.notes = $1 })
  ]

  // MARK: - Actions

  /// Loads the user's tracked schools for the school picker
  func loadSchools() async {
    guard !isLoadingSchools else {
      logger.debug("Already loading schools, skipping duplicate request")
      return
    }

    logger.debug("Loading schools for family unit: \(self.familyUnitId)")
    isLoadingSchools = true
    submitError = nil
    defer { isLoadingSchools = false }

    do {
      schools = try await coachesService.fetchSchools(familyUnitId: familyUnitId)
      logger.info("Loaded \(self.schools.count) schools")

      if schools.isEmpty {
        logger.warning("No schools found for family unit")
      }
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      submitError = "Failed to load schools. Please try again."
    }
  }

  /// Validates a single form field (called on blur/submit)
  /// - Parameters:
  ///   - field: KeyPath to the field in CoachFormState
  ///   - value: The current field value
  func validateField(_ field: KeyPath<CoachFormState, String>, value: String) {
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

  /// Validates the role field (called on picker change)
  /// - Parameter role: The selected role (optional)
  func validateRole(_ role: CoachRole?) {
    logger.debug("Validating role: \(role?.rawValue ?? "nil")")
    formErrors.role = FieldValidator.validateRole(role?.rawValue)
  }

  /// Submits the coach form after full validation
  /// - Returns: The newly created Coach on success, nil on failure
  func submitCoach() async -> Coach? {
    logger.debug("Submitting coach form")

    // 1. Full validation
    formErrors = validateAllFields()

    guard !formErrors.hasErrors else {
      logger.warning("Form validation failed: \(self.formErrors.allErrors.count) errors")
      announceErrorsForAccessibility()
      return nil
    }

    guard let schoolId = formState.selectedSchoolId else {
      logger.error("No school selected")
      submitError = "Please select a school"
      return nil
    }

    // 2. Prepare data with sanitization
    let request = CoachCreateRequest.from(
      form: formState,
      schoolId: schoolId,
      userId: userId,
      familyUnitId: familyUnitId
    )

    logger.debug("Prepared request: \(request.firstName) \(request.lastName) (\(request.role))")

    // 3. Submit to API
    isSubmitting = true
    submitError = nil
    defer { isSubmitting = false }

    do {
      let newCoach = try await coachesService.createCoach(request: request)
      logger.info("Coach created successfully: \(newCoach.id)")

      // Success announcement with haptic feedback
      let announcement = "Coach \(newCoach.firstName) \(newCoach.lastName) added successfully"
      announcer.announceWithFeedback(announcement, success: true)

      return newCoach

    } catch {
      logger.error("Failed to create coach: \(error.localizedDescription)")
      submitError = "Failed to create coach. Please try again."

      // Error announcement with haptic feedback
      announcer.announceWithFeedback(
        "Failed to create coach. \(error.localizedDescription)",
        success: false
      )

      return nil
    }
  }

  // MARK: - Private Helpers

  /// Validates all form fields at once
  /// - Returns: CoachFormErrors with all validation errors
  private func validateAllFields() -> CoachFormErrors {
    CoachFormErrors(
      role: FieldValidator.validateRole(formState.role?.rawValue),
      firstName: FieldValidator.validateFirstName(formState.firstName),
      lastName: FieldValidator.validateLastName(formState.lastName),
      email: FieldValidator.validateEmail(formState.email),
      phone: FieldValidator.validatePhone(formState.phone),
      twitterHandle: FieldValidator.validateTwitterHandle(formState.twitterHandle),
      instagramHandle: FieldValidator.validateInstagramHandle(formState.instagramHandle),
      notes: FieldValidator.validateNotes(formState.notes)
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
    formErrors = CoachFormErrors.empty
    submitError = nil
  }

  /// Resets the entire form to initial state
  func resetForm() {
    logger.debug("Resetting form to initial state")
    formState = CoachFormState()
    formErrors = CoachFormErrors.empty
    submitError = nil
  }
}
