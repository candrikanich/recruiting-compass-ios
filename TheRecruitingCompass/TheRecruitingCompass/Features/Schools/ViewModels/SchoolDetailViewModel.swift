import Combine
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolDetailViewModel")

@MainActor
final class SchoolDetailViewModel: ObservableObject {
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  // Status management
  @Published var statusHistory: [SchoolStatusHistory] = []
  @Published var isUpdatingStatus = false

  // MARK: - Phase 2: Notes Editing
  @Published var isEditingNotes = false
  @Published var editedNotes = ""
  @Published var isSavingNotes = false

  // MARK: - Phase 2: Private Notes Editing
  @Published var isEditingPrivateNotes = false
  @Published var editedPrivateNotes = ""
  @Published var isSavingPrivateNotes = false

  // MARK: - Phase 2: Pros & Cons
  @Published var newPro = ""
  @Published var newCon = ""
  @Published var isAddingPro = false
  @Published var isAddingCon = false

  // MARK: - Phase 2: Basic Info Editing
  @Published var isEditingBasicInfo = false
  @Published var editedBasicInfo = EditableBasicInfo()
  @Published var isSavingBasicInfo = false

  // Dependencies
  private let schoolId: String
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  nonisolated init(
    schoolId: String,
    schoolsService: any SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared,
    familyManager: FamilyManager = .shared
  ) {
    self.schoolId = schoolId
    self.schoolsService = schoolsService
    self.authManager = authManager
    self.familyManager = familyManager
  }

  // MARK: - Computed Properties

  var currentUserId: String {
    authManager.user?.id ?? ""
  }

  var privateNoteForCurrentUser: String {
    guard !currentUserId.isEmpty else { return "" }
    return school?.privateNote(for: currentUserId) ?? ""
  }

  // MARK: - Loading

  func loadSchool() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      logger.warning("Cannot load school: no active family")
      return
    }

    do {
      async let schoolData = schoolsService.fetchSchool(id: schoolId, familyUnitId: familyId)
      async let historyData = schoolsService.fetchStatusHistory(schoolId: schoolId)

      school = try await schoolData
      statusHistory = try await historyData

      logger.info("Loaded school: \(self.school?.name ?? "unknown")")
    } catch {
      errorMessage = "Failed to load school: \(error.localizedDescription)"
      logger.error("Failed to load school: \(error.localizedDescription)")
    }
  }

  // MARK: - Status Update

  func updateStatus(to newStatus: SchoolStatus) async {
    guard let school, !currentUserId.isEmpty else { return }

    let previousStatus = SchoolStatus(rawValue: school.status) ?? .interested
    guard newStatus != previousStatus else { return }

    isUpdatingStatus = true
    defer { isUpdatingStatus = false }

    do {
      let updated = try await schoolsService.updateStatus(
        id: schoolId,
        newStatus: newStatus,
        previousStatus: previousStatus,
        userId: currentUserId
      )
      self.school = updated

      // Refresh history
      statusHistory = try await schoolsService.fetchStatusHistory(schoolId: schoolId)
      logger.info("Status updated to \(newStatus.displayName)")
    } catch {
      errorMessage = "Failed to update status"
      logger.error("Failed to update status: \(error.localizedDescription)")
    }
  }

  // MARK: - Favorite Toggle

  func toggleFavorite() async {
    guard let school else { return }

    let newValue = !school.isFavorite

    // Optimistic update
    self.school = school.with(isFavorite: newValue)

    do {
      try await schoolsService.toggleFavorite(id: schoolId, isFavorite: newValue)
      logger.info("Favorite toggled to \(newValue)")
    } catch {
      // Revert on error
      self.school = school.with(isFavorite: !newValue)
      errorMessage = "Failed to update favorite"
      logger.error("Failed to toggle favorite: \(error.localizedDescription)")
    }
  }

  // MARK: - Notes Editing

  func startEditingNotes() {
    editedNotes = school?.notes ?? ""
    isEditingNotes = true
  }

  func cancelEditingNotes() {
    editedNotes = ""
    isEditingNotes = false
  }

  func saveNotes() async {
    guard !editedNotes.isEmpty else { return }

    isSavingNotes = true
    defer { isSavingNotes = false }

    do {
      let updated = try await schoolsService.updateNotes(id: schoolId, notes: editedNotes)
      school = updated
      isEditingNotes = false
      logger.info("Notes saved successfully")
    } catch {
      errorMessage = "Failed to save notes"
      logger.error("Failed to save notes: \(error.localizedDescription)")
    }
  }

  // MARK: - Private Notes Editing

  func startEditingPrivateNotes() {
    editedPrivateNotes = privateNoteForCurrentUser
    isEditingPrivateNotes = true
  }

  func cancelEditingPrivateNotes() {
    editedPrivateNotes = ""
    isEditingPrivateNotes = false
  }

  func savePrivateNotes() async {
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    isSavingPrivateNotes = true
    defer { isSavingPrivateNotes = false }

    do {
      let note = editedPrivateNotes.isEmpty ? nil : editedPrivateNotes
      let updated = try await schoolsService.updatePrivateNotes(
        id: schoolId,
        familyUnitId: familyId,
        userId: currentUserId,
        note: note
      )
      school = updated
      isEditingPrivateNotes = false
      logger.info("Private notes saved successfully")
    } catch {
      errorMessage = "Failed to save private notes"
      logger.error("Failed to save private notes: \(error.localizedDescription)")
    }
  }

  // MARK: - Pros & Cons

  func addPro() async {
    guard !newPro.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    isAddingPro = true
    defer { isAddingPro = false }

    do {
      let updated = try await schoolsService.addPro(id: schoolId, familyUnitId: familyId, text: newPro)
      school = updated
      newPro = ""
      logger.info("Pro added successfully")
    } catch {
      errorMessage = "Failed to add pro"
      logger.error("Failed to add pro: \(error.localizedDescription)")
    }
  }

  func removePro(at index: Int) async {
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    do {
      let updated = try await schoolsService.removePro(id: schoolId, familyUnitId: familyId, index: index)
      school = updated
      logger.info("Pro removed successfully")
    } catch {
      errorMessage = "Failed to remove pro"
      logger.error("Failed to remove pro: \(error.localizedDescription)")
    }
  }

  func addCon() async {
    guard !newCon.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    isAddingCon = true
    defer { isAddingCon = false }

    do {
      let updated = try await schoolsService.addCon(id: schoolId, familyUnitId: familyId, text: newCon)
      school = updated
      newCon = ""
      logger.info("Con added successfully")
    } catch {
      errorMessage = "Failed to add con"
      logger.error("Failed to add con: \(error.localizedDescription)")
    }
  }

  func removeCon(at index: Int) async {
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    do {
      let updated = try await schoolsService.removeCon(id: schoolId, familyUnitId: familyId, index: index)
      school = updated
      logger.info("Con removed successfully")
    } catch {
      errorMessage = "Failed to remove con"
      logger.error("Failed to remove con: \(error.localizedDescription)")
    }
  }

  // MARK: - Basic Info Editing

  func startEditingBasicInfo() {
    guard let school else { return }
    editedBasicInfo = EditableBasicInfo.from(school: school)
    isEditingBasicInfo = true
  }

  func cancelEditingBasicInfo() {
    editedBasicInfo = EditableBasicInfo()
    isEditingBasicInfo = false
  }

  func saveBasicInfo() async {
    isSavingBasicInfo = true
    defer { isSavingBasicInfo = false }

    do {
      let updated = try await schoolsService.updateBasicInfo(
        id: schoolId,
        info: editedBasicInfo
      )
      school = updated
      isEditingBasicInfo = false
      logger.info("Basic info saved successfully")
    } catch {
      errorMessage = "Failed to save information"
      logger.error("Failed to save basic info: \(error.localizedDescription)")
    }
  }
}
