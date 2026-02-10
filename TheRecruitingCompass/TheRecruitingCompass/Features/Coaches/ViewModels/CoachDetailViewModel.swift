import Combine
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachDetailViewModel")

@MainActor
final class CoachDetailViewModel: ObservableObject {
  @Published var coach: Coach?
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  // Interactions and stats
  @Published var recentInteractions: [Interaction] = []
  @Published var stats: CoachStats?

  // Editing state
  @Published var isEditing = false
  @Published var editedCoach: EditableCoach?
  @Published var isSaving = false
  @Published var validationErrors: [String: String] = [:]

  // Delete state
  @Published var showDeleteConfirmation = false
  @Published var isDeleting = false
  @Published var deleteSuccessMessage: String?

  // Notes editing
  @Published var isEditingSharedNotes = false
  @Published var editedSharedNotes = ""
  @Published var isEditingPrivateNotes = false
  @Published var editedPrivateNotes = ""

  private let coachId: String
  private let coachesService: any CoachesManaging
  private let authManager: any AuthManaging
  private let allCoaches: [Coach]
  private let allSchools: [School]

  nonisolated init(
    coachId: String,
    allCoaches: [Coach] = [],
    allSchools: [School] = [],
    coachesService: any CoachesManaging = CoachesServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared
  ) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    self.coachesService = coachesService
    self.authManager = authManager
  }

  // MARK: - Computed Properties

  var currentUserId: String {
    authManager.user?.id ?? ""
  }

  var privateNoteForCurrentUser: String? {
    coach?.privateNote(for: currentUserId)
  }

  // MARK: - Loading

  func loadCoach() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    // For now, use the passed-in coaches array since we don't have fetchCoach(id:) API yet
    if let foundCoach = allCoaches.first(where: { $0.id == coachId }) {
      coach = foundCoach
      if let foundSchool = allSchools.first(where: { $0.id == foundCoach.schoolId }) {
        school = foundSchool
      }
      logger.info("Loaded coach from cache: \(foundCoach.fullName)")
    } else {
      errorMessage = "Coach not found"
      logger.warning("Coach not found with ID: \(self.coachId)")
    }
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

  // MARK: - Shared Notes

  func startEditingSharedNotes() {
    editedSharedNotes = coach?.notes ?? ""
    isEditingSharedNotes = true
  }

  func cancelEditingSharedNotes() {
    editedSharedNotes = ""
    isEditingSharedNotes = false
  }

  func saveSharedNotes() async {
    guard let coachId = coach?.id else { return }

    isSaving = true
    defer { isSaving = false }

    do {
      let request = CoachUpdateRequest(
        firstName: nil, lastName: nil, email: nil, phone: nil,
        position: nil, twitterHandle: nil, instagramHandle: nil,
        notes: editedSharedNotes.isEmpty ? nil : editedSharedNotes,
        privateNotes: nil
      )
      let updated = try await coachesService.updateCoach(id: coachId, updates: request)
      coach = updated
      isEditingSharedNotes = false
      logger.info("Shared notes updated successfully")
    } catch {
      logger.error("Failed to update shared notes: \(error.localizedDescription)")
      errorMessage = "Failed to save notes"
    }
  }

  // MARK: - Private Notes

  func startEditingPrivateNotes() {
    editedPrivateNotes = privateNoteForCurrentUser ?? ""
    isEditingPrivateNotes = true
  }

  func cancelEditingPrivateNotes() {
    editedPrivateNotes = ""
    isEditingPrivateNotes = false
  }

  func savePrivateNotes() async {
    guard let coachId = coach?.id else { return }

    isSaving = true
    defer { isSaving = false }

    do {
      // CRITICAL: Merge with existing privateNotes to preserve other users' notes
      var privateNotes = coach?.privateNotes ?? [:]
      if editedPrivateNotes.isEmpty {
        privateNotes.removeValue(forKey: currentUserId)
      } else {
        privateNotes[currentUserId] = editedPrivateNotes
      }

      let request = CoachUpdateRequest(
        firstName: nil, lastName: nil, email: nil, phone: nil,
        position: nil, twitterHandle: nil, instagramHandle: nil,
        notes: nil, privateNotes: privateNotes
      )
      let updated = try await coachesService.updateCoach(id: coachId, updates: request)
      coach = updated
      isEditingPrivateNotes = false
      logger.info("Private notes updated successfully")
    } catch {
      logger.error("Failed to update private notes: \(error.localizedDescription)")
      errorMessage = "Failed to save private notes"
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
      deleteSuccessMessage = "Coach deleted"
      logger.info("Coach deleted successfully")
    } catch {
      // If FK constraint error, fallback to cascade delete
      if error.localizedDescription.contains("foreign key") {
        do {
          let result = try await coachesService.cascadeDeleteCoach(id: coach.id)
          deleteSuccessMessage = "Coach and \(result.deletedInteractions) interactions deleted"
          logger.info("Cascade delete successful: \(result.deletedInteractions) interactions deleted")
        } catch {
          logger.error("Cascade delete failed: \(error.localizedDescription)")
          errorMessage = error.localizedDescription
        }
      } else {
        logger.error("Delete failed: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
      }
    }
  }
}
