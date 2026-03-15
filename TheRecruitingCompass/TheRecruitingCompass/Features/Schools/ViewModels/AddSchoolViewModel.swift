//
//  AddSchoolViewModel.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 5: ViewModel - Form state management and submission logic
//

import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddSchoolViewModel"
)

@Observable
@MainActor
final class AddSchoolViewModel {

  // MARK: - State

  var formState = SchoolFormState()
  var formErrors = SchoolFormErrors.empty
  var isSubmitting = false
  var submitError: String?

  // Autocomplete state (moved from extension)
  var searchQuery: String = ""
  var searchResults: [CollegeSearchResult] = []
  var isSearching: Bool = false
  var selectedCollege: CollegeSearchResult?
  var searchError: String?

  // Enrichment state (moved from extension)
  var scorecardData: CollegeDataResult?
  var isEnrichmentLoading: Bool = false
  var enrichmentError: String?

  // Duplicate detection state (moved from extension)
  var showDuplicateDialog = false
  var duplicateResult: DuplicateResult?
  var isCheckingDuplicates = false

  // MARK: - Dependencies

  internal let schoolsService: SchoolsManaging
  internal let collegeScorecardService: CollegeScorecardManaging
  internal let ncaaDatabase: NcaaDatabaseManaging
  internal let schoolFaviconService: SchoolFaviconManaging
  internal let familyUnitId: String
  internal let userId: String
  nonisolated(unsafe) internal let announcer: AccessibilityAnnouncing

  // MARK: - Computed Properties

  var isSubmitDisabled: Bool {
    isSubmitting || formErrors.hasErrors || !formState.isSubmittable
  }

  var submitButtonTitle: String {
    isSubmitting ? "Adding..." : "Add School"
  }

  // MARK: - Init

  nonisolated init(
    schoolsService: SchoolsManaging,
    collegeScorecardService: CollegeScorecardManaging,
    ncaaDatabase: NcaaDatabaseManaging,
    schoolFaviconService: SchoolFaviconManaging,
    familyUnitId: String,
    userId: String,
    announcer: AccessibilityAnnouncing
  ) {
    self.schoolsService = schoolsService
    self.collegeScorecardService = collegeScorecardService
    self.ncaaDatabase = ncaaDatabase
    self.schoolFaviconService = schoolFaviconService
    self.familyUnitId = familyUnitId
    self.userId = userId
    self.announcer = announcer
  }

  /// Convenience initializer with default dependencies
  convenience init(
    schoolsService: SchoolsManaging,
    familyUnitId: String,
    userId: String
  ) {
    self.init(
      schoolsService: schoolsService,
      collegeScorecardService: CollegeScorecardService(),
      ncaaDatabase: NcaaDatabase.shared,
      schoolFaviconService: SchoolFaviconService(),
      familyUnitId: familyUnitId,
      userId: userId,
      announcer: AccessibilityAnnouncer()
    )
  }

  // MARK: - Debounce Task

  private var searchDebounceTask: Task<Void, Never>?

  // MARK: - Search Coordination

  /// Handles search query changes with 300ms debounce.
  /// Cancels any pending search task before scheduling a new one.
  func handleSearchQueryChanged(_ text: String) {
    searchDebounceTask?.cancel()
    searchDebounceTask = Task {
      try? await Task.sleep(for: .milliseconds(300))
      if !Task.isCancelled {
        await performAutocompleteSearch(query: text)
      }
    }
  }

  /// Handles school name changes, triggering NCAA lookup when appropriate.
  func handleNameChanged(_ newName: String) {
    guard !newName.isEmpty, formState.division == nil else { return }
    Task {
      await performNcaaLookup(for: newName)
    }
  }

  // MARK: - Validation Lookup Table

  private typealias FieldValidation = (String) -> String?
  private typealias ErrorSetter = (inout SchoolFormErrors, String?) -> Void

  private static let fieldValidators: [PartialKeyPath<SchoolFormState>: (
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

    guard let (validator, setError) = Self.fieldValidators[field] else {
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

    // 3. Duplicate check
    let duplicateCheck = await checkForDuplicates(request: request)

    if duplicateCheck.isDuplicate {
      duplicateResult = duplicateCheck
      showDuplicateDialog = true
      return nil  // Wait for user decision
    }

    // 4. Submit to API (extracted to createSchoolInternal for reuse)
    return await createSchoolInternal(request: request)
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

  /// Announces character count milestones for accessibility
  /// Called when notes field changes - announces at 90% and when limit exceeded
  /// - Parameter count: Current character count
  func announceCharacterCountIfNeeded(count: Int) {
    let limit = SchoolFormState.notesCharacterLimit
    let threshold90 = Int(Double(limit) * 0.9) // 4500 for 5000 limit

    // Announce at 90% threshold
    if count == threshold90 {
      let remaining = limit - count
      announcer.announce("\(remaining) characters remaining")
    }

    // Announce when limit exceeded
    if count == limit + 1 {
      announcer.announce("Character limit exceeded")
    }
  }

  // MARK: - Error Mapping

  /// Maps CollegeDataError to user-friendly error message
  /// - Parameter error: The CollegeDataError to map
  /// - Returns: User-friendly error message, or nil for silent failures
  func mapCollegeDataError(_ error: CollegeDataError) -> String? {
    switch error {
    case .apiKeyMissing:
      return "College search is not configured. Please enter the school manually."
    case .nameTooShort:
      return nil // Silent
    case .rateLimited:
      return "Too many requests. Please try again in a moment."
    case .invalidApiKey:
      return "College search is not configured correctly."
    case .networkError:
      return "Unable to search colleges. Check your internet connection."
    case .serverError:
      return "College search service is temporarily unavailable."
    default:
      return "Unable to search colleges. Please try again."
    }
  }


}
