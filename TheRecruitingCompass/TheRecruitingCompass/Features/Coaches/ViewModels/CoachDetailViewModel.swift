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

  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

  private let coachId: String
  private let coachesService: any CoachesManaging
  private let authManager: any AuthManaging
  private let allCoaches: [Coach]
  private let allSchools: [School]
  private let cache: (any CacheManaging)?

  /// TTL for cached coach (seconds).
  private static let coachCacheTTL: TimeInterval = 60

  init(
    coachId: String,
    allCoaches: [Coach] = [],
    allSchools: [School] = [],
    coachesService: (any CoachesManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
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

  /// Invalidates cached coach so the next load refetches. Call after any mutation.
  private func invalidateCoachCache() async {
    let cacheKey = "coach:\(coachId)"
    let cacheToUse = cache ?? InMemoryCache.shared
    await cacheToUse.remove(forKey: cacheKey)
  }

  func loadDetails() async {
    guard coach != nil else { return }

    do {
      recentInteractions = try await coachesService.fetchInteractions(coachId: coachId, limit: 10)
      stats = computeStats()
      logger.info("Loaded \(self.recentInteractions.count) interactions for coach")
    } catch {
      logger.error("Failed to load details: \(error.localizedDescription)")
      errorMessage = "Failed to load coach details"
    }
  }

  private func computeStats() -> CoachStats {
    let totalInteractions = recentInteractions.count

    let daysSinceContact: Int? = {
      guard let lastContactDate = coach?.lastContactDateParsed else { return nil }
      let calendar = Calendar.current
      let days = calendar.dateComponents([.day], from: lastContactDate, to: Date()).day
      return days
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
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
      if error.localizedDescription.contains("foreign key") {
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
