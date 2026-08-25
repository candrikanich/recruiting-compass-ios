import Observation
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachDetailViewModel")

@Observable
@MainActor
final class CoachDetailViewModel {

  var coach: Coach?
  var school: School?
  var isLoading = false
  var errorMessage: String?

  // Interactions and stats
  var recentInteractions: [Interaction] = []
  var stats: CoachStats?
  var coachInsights: CoachInsights?

  // Communication analytics (parity with the web coach detail page)
  var metrics: CoachMetrics?
  var comparison: CoachComparison?
  var insights: [String] = []

  // Interactions-log filters (applied in-memory over `recentInteractions`)
  var filterType: InteractionType?
  var filterDirection: Direction?
  var filterSentiment: Sentiment?
  var filterWindowDays: Int?

  /// Upper bound on interactions pulled for a coach — high enough that metrics
  /// reflect the full history rather than only the last handful.
  private static let interactionsFetchLimit = 500

  // Editing state
  var isEditing = false
  var editedCoach: EditableCoach?
  var isSaving = false
  var validationErrors: [String: String] = [:]

  // Delete state
  var showDeleteConfirmation = false
  var isDeleting = false
  var deleteSuccessMessage: String?

  // Notes (always-editable, auto-save on blur)
  var editedSharedNotes = ""
  var saveStatus: SaveStatus = .idle
  var hapticSuccessTrigger = 0

  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

  private let coachId: String
  private let coachesService: any CoachesManaging
  private let interactionsService: any InteractionsManaging
  private let authManager: any AuthManaging
  private let allCoaches: [Coach]
  private let allSchools: [School]
  private let cache: (any CacheManaging)?

  // Social-DM return-confirmation: tapping Twitter/Instagram arms a prompt that
  // fires when the app returns to foreground (see confirmSocialDM/dismissSocialDM).
  enum SocialChannel: Sendable { case twitter, instagram }
  struct PendingSocialDM: Equatable, Sendable {
    let channel: SocialChannel
    let coachId: String
    let coachName: String
  }
  var pendingSocialDM: PendingSocialDM?

  /// TTL for cached coach (seconds).
  private static let coachCacheTTL: TimeInterval = 60

  init(
    coachId: String,
    allCoaches: [Coach] = [],
    allSchools: [School] = [],
    coachesService: (any CoachesManaging)? = nil,
    interactionsService: (any InteractionsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  // MARK: - Computed Properties

  var currentUserId: String? {
    authManager.user?.id
  }

  var editableCoachBinding: Binding<EditableCoach> {
    Binding(
      get: { [weak self] in
        guard let self else { return .empty }
        if let editedCoach = self.editedCoach {
          return editedCoach
        }
        if let coach = self.coach {
          return EditableCoach(from: coach)
        }
        return .empty
      },
      set: { [weak self] newValue in
        self?.editedCoach = newValue
      }
    )
  }

  // MARK: - Loading

  func loadCoach() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = "coach:\(coachId)"
    let cacheToUse = cache ?? InMemoryCache.shared

    // Try cache first
    if let cachedCoach = await cacheToUse.get(Coach.self, forKey: cacheKey) {
      coach = cachedCoach
      initializeNoteFields(from: cachedCoach)
      if let foundSchool = allSchools.first(where: { $0.id == cachedCoach.schoolId }) {
        school = foundSchool
      }
      logger.info("Loaded coach from cache: \(cachedCoach.fullName)")
      return
    }

    // Then try passed-in list (avoids network when navigating from list)
    if let foundCoach = allCoaches.first(where: { $0.id == coachId }) {
      coach = foundCoach
      initializeNoteFields(from: foundCoach)
      if let foundSchool = allSchools.first(where: { $0.id == foundCoach.schoolId }) {
        school = foundSchool
      }
      await cacheToUse.set(foundCoach, forKey: cacheKey, ttlSeconds: Self.coachCacheTTL)
      logger.info("Loaded coach from list: \(foundCoach.fullName)")
      return
    }

    // Finally fetch by ID
    do {
      let fetchedCoach = try await coachesService.fetchCoach(id: coachId)
      coach = fetchedCoach
      initializeNoteFields(from: fetchedCoach)
      if let foundSchool = allSchools.first(where: { $0.id == fetchedCoach.schoolId }) {
        school = foundSchool
      }
      await cacheToUse.set(fetchedCoach, forKey: cacheKey, ttlSeconds: Self.coachCacheTTL)
      logger.info("Loaded coach from API: \(fetchedCoach.fullName)")
    } catch {
      errorMessage = "Coach not found"
      logger.warning("Coach not found with ID: \(self.coachId): \(error.localizedDescription)")
    }
  }

  /// Invalidates cached coach, plus CoachesListViewModel's cached list
  /// (Phase 3.6) so an edited field shows correctly on next visit to the list
  /// screen. `allSchools` is the same list the caller passed in on
  /// navigation (from CoachesListViewModel), so no extra fetch is needed to
  /// resolve the coach's familyUnitId. Call after any mutation.
  private func invalidateCoachCache() async {
    let cacheKey = "coach:\(coachId)"
    let cacheToUse = cache ?? InMemoryCache.shared
    await cacheToUse.remove(forKey: cacheKey)
    if let coach, let familyUnitId = allSchools.first(where: { $0.id == coach.schoolId })?.familyUnitId {
      await cacheToUse.remove(forKey: ListCacheKeys.coaches(familyUnitId: familyUnitId))
    }
  }

  func loadDetails() async {
    guard let coach else { return }

    do {
      recentInteractions = try await coachesService.fetchInteractions(
        coachId: coachId,
        limit: Self.interactionsFetchLimit
      )
      stats = computeStats()
      coachInsights = CoachInsights.make(coach: coach, interactions: recentInteractions)
      metrics = CoachMetricsCalculator.metrics(for: coachId, in: recentInteractions)
      insights = CoachMetricsCalculator.insights(for: coachId, in: recentInteractions)
      logger.info("Loaded \(self.recentInteractions.count) interactions for coach")
    } catch {
      logger.error("Failed to load details: \(error.localizedDescription)")
      errorMessage = "Failed to load coach details"
    }

    // Cross-coach ranking needs the school's other coaches' interactions too.
    // Best-effort: a failure here just hides the ranking line, never the page.
    let schoolId = coach.schoolId
    do {
      let schoolInteractions = try await coachesService.fetchInteractions(
        schoolId: schoolId,
        limit: Self.interactionsFetchLimit
      )
      comparison = CoachMetricsCalculator.comparison(
        for: coachId,
        schoolId: schoolId,
        interactions: schoolInteractions,
        coaches: allCoaches
      )
    } catch {
      logger.debug("School-wide interactions unavailable for ranking: \(error.localizedDescription)")
    }
  }

  /// Interactions after the log filters, newest-first.
  var filteredInteractions: [Interaction] {
    recentInteractions.filter { interaction in
      if let filterType, interaction.type != filterType { return false }
      if let filterDirection, interaction.direction != filterDirection { return false }
      if let filterSentiment, interaction.sentiment != filterSentiment { return false }
      if let filterWindowDays {
        let cutoff = Calendar.current.date(byAdding: .day, value: -filterWindowDays, to: .now) ?? .now
        if interaction.displayDate < cutoff { return false }
      }
      return true
    }
  }

  var hasActiveFilters: Bool {
    filterType != nil || filterDirection != nil || filterSentiment != nil || filterWindowDays != nil
  }

  func clearFilters() {
    filterType = nil
    filterDirection = nil
    filterSentiment = nil
    filterWindowDays = nil
  }

  // MARK: - Social-DM return-confirmation

  /// Arm the prompt when the user opens a Twitter/Instagram profile. Fired on
  /// return to foreground by the view; resolved via confirm/dismiss.
  func armSocialDM(_ channel: SocialChannel) {
    guard let coach else { return }
    pendingSocialDM = PendingSocialDM(channel: channel, coachId: coach.id, coachName: coach.fullName)
  }

  /// User confirmed they sent the DM → log an outbound direct-message interaction,
  /// reload so insights/days-since update, and clear the prompt.
  func confirmSocialDM() async {
    guard let pending = pendingSocialDM, let coach,
          let userId = authManager.user?.id,
          let familyUnitId = allSchools.first(where: { $0.id == coach.schoolId })?.familyUnitId else {
      pendingSocialDM = nil
      return
    }
    let subject = pending.channel == .twitter ? "Twitter DM" : "Instagram DM"
    let request = InteractionCreateRequest(
      schoolId: coach.schoolId, coachId: coach.id, type: .directMessage, direction: .outbound,
      occurredAt: .now, subject: subject, content: nil, sentiment: nil,
      loggedBy: userId, familyUnitId: familyUnitId)
    do {
      _ = try await interactionsService.createInteraction(request)
      pendingSocialDM = nil
      await loadDetails()
    } catch {
      logger.error("Failed to log social DM: \(error.localizedDescription)")
      errorMessage = "Failed to log message"
      pendingSocialDM = nil
    }
  }

  /// User dismissed the prompt (or said No) → clear without writing.
  func dismissSocialDM() {
    pendingSocialDM = nil
  }

  // MARK: - Tags

  /// Persist coach tags (sanitized to the 20/40 caps), updating the loaded coach.
  func saveTags(_ tags: [String]) async {
    guard let coachId = coach?.id else { return }
    let sanitized = CoachTagsValidator.sanitize(tags)
    do {
      let updated = try await coachesService.updateCoach(id: coachId, updates: CoachUpdateRequest(tags: sanitized))
      coach = updated
      await invalidateCoachCache()
      logger.info("Coach tags updated (\(sanitized.count))")
    } catch {
      logger.error("Failed to update tags: \(error.localizedDescription)")
      errorMessage = "Failed to save tags"
    }
  }

  private func computeStats() -> CoachStats {
    let totalInteractions = recentInteractions.count

    let daysSinceContact: Int? = {
      let calendar = Calendar.current
      // Prefer the newest logged interaction so the number is correct in-session
      // without waiting on the DB `last_contact_date` trigger or a coach refetch.
      // Filter nil-`occurredAt` rows first: `Interaction.displayDate` defaults to
      // `.now`, which would otherwise masquerade a dateless row as "today".
      let latestInteraction = recentInteractions
        .filter { $0.occurredAt != nil }
        .map(\.displayDate)
        .max()
      if let latestInteraction {
        return calendar.dateComponents([.day], from: latestInteraction, to: .now).day
      }
      // Fallback: the stored last-contact date (kept fresh by the trigger).
      guard let lastContactDate = coach?.lastContactDateParsed else { return nil }
      return calendar.dateComponents([.day], from: lastContactDate, to: .now).day
    }()

    let preferredMethod: String? = {
      let typeCounts = Dictionary(grouping: recentInteractions, by: { $0.type })
        .mapValues { $0.count }
      return typeCounts.max(by: { $0.value < $1.value })?.key.displayName
    }()

    return CoachStats(
      totalInteractions: totalInteractions,
      daysSinceContact: daysSinceContact,
      preferredMethod: preferredMethod
    )
  }

  // MARK: - Editing

  func startEditing() {
    guard let coach else { return }
    editedCoach = EditableCoach(from: coach)
    validationErrors = [:]
    isEditing = true
  }

  func cancelEditing() {
    editedCoach = nil
    validationErrors = [:]
    isEditing = false
  }

  func saveChanges() async {
    guard let edited = editedCoach, let coachId = coach?.id else { return }

    // Validate
    validationErrors = validateEdits(edited)
    if !validationErrors.isEmpty {
      logger.warning("Validation failed: \(self.validationErrors)")
      return
    }

    isSaving = true
    defer { isSaving = false }

    do {
      let request = edited.toUpdateRequest()
      let updated = try await coachesService.updateCoach(id: coachId, updates: request)
      coach = updated
      await invalidateCoachCache()
      isEditing = false
      editedCoach = nil
      logger.info("Coach updated successfully")
    } catch {
      logger.error("Failed to update coach: \(error.localizedDescription)")
      errorMessage = "Failed to save changes"
    }
  }

  private func validateEdits(_ edited: EditableCoach) -> [String: String] {
    var errors: [String: String] = [:]

    // First name
    if let error = FormValidator.validateName(edited.firstName) {
      errors["firstName"] = error
    }

    // Last name
    if let error = FormValidator.validateName(edited.lastName) {
      errors["lastName"] = error
    }

    // Email (optional, but must be valid if provided)
    if !edited.email.isEmpty {
      if let error = FormValidator.validateEmail(edited.email) {
        errors["email"] = error
      }
    }

    // Twitter handle
    if edited.twitterHandle.count > 15 {
      errors["twitterHandle"] = "Twitter handle must be 15 characters or less"
    }

    // Instagram handle
    if edited.instagramHandle.count > 30 {
      errors["instagramHandle"] = "Instagram handle must be 30 characters or less"
    }

    // Notes
    if edited.notes.count > 5000 {
      errors["notes"] = "Notes must be 5000 characters or less"
    }

    return errors
  }

  // MARK: - Notes

  private func initializeNoteFields(from coach: Coach) {
    editedSharedNotes = coach.notes ?? ""
  }

  private func markSaved() {
    saveStatus = .saved
    hapticSuccessTrigger += 1
    pendingStatusReset?.cancel()
    pendingStatusReset = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      if self.saveStatus == .saved { self.saveStatus = .idle }
    }
  }

  func saveSharedNotes() async {
    guard let coachId = coach?.id else { return }
    saveStatus = .saving

    do {
      let sanitized = DataSanitizer.stripHtmlTags(editedSharedNotes.trimmingCharacters(in: .whitespacesAndNewlines))
      let request = CoachUpdateRequest(
        firstName: nil, lastName: nil, email: nil, phone: nil,
        position: nil, twitterHandle: nil, instagramHandle: nil,
        notes: DataSanitizer.nilIfEmpty(sanitized),
        nextContactDate: nil, followUpThresholdDays: nil
      )
      let updated = try await coachesService.updateCoach(id: coachId, updates: request)
      coach = updated
      await invalidateCoachCache()
      markSaved()
      logger.info("Shared notes updated successfully")
    } catch {
      logger.error("Failed to update shared notes: \(error.localizedDescription)")
      errorMessage = "Failed to save notes"
      saveStatus = .idle
    }
  }

  // MARK: - Delete

  func confirmDelete() {
    showDeleteConfirmation = true
  }

  func deleteCoach() async {
    guard let coach else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      // Try simple delete first (fast path)
      try await coachesService.deleteCoach(id: coach.id)
      await invalidateCoachCache()
      deleteSuccessMessage = "Coach deleted"
      logger.info("Coach deleted successfully")
    } catch {
      // If FK constraint error, fallback to cascade delete
      if isForeignKeyViolation(error) {
        do {
          let result = try await coachesService.cascadeDeleteCoach(id: coach.id)
          await invalidateCoachCache()
          deleteSuccessMessage = "Coach and \(result.deletedInteractions) interactions deleted"
          logger.info("Cascade delete successful: \(result.deletedInteractions) interactions deleted")
        } catch {
          logger.error("Cascade delete failed: \(error.localizedDescription)")
          errorMessage = "Failed to delete coach. Please try again."
        }
      } else {
        logger.error("Delete failed: \(error.localizedDescription)")
        errorMessage = "Failed to delete coach. Please try again."
      }
    }
  }

  nonisolated deinit {
    pendingStatusReset?.cancel()
  }
}
