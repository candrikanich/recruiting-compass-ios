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
  var showAddSchoolSheet = false
  var newCoachForm = NewCoachFormState()
  var otherCoachName: String = ""

  /// Set on a successful submit when the logged interaction auto-advanced its
  /// school from a pre-contact stage to `contacted` (via the DB trigger). Read
  /// by the presenting screen to show a "‹School› moved to Contacted" toast.
  private(set) var contactedAdvanceMessage: String?

  // MARK: - Dependencies

  private let interactionsService: any InteractionsManaging
  private let familyUnitId: String
  private let userId: String
  private let preselectedSchoolId: String?
  /// Set when this form is reviewing an inbound-email draft rather than
  /// logging fresh (#113, parity w/ web #678) — submit confirms the draft via
  /// the web API (with the reviewed field overrides) instead of writing
  /// straight to `interactions`, since `inbound_email_drafts` is service-role-only.
  private let draftToConfirm: InboundEmailDraft?
  private let draftsAPIService: any InboundDraftsAPIManaging
  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  var schoolCoaches: [Coach] {
    guard !formState.schoolId.isEmpty else { return [] }
    return allCoaches.filter { $0.schoolId == formState.schoolId }
  }

  var canSubmit: Bool {
    formState.isValid && !isSubmitting
  }

  var pageTitle: String {
    draftToConfirm != nil ? String(localized: "Review Coach Email") : String(localized: "Log Interaction")
  }

  /// Website to prefill the add-school sheet with, derived from the draft
  /// sender's email domain (#125, parity w/ web #675). Only set while
  /// reviewing a draft with a `senderEmail` containing `@` and a non-empty
  /// trailing segment — guards a malformed multi-`@` address the same way
  /// web's `segments[segments.length - 1]` does.
  var schoolWebsitePrefill: String? {
    guard let senderEmail = draftToConfirm?.senderEmail, senderEmail.contains("@") else { return nil }
    guard let domain = senderEmail.split(separator: "@").last, !domain.isEmpty else { return nil }
    return "https://\(domain)"
  }

  var submitButtonTitle: String {
    isSubmitting ? String(localized: "Logging...") : String(localized: "Log Interaction")
  }

  // MARK: - Init

  init(
    interactionsService: any InteractionsManaging,
    familyUnitId: String,
    userId: String,
    preselectedSchoolId: String? = nil,
    draftToConfirm: InboundEmailDraft? = nil,
    draftsAPIService: (any InboundDraftsAPIManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.interactionsService = interactionsService
    self.familyUnitId = familyUnitId
    self.userId = userId
    self.preselectedSchoolId = preselectedSchoolId
    self.draftToConfirm = draftToConfirm
    self.draftsAPIService = draftsAPIService ?? InboundDraftsAPIService()
    self.authManager = authManager ?? AuthManager.shared
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
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      allCoaches = try await coachesTask

      logger.info("Loaded \(self.schools.count) schools and \(self.allCoaches.count) coaches")

      if let draftToConfirm {
        prefillFromDraft(draftToConfirm)
      } else if let preselectedSchoolId, schools.contains(where: { $0.id == preselectedSchoolId }) {
        formState.schoolId = preselectedSchoolId
        logger.debug("Pre-selected school: \(preselectedSchoolId)")
      }
    } catch {
      logger.error("Failed to load form data: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load schools and coaches. Please try again.")
    }
  }

  /// Prefills the form from a parsed inbound-email draft for review (#113).
  /// Every field stays editable — the school is only set when it matches a
  /// real school in this family (an unmatched draft leaves it blank so the
  /// required-field validation forces a manual pick, same as web).
  private func prefillFromDraft(_ draft: InboundEmailDraft) {
    formState.type = .email
    formState.direction = .inbound
    formState.subject = draft.subject ?? ""
    formState.content = draft.bodyText ?? ""
    formState.occurredAt = draft.occurredAtDate
    formState.coachId = draft.matchedCoachId
    if let matchedSchoolId = draft.matchedSchoolId, schools.contains(where: { $0.id == matchedSchoolId }) {
      formState.schoolId = matchedSchoolId
    }

    // Unmatched-coach assist (#125, parity w/ web #675): prefill the add-coach
    // sheet from the sender's name/email so it doesn't open blank.
    let (firstName, lastName) = NewCoachFormState.splitSenderName(draft.senderName)
    newCoachForm.firstName = firstName
    newCoachForm.lastName = lastName
    newCoachForm.email = draft.senderEmail?.trimmingCharacters(in: .whitespaces) ?? ""
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
        email: newCoachForm.trimmedEmail.isEmpty ? nil : newCoachForm.trimmedEmail,
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

  /// Completion handler for the "School not listed? Add it" sheet (#125,
  /// parity w/ web #675) — selects the newly created school without
  /// disturbing any other in-progress edit (subject/body/type/direction),
  /// since this view model stays alive underneath the child sheet.
  func selectNewlyCreatedSchool(_ school: School) {
    if !schools.contains(where: { $0.id == school.id }) {
      schools.append(school)
    }
    formState.schoolId = school.id
    logger.debug("Selected newly created school: \(school.id)")
  }

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

    if let draftToConfirm {
      return await confirmDraft(draftToConfirm, type: interactionType)
    }

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

      // Capture pre-advance status: logging an interaction auto-advances a
      // pre-contact school (researching/interested/nil, rank < contacted) to
      // `contacted` via a DB trigger. Mirror that rule to confirm it in the UI.
      contactedAdvanceMessage = nil
      let advancingSchool = schools.first { $0.id == formState.schoolId }
      let wasPreContact = advancingSchool.map {
        (SchoolStatus(rawValue: $0.status) ?? .unknown).rank < SchoolStatus.contacted.rank
      } ?? false

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

      if wasPreContact, let name = advancingSchool?.name {
        contactedAdvanceMessage = String(localized: "\(name) moved to Contacted")
      }

      return true
    } catch {
      logger.error("Failed to submit interaction: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to create interaction. Please try again.")
      return false
    }
  }

  /// Confirms an inbound-email draft with the reviewed field overrides
  /// (#113) — routes through the web API instead of `createInteraction`
  /// since `inbound_email_drafts` needs the endpoint's service-role access
  /// to insert the interaction and flip the draft's status. Caller already
  /// set `isSubmitting`/`errorMessage`.
  private func confirmDraft(_ draft: InboundEmailDraft, type: InteractionType) async -> Bool {
    do {
      let response = try await draftsAPIService.confirmDraft(
        id: draft.id,
        schoolId: formState.schoolId,
        coachId: formState.coachId,
        type: type,
        direction: formState.direction,
        occurredAt: formState.occurredAt,
        subject: formState.subject.isEmpty ? nil : formState.subject,
        content: formState.content.isEmpty ? nil : formState.content,
        accessToken: authManager.session?.accessToken
      )
      logger.info("Confirmed draft \(draft.id) -> interaction \(response.interactionId ?? "nil")")

      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForFamily(familyUnitId: familyUnitId))
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForAthlete(userId: userId))

      return true
    } catch {
      logger.error("Failed to confirm draft \(draft.id): \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to confirm this draft. Please try again.")
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
