import Observation
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolDetailViewModel")

@Observable
@MainActor
final class SchoolDetailViewModel {
  var school: School?
  var isLoading = false
  var errorMessage: String?
  var activeAlert: AlertType?

  // Status management
  var statusHistory: [SchoolStatusHistory] = []
  var isUpdatingStatus = false

  // MARK: - Notes
  var isEditingNotes = false
  var editedNotes = ""
  var isSavingNotes = false

  // MARK: - Private Notes
  var isEditingPrivateNotes = false
  var editedPrivateNotes = ""
  var isSavingPrivateNotes = false

  // MARK: - Pros & Cons
  var newPro = ""
  var newCon = ""
  var isAddingPro = false
  var isAddingCon = false

  // MARK: - Basic Info
  var isEditingBasicInfo = false
  var editedBasicInfo = EditableBasicInfo()
  var isSavingBasicInfo = false

  // MARK: - Fit Score
  var fitScore: FitScoreResult?
  var divisionRecommendation: DivisionRecommendation?
  var isLoadingFitScore = false

  // MARK: - College Scorecard
  var isLookingUpCollegeData = false
  var collegeDataError: String?

  // MARK: - Coaches
  var coaches: [Coach] = []
  var isLoadingCoaches = false

  // MARK: - Coaching Philosophy
  var isEditingCoachingPhilosophy = false
  var editedCoachingPhilosophy = EditableCoachingPhilosophy()
  var isSavingCoachingPhilosophy = false

  // MARK: - Delete
  var showDeleteConfirmation = false
  var isDeleting = false
  var deleteErrorMessage: String?

  // MARK: - Priority Tier
  var isUpdatingPriorityTier = false

  // Dependencies
  private let schoolId: String
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager
  private let fitScoreService: any FitScoreManaging
  private let collegeService: any CollegeScorecardManaging
  private let coachesService: any CoachesManaging

  nonisolated init(
    schoolId: String,
    schoolsService: any SchoolsManaging = SchoolsServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared,
    familyManager: FamilyManager = .shared,
    fitScoreService: any FitScoreManaging = FitScoreService(),
    collegeService: any CollegeScorecardManaging = CollegeScorecardService(),
    coachesService: any CoachesManaging = CoachesServiceImpl(supabaseManager: .shared)
  ) {
    self.schoolId = schoolId
    self.schoolsService = schoolsService
    self.authManager = authManager
    self.familyManager = familyManager
    self.fitScoreService = fitScoreService
    self.collegeService = collegeService
    self.coachesService = coachesService
  }

  // MARK: - Helper Methods

  /// Consolidated error handling
  private func handleError(
    _ error: Error,
    userMessage: String,
    file: String = #file,
    function: String = #function
  ) {
    errorMessage = userMessage
    activeAlert = .error(userMessage)
    let fileName = (file as NSString).lastPathComponent
    logger.error("[\(fileName):\(function)] \(error.localizedDescription)")
  }

  /// Execute async operation with loading state management
  @discardableResult
  private func withLoading<T>(
    setting flag: ReferenceWritableKeyPath<SchoolDetailViewModel, Bool>,
    operation: () async throws -> T
  ) async rethrows -> T {
    self[keyPath: flag] = true
    defer { self[keyPath: flag] = false }
    return try await operation()
  }

  // MARK: - Computed Properties

  var currentUserId: String? {
    authManager.user?.id
  }

  var privateNoteForCurrentUser: String {
    guard let userId = currentUserId else { return "" }
    return school?.privateNote(for: userId) ?? ""
  }

  var hasCoaches: Bool {
    !coaches.isEmpty
  }

  var canLookupCollegeData: Bool {
    school != nil && !isLookingUpCollegeData
  }

  var isEditingAnything: Bool {
    isEditingNotes ||
    isEditingPrivateNotes ||
    isEditingBasicInfo ||
    isEditingCoachingPhilosophy
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

      // Load fit score and coaches in parallel (non-critical, don't block on failure)
      await loadFitScore()
      await loadCoaches()

    } catch {
      errorMessage = "Failed to load school: \(error.localizedDescription)"
      logger.error("Failed to load school: \(error.localizedDescription)")
    }
  }

  // MARK: - Status Update

  func updateStatus(to newStatus: SchoolStatus) async {
    guard let school, let currentUserId else { return }

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

    await withLoading(setting: \.isSavingNotes) {
      do {
        let updated = try await schoolsService.updateNotes(id: schoolId, notes: editedNotes)
        school = updated
        isEditingNotes = false
        logger.info("Notes saved successfully")
      } catch {
        handleError(error, userMessage: "Failed to save notes")
      }
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
    guard let userId = currentUserId else {
      errorMessage = "You must be signed in"
      return
    }

    await withLoading(setting: \.isSavingPrivateNotes) {
      do {
        let note = editedPrivateNotes.isEmpty ? nil : editedPrivateNotes
        let updated = try await schoolsService.updatePrivateNotes(
          id: schoolId,
          familyUnitId: familyId,
          userId: userId,
          note: note
        )
        school = updated
        isEditingPrivateNotes = false
        logger.info("Private notes saved successfully")
      } catch {
        handleError(error, userMessage: "Failed to save private notes")
      }
    }
  }

  // MARK: - Pros & Cons

  func addPro() async {
    guard !newPro.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = "No active family"
      return
    }

    await withLoading(setting: \.isAddingPro) {
      do {
        let updated = try await schoolsService.addPro(id: schoolId, familyUnitId: familyId, text: newPro)
        school = updated
        newPro = ""
        logger.info("Pro added successfully")
      } catch {
        handleError(error, userMessage: "Failed to add pro")
      }
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

    await withLoading(setting: \.isAddingCon) {
      do {
        let updated = try await schoolsService.addCon(id: schoolId, familyUnitId: familyId, text: newCon)
        school = updated
        newCon = ""
        logger.info("Con added successfully")
      } catch {
        handleError(error, userMessage: "Failed to add con")
      }
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
    await withLoading(setting: \.isSavingBasicInfo) {
      do {
        let updated = try await schoolsService.updateBasicInfo(
          id: schoolId,
          info: editedBasicInfo
        )
        school = updated
        isEditingBasicInfo = false
        logger.info("Basic info saved successfully")
      } catch {
        handleError(error, userMessage: "Failed to save information")
      }
    }
  }

  // MARK: - Fit Score

  func loadFitScore() async {
    isLoadingFitScore = true
    defer { isLoadingFitScore = false }

    do {
      let result = try await fitScoreService.calculateFitScore(schoolId: schoolId)
      self.fitScore = result

      self.divisionRecommendation = fitScoreService.getDivisionRecommendations(
        division: school?.division,
        fitScore: result.score
      )

      logger.info("Fit score loaded: \(result.score)")
    } catch {
      // Non-critical - just hide section if calculation fails
      logger.error("Failed to load fit score: \(error.localizedDescription)")
    }
  }

  // MARK: - College Scorecard Lookup

  func lookupCollegeData() async {
    guard let schoolName = school?.name else { return }

    isLookingUpCollegeData = true
    collegeDataError = nil
    defer { isLookingUpCollegeData = false }

    do {
      guard let data = try await collegeService.lookupCollege(name: schoolName) else {
        collegeDataError = "School not found in database"
        logger.warning("College not found: \(schoolName)")
        return
      }

      logger.info("Found college data: \(data.name)")

      // Merge data into school's academic_info
      let updated = try await schoolsService.mergeCollegeData(id: schoolId, data: data)
      self.school = updated

      collegeDataError = nil
      logger.info("College data merged successfully")

    } catch let error as CollegeDataError {
      collegeDataError = error.errorDescription
      logger.error("College data error: \(error.errorDescription ?? "unknown")")
    } catch {
      collegeDataError = "Failed to lookup college data"
      logger.error("Failed to lookup college data: \(error.localizedDescription)")
    }
  }

  // MARK: - Coaches

  func loadCoaches() async {
    isLoadingCoaches = true
    defer { isLoadingCoaches = false }

    do {
      self.coaches = try await coachesService.fetchCoaches(schoolIds: [schoolId])
      logger.info("Loaded \(self.coaches.count) coaches for school")
    } catch {
      // Non-critical - just show empty state
      logger.error("Failed to load coaches: \(error.localizedDescription)")
    }
  }

  // MARK: - Coaching Philosophy

  func startEditingCoachingPhilosophy() {
    guard let school else { return }
    editedCoachingPhilosophy = EditableCoachingPhilosophy.from(school: school)
    isEditingCoachingPhilosophy = true
  }

  func cancelEditingCoachingPhilosophy() {
    editedCoachingPhilosophy = EditableCoachingPhilosophy()
    isEditingCoachingPhilosophy = false
  }

  func saveCoachingPhilosophy() async {
    await withLoading(setting: \.isSavingCoachingPhilosophy) {
      do {
        let updated = try await schoolsService.updateCoachingPhilosophy(
          id: schoolId,
          philosophy: editedCoachingPhilosophy
        )
        school = updated
        isEditingCoachingPhilosophy = false
        logger.info("Coaching philosophy saved successfully")
      } catch {
        handleError(error, userMessage: "Failed to save coaching philosophy")
      }
    }
  }

  // MARK: - Delete

  func confirmDelete() {
    showDeleteConfirmation = true
    activeAlert = .deleteConfirmation
  }

  func deleteSchool(onSuccess: @escaping () -> Void) async {
    isDeleting = true
    deleteErrorMessage = nil
    defer {
      isDeleting = false
      showDeleteConfirmation = false
    }

    do {
      try await performDelete()
      onSuccess()
    } catch {
      let errorMsg = "Failed to delete school. Please try again."
      deleteErrorMessage = errorMsg
      activeAlert = .deleteError(errorMsg)
      logger.error("Delete failed: \(error.localizedDescription)")
    }
  }

  private func performDelete() async throws {
    do {
      try await schoolsService.deleteSchool(id: schoolId)
      logger.info("School deleted successfully (simple delete)")
    } catch {
      logger.warning("Simple delete failed, attempting cascade delete: \(error.localizedDescription)")
      let result = try await schoolsService.cascadeDeleteSchool(id: schoolId)
      let totalDeleted = result.deletedInteractions + result.deletedNotes
      logger.info("School deleted successfully (cascade delete: \(totalDeleted) related items)")
    }
  }

  // MARK: - Priority Tier Update

  func updatePriorityTier(_ tier: PriorityTier?) async {
    await withLoading(setting: \.isUpdatingPriorityTier) {
      do {
        let updated = try await schoolsService.updatePriorityTier(id: schoolId, tier: tier)
        school = updated
        logger.info("Priority tier updated to \(tier?.rawValue ?? "none")")
      } catch {
        handleError(error, userMessage: "Failed to update priority tier")
      }
    }
  }
}
