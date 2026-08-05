import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "AddInteractionViewModel"
)

@Observable
@MainActor
final class AddInteractionViewModel {

  nonisolated deinit {}

  // MARK: - State

  var formState = InteractionFormState()
  var calibration = InterestCalibration()
  var schools: [School] = []
  var allCoaches: [Coach] = []
  var isLoading = false
  var isSubmitting = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var showAddCoachSheet = false
  var showOtherCoachSheet = false
  var newCoachForm = NewCoachFormState()
  var otherCoachName: String = ""

  // MARK: - Dependencies

  private let interactionsService: any InteractionsManaging
  private let familyUnitId: String
  private let userId: String

  // MARK: - Computed Properties

  var schoolCoaches: [Coach] {
    guard !formState.schoolId.isEmpty else { return [] }
    return allCoaches.filter { $0.schoolId == formState.schoolId }
  }

  var canSubmit: Bool {
    formState.isValid && !isSubmitting
  }

  var pageTitle: String {
    "Log Interaction"
  }

  var submitButtonTitle: String {
    isSubmitting ? String(localized: "Logging...") : String(localized: "Log Interaction")
  }

  // MARK: - Init

  init(
    interactionsService: any InteractionsManaging,
    familyUnitId: String,
    userId: String
  ) {
    self.interactionsService = interactionsService
    self.familyUnitId = familyUnitId
    self.userId = userId
  }

  // MARK: - Data Loading

  func loadFormData() async {
    guard !isLoading else {
      logger.debug("Already loading, skipping duplicate request")
      return
    }

    logger.debug("Loading form data")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let schoolsTask = interactionsService.fetchSchools(familyUnitId: familyUnitId)
      async let coachesTask = interactionsService.fetchCoaches(familyUnitId: familyUnitId)

      schools = try await schoolsTask
      allCoaches = try await coachesTask

      logger.info("Loaded \(self.schools.count) schools and \(self.allCoaches.count) coaches")
    } catch {
      logger.error("Failed to load form data: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load schools and coaches. Please try again.")
    }
  }

  // MARK: - Form Validation

  func validateForm() -> [String: String] {
    var errors: [String: String] = [:]

    if formState.schoolId.isEmpty {
      errors["school"] = String(localized: "Please select a school")
    }

    if formState.type == nil {
      errors["type"] = String(localized: "Please select an interaction type")
    }

    if formState.subject.count > 500 {
      errors["subject"] = String(localized: "Subject must be 500 characters or less")
    }

    if formState.content.count > 10000 {
      errors["content"] = String(localized: "Content must be 10,000 characters or less")
    }

    return errors
  }

  // MARK: - Coach Management

  func createNewCoach() async -> Bool {
    guard newCoachForm.isValid else {
      logger.warning("New coach form is invalid")
      return false
    }

    guard !formState.schoolId.isEmpty else {
      logger.warning("No school selected for new coach")
      errorMessage = String(localized: "Please select a school first")
      return false
    }

    logger.debug("Creating new coach: \(self.newCoachForm.fullName)")

    do {
      let request = CoachCreateRequest(
        schoolId: formState.schoolId,
        userId: userId,
        familyUnitId: familyUnitId,
        role: newCoachForm.role.rawValue,
        firstName: newCoachForm.trimmedFirstName,
        lastName: newCoachForm.trimmedLastName,
        email: nil,
        phone: nil,
        twitterHandle: nil,
        instagramHandle: nil,
        notes: nil
      )

      let newCoach = try await interactionsService.createCoach(request)
      logger.info("Created coach: \(newCoach.id)")

      // Invalidate CoachesListViewModel's cached list (Phase 3.6) so the new
      // coach appears immediately on next visit instead of waiting out the TTL.
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.coaches(familyUnitId: familyUnitId))

      // Add to local coach list and select
      allCoaches.append(newCoach)
      formState.coachId = newCoach.id

      // Reset form
      newCoachForm.reset()

      return true
    } catch {
      logger.error("Failed to create coach: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to create coach. Please try again.")
      return false
    }
  }

  func handleOtherCoach() {
    guard !otherCoachName.isEmpty else {
      logger.warning("Other coach name is empty")
      return
    }

    logger.debug("Using other coach: \(self.otherCoachName)")
    // Store coach name in content or metadata (spec allows null coach_id)
    formState.coachId = nil
    showOtherCoachSheet = false
  }

  // MARK: - School Selection

  func onSchoolChange() {
    // Clear coach selection when school changes
    formState.coachId = nil
    logger.debug("School changed, coach selection cleared")
  }

  // MARK: - Interest Calibration

  func onDirectionOrSentimentChange() {
    // Reset calibration if conditions no longer met
    if !formState.showsInterestCalibration {
      calibration.reset()
      formState.interestLevel = .notSet
      logger.debug("Calibration conditions not met, reset calibration")
    }
  }

  func onCalibrationAnswerChange() {
    formState.interestLevel = calibration.interestLevel
    logger.debug("Interest level updated: \(self.formState.interestLevel.rawValue)")
  }

  // MARK: - Submission

  func submitInteraction() async -> Bool {
    guard formState.isValid else {
      logger.warning("Form is invalid, cannot submit")
      return false
    }

    let validationErrors = validateForm()
    guard validationErrors.isEmpty else {
      logger.warning("Form validation failed: \(validationErrors.count) errors")
      errorMessage = validationErrors.values.first
      return false
    }

    guard let interactionType = formState.type else {
      errorMessage = String(localized: "Interaction type is required")
      return false
    }

    logger.debug("Submitting interaction")
    isSubmitting = true
    errorMessage = nil
    defer { isSubmitting = false }

    do {
      // Build final content with interest level if calibrated
      var finalContent = formState.content
      if formState.showsInterestCalibration && formState.interestLevel != .notSet {
        let calibrationNote = "\n\n[Coach Interest Level: \(formState.interestLevel.rawValue.uppercased())]"
        finalContent += calibrationNote
      }

      // Append other coach name if used
      if formState.coachId == nil && !otherCoachName.isEmpty {
        let otherCoachNote = "\n\n[Coach: \(otherCoachName)]"
        finalContent += otherCoachNote
      }

      // Create request
      let request = InteractionCreateRequest(
        schoolId: formState.schoolId.isEmpty ? nil : formState.schoolId,
        coachId: formState.coachId,
        eventId: nil,
        type: interactionType,
        direction: formState.direction,
        occurredAt: formState.occurredAt,
        subject: formState.subject.isEmpty ? nil : formState.subject,
        content: finalContent.isEmpty ? nil : finalContent,
        sentiment: formState.sentiment,
        loggedBy: userId,
        familyUnitId: familyUnitId
      )

      let interaction = try await interactionsService.createInteraction(request)
      logger.info("Created interaction: \(interaction.id)")

      // Invalidate InteractionsListViewModel's cached list (Phase 3.6) for both
      // possible fetch scopes — this VM doesn't know which one is cached.
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForFamily(familyUnitId: familyUnitId))
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForAthlete(userId: userId))

      // Upload attachments if any (Phase 4 - defer for MVP)
      // if !formState.attachedFiles.isEmpty { ... }

      // Create inbound alert if direction is inbound (Phase 4)
      // if formState.direction == .inbound { ... }

      return true
    } catch {
      logger.error("Failed to submit interaction: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to create interaction. Please try again.")
      return false
    }
  }

  // MARK: - Reset

  func reset() {
    formState.reset()
    calibration.reset()
    newCoachForm.reset()
    otherCoachName = ""
    errorMessage = nil
    logger.debug("Form reset")
  }

}
