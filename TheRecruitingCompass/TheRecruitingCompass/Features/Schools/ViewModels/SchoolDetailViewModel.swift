import Observation
import Foundation
import OSLog
import SwiftUI
import CoreLocation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolDetailViewModel")

@Observable
@MainActor
final class SchoolDetailViewModel {

  var school: School?
  var isLoading = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  /// Suppressed while the delete confirmation dialog is up so the two don't overlap.
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil && !showDeleteConfirmation }
    set {
      if !newValue {
        errorMessage = nil
      }
    }
  }

  // Status management
  var statusHistory: [SchoolStatusHistory] = []
  var isUpdatingStatus = false

  // MARK: - Notes (always-editable, auto-save on blur)
  var editedNotes = ""
  var saveStatus: SaveStatus = .idle
  var hapticSuccessTrigger = 0

  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

  // MARK: - Pros & Cons
  var newPro = ""
  var newCon = ""
  var isAddingPro = false
  var isAddingCon = false

  // MARK: - Basic Info
  var isEditingBasicInfo = false
  var editedBasicInfo = EditableBasicInfo()
  var isSavingBasicInfo = false

  // MARK: - Personal Fit
  private(set) var personalFit: PersonalFitAnalysis?
  private var athleteProfile: PlayerDetails?

  // MARK: - College Scorecard
  var isLookingUpCollegeData = false
  var collegeDataError: String?

  // MARK: - Home Location (for distance)
  private(set) var homeCoordinate: CLLocationCoordinate2D?

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

  // Dependencies
  private let schoolId: String
  private let schoolsService: any SchoolsManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager
  private let collegeService: any CollegeScorecardManaging
  private let coachesService: any CoachesManaging
  private let preferenceService: any PreferenceManaging
  private let cache: (any CacheManaging)?

  /// TTL for cached school and status history (seconds).
  private static let schoolCacheTTL: TimeInterval = 60

  init(
    schoolId: String,
    schoolsService: (any SchoolsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil,
    collegeService: (any CollegeScorecardManaging)? = nil,
    coachesService: (any CoachesManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.schoolId = schoolId
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: SupabaseManager.shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? .shared
    self.collegeService = collegeService ?? CollegeScorecardService()
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: SupabaseManager.shared)
    self.preferenceService = preferenceService
      ?? PreferenceServiceImpl(supabaseManager: SupabaseManager.shared)
    self.cache = cache
  }

  // MARK: - Helper Methods

  // MARK: - Computed Properties

  var currentUserId: String? {
    authManager.user?.id
  }

  var hasCoaches: Bool {
    !coaches.isEmpty
  }

  var canLookupCollegeData: Bool {
    school != nil && !isLookingUpCollegeData
  }

  var isEditingAnything: Bool {
    isEditingBasicInfo ||
    isEditingCoachingPhilosophy
  }

  // MARK: - Loading

  func loadSchool() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    guard let familyId = familyManager.familyUnitId else {
      errorMessage = String(localized: "No active family")
      logger.warning("Cannot load school: no active family")
      return
    }

    let cacheKey = "school:\(schoolId)"
    let historyKey = "school:\(schoolId):history"
    let cacheToUse = cache ?? InMemoryCache.shared

    // Try cache first
    if let cachedSchool = await cacheToUse.get(School.self, forKey: cacheKey),
       let cachedHistory = await cacheToUse.get([SchoolStatusHistory].self, forKey: historyKey) {
      school = cachedSchool
      statusHistory = cachedHistory
      initializeNoteFields(from: cachedSchool)
      logger.info("Loaded school from cache: \(cachedSchool.name)")
      await loadPersonalFit()
      await loadCoaches()
      return
    }

    do {
      async let schoolData = schoolsService.fetchSchool(id: schoolId, familyUnitId: familyId)
      async let historyData = schoolsService.fetchStatusHistory(schoolId: schoolId)

      let loadedSchool = try await schoolData
      let loadedHistory = try await historyData
      school = loadedSchool
      statusHistory = loadedHistory
      initializeNoteFields(from: loadedSchool)

      await cacheToUse.set(loadedSchool, forKey: cacheKey, ttlSeconds: Self.schoolCacheTTL)
      await cacheToUse.set(loadedHistory, forKey: historyKey, ttlSeconds: Self.schoolCacheTTL)

      logger.info("Loaded school: \(loadedSchool.name)")
      await loadPersonalFit()
      await loadCoaches()

    } catch {
      logger.error("Failed to load school \(self.schoolId): \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load school details. Please try again.")
    }
  }

  /// Loads the player's home coordinate from user_preferences (category `location`),
  /// the same store the web app and the Home Location settings screen use.
  /// Silent on failure: a preferences fetch error must not block the detail view —
  /// distance simply won't show.
  func loadHomeLocation() async {
    do {
      if let location: HomeLocation = try await preferenceService.fetchPreferences(category: .location, userId: familyManager.selectedAthlete?.userId),
         let lat = location.latitude,
         let lon = location.longitude {
        homeCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
      } else {
        homeCoordinate = nil
      }
    } catch {
      logger.debug("Could not load home location: \(error.localizedDescription)")
      homeCoordinate = nil
    }
  }

  /// Invalidates cached school and history so the next load refetches, plus
  /// SchoolsListViewModel's cached list (Phase 3.6) so an edited field (status,
  /// favorite, etc.) shows correctly on next visit to the list screen instead
  /// of waiting out the list cache's TTL. Call after any mutation.
  private func invalidateSchoolCache() async {
    let cacheKey = "school:\(schoolId)"
    let historyKey = "school:\(schoolId):history"
    let cacheToUse = cache ?? InMemoryCache.shared
    await cacheToUse.remove(forKey: cacheKey)
    await cacheToUse.remove(forKey: historyKey)
    if let familyUnitId = familyManager.familyUnitId {
      await cacheToUse.remove(forKey: ListCacheKeys.schools(familyUnitId: familyUnitId))
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
      await invalidateSchoolCache()
      logger.info("Status updated to \(newStatus.displayName)")
    } catch {
      errorMessage = String(localized: "Failed to update status")
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
      await invalidateSchoolCache()
      logger.info("Favorite toggled to \(newValue)")
    } catch {
      // Revert on error
      self.school = school.with(isFavorite: !newValue)
      errorMessage = String(localized: "Failed to update favorite")
      logger.error("Failed to toggle favorite: \(error.localizedDescription)")
    }
  }

  // MARK: - Notes

  private func initializeNoteFields(from school: School) {
    editedNotes = school.notes ?? ""
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

  func saveNotes() async {
    let sanitized = DataSanitizer.stripHtmlTags(editedNotes.trimmingCharacters(in: .whitespacesAndNewlines))
    saveStatus = .saving
    do {
      let updated = try await schoolsService.updateNotes(id: schoolId, notes: sanitized)
      school = updated
      await invalidateSchoolCache()
      markSaved()
      logger.info("Notes saved successfully")
    } catch {
      ViewModelHelpers.handleError(error, userMessage: String(localized: "Failed to save notes"), logger: logger) { self.errorMessage = $0 }
      saveStatus = .idle
    }
  }

  // MARK: - Pros & Cons

  func addPro() async {
    guard !newPro.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = String(localized: "No active family")
      return
    }

    let sanitizedText = DataSanitizer.stripHtmlTags(newPro.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !sanitizedText.isEmpty else { return }

    await ViewModelHelpers.withLoading(set: { self.isAddingPro = $0 }) {
      do {
        let updated = try await schoolsService.addPro(id: schoolId, familyUnitId: familyId, text: sanitizedText)
        school = updated
        newPro = ""
        await invalidateSchoolCache()
        logger.info("Pro added successfully")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: String(localized: "Failed to add pro"), logger: logger) { self.errorMessage = $0 }
      }
    }
  }

  func removePro(at index: Int) async {
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = String(localized: "No active family")
      return
    }

    do {
      let updated = try await schoolsService.removePro(id: schoolId, familyUnitId: familyId, index: index)
      school = updated
      await invalidateSchoolCache()
      logger.info("Pro removed successfully")
    } catch {
      errorMessage = String(localized: "Failed to remove pro")
      logger.error("Failed to remove pro: \(error.localizedDescription)")
    }
  }

  func addCon() async {
    guard !newCon.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = String(localized: "No active family")
      return
    }

    let sanitizedText = DataSanitizer.stripHtmlTags(newCon.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !sanitizedText.isEmpty else { return }

    await ViewModelHelpers.withLoading(set: { self.isAddingCon = $0 }) {
      do {
        let updated = try await schoolsService.addCon(id: schoolId, familyUnitId: familyId, text: sanitizedText)
        school = updated
        newCon = ""
        await invalidateSchoolCache()
        logger.info("Con added successfully")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: String(localized: "Failed to add con"), logger: logger) { self.errorMessage = $0 }
      }
    }
  }

  func removeCon(at index: Int) async {
    guard let familyId = familyManager.familyUnitId else {
      errorMessage = String(localized: "No active family")
      return
    }

    do {
      let updated = try await schoolsService.removeCon(id: schoolId, familyUnitId: familyId, index: index)
      school = updated
      await invalidateSchoolCache()
      logger.info("Con removed successfully")
    } catch {
      errorMessage = String(localized: "Failed to remove con")
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
    await ViewModelHelpers.withLoading(set: { self.isSavingBasicInfo = $0 }) {
      do {
        let updated = try await schoolsService.updateBasicInfo(
          id: schoolId,
          info: editedBasicInfo
        )
        school = updated
        isEditingBasicInfo = false
        await invalidateSchoolCache()
        logger.info("Basic info saved successfully")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: String(localized: "Failed to save information"), logger: logger) { self.errorMessage = $0 }
      }
    }
  }

  // MARK: - Personal Fit

  /// Computes on-device Personal Fit signals from the athlete profile + school.
  /// Signals are transparent comparisons — never an invented composite score.
  func loadPersonalFit() async {
    if athleteProfile == nil {
      athleteProfile = try? await preferenceService.fetchPreferences(
        category: .player, userId: familyManager.selectedAthlete?.userId)
    }
    guard let school else { personalFit = nil; return }
    personalFit = PersonalFitCalculator.calculate(athlete: athleteProfile, school: school)
  }

  // MARK: - College Scorecard Lookup

  func lookupCollegeData() async {
    guard let schoolName = school?.name else { return }

    isLookingUpCollegeData = true
    collegeDataError = nil
    defer { isLookingUpCollegeData = false }

    do {
      guard let data = try await collegeService.lookupCollege(name: schoolName) else {
        collegeDataError = String(localized: "School not found in database")
        logger.warning("College not found: \(schoolName)")
        return
      }

      logger.info("Found college data: \(data.name)")

      // Merge data into school's academic_info
      let updated = try await schoolsService.mergeCollegeData(id: schoolId, data: data)
      self.school = updated
      await loadPersonalFit()
      await invalidateSchoolCache()
      collegeDataError = nil
      logger.info("College data merged successfully")

    } catch let error as CollegeDataError {
      collegeDataError = error.errorDescription
      logger.error("College data error: \(error.errorDescription ?? "unknown")")
    } catch {
      collegeDataError = String(localized: "Failed to lookup college data")
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
    await ViewModelHelpers.withLoading(set: { self.isSavingCoachingPhilosophy = $0 }) {
      do {
        let updated = try await schoolsService.updateCoachingPhilosophy(
          id: schoolId,
          philosophy: editedCoachingPhilosophy
        )
        school = updated
        isEditingCoachingPhilosophy = false
        await invalidateSchoolCache()
        logger.info("Coaching philosophy saved successfully")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: String(localized: "Failed to save coaching philosophy"), logger: logger) { self.errorMessage = $0 }
      }
    }
  }

  // MARK: - Delete

  func confirmDelete() {
    showDeleteConfirmation = true
  }

  @discardableResult
  func deleteSchool() async -> Bool {
    isDeleting = true
    deleteErrorMessage = nil
    defer {
      isDeleting = false
      showDeleteConfirmation = false
    }

    do {
      try await performDelete()
      return true
    } catch {
      let errorMsg = String(localized: "Failed to delete school. Please try again.")
      deleteErrorMessage = errorMsg
      logger.error("Delete failed: \(error.localizedDescription)")
      return false
    }
  }

  private func performDelete() async throws {
    do {
      try await schoolsService.deleteSchool(id: schoolId)
      await invalidateSchoolCache()
      logger.info("School deleted successfully (simple delete)")
    } catch {
      logger.warning("Simple delete failed, attempting cascade delete: \(error.localizedDescription)")
      let result = try await schoolsService.cascadeDeleteSchool(id: schoolId)
      await invalidateSchoolCache()
      let totalDeleted = result.deletedInteractions + result.deletedNotes
      logger.info("School deleted successfully (cascade delete: \(totalDeleted) related items)")
    }
  }

  nonisolated deinit {
    pendingStatusReset?.cancel()
  }
}
