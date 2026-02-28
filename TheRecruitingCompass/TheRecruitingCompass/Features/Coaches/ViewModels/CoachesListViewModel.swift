import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachesListViewModel")

@Observable
@MainActor
final class CoachesListViewModel {
  var allCoaches: [Coach] = []
  var allSchools: [School] = []
  var isLoading = false
  var errorMessage: String?
  var filters = CoachFilters()
  var showDeleteConfirmation = false
  var coachToDelete: Coach?
  var isDeleting = false
  var deleteErrorMessage: String?
  var successMessage: String?
  var showSuccessToast = false

  let coachesService: any CoachesManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  var filteredCoaches: [Coach] {
    var result = allCoaches

    if !filters.searchText.isEmpty {
      let query = filters.searchText.lowercased()
      result = result.filter { coach in
        coach.fullName.lowercased().contains(query)
          || (coach.email?.lowercased().contains(query) ?? false)
          || (coach.phone?.lowercased().contains(query) ?? false)
          || (coach.notes?.lowercased().contains(query) ?? false)
          || (coach.twitterHandle?.lowercased().contains(query) ?? false)
          || (coach.instagramHandle?.lowercased().contains(query) ?? false)
      }
    }

    if let role = filters.role {
      result = result.filter { $0.role == role }
    }

    if let days = filters.lastContactDays {
      let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
      result = result.filter { coach in
        guard let contactDate = coach.lastContactDateParsed else { return false }
        return contactDate >= cutoff
      }
    }

    if let level = filters.responsivenessLevel {
      result = result.filter { level.matches(score: $0.responsivenessScore) }
    }

    if let schoolId = filters.schoolId {
      result = result.filter { $0.schoolId == schoolId }
    }

    return sorted(result)
  }

  var schoolNameMap: [String: String] {
    EntityNameLookup.schoolNameMap(from: allSchools)
  }

  private var schoolLogoMap: [String: String?] {
    Dictionary(uniqueKeysWithValues: allSchools.map { ($0.id, $0.faviconUrl) })
  }

  private var schoolInitialsMap: [String: String] {
    Dictionary(uniqueKeysWithValues: allSchools.map { ($0.id, $0.initials) })
  }

  var activeFilterCount: Int {
    filters.activeFilterCount
  }

  var resultCount: Int {
    filteredCoaches.count
  }

  /// Summary stats for the full coach list (unfiltered), matching web app behavior.
  var analytics: CoachAnalytics {
    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

    return CoachAnalytics(
      totalCount: allCoaches.count,
      headCoachCount: allCoaches.filter { $0.role == .head }.count,
      recentContactsCount: allCoaches.filter { coach in
        guard let date = coach.lastContactDateParsed else { return false }
        return date >= sevenDaysAgo
      }.count,
      needFollowUpCount: allCoaches.filter { coach in
        guard let date = coach.lastContactDateParsed else { return true }
        return date < thirtyDaysAgo
      }.count
    )
  }

  init(
    coachesService: (any CoachesManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
  }

  func loadCoaches() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load coaches. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let schools = try await coachesService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools

      let schoolIds = schools.map(\.id)
      allCoaches = try await coachesService.fetchCoaches(schoolIds: schoolIds)

      logger.info("Loaded \(self.allCoaches.count) coaches from \(schools.count) schools")
    } catch {
      logger.error("Failed to load coaches: \(error.localizedDescription)")
      errorMessage = "Failed to load coaches. Please try again."
    }
  }

  func confirmDelete(_ coach: Coach) {
    coachToDelete = coach
    showDeleteConfirmation = true
  }

  func deleteCoach() async {
    guard let coach = coachToDelete else { return }
    let coachName = coach.fullName

    isDeleting = true
    deleteErrorMessage = nil
    successMessage = nil
    defer {
      isDeleting = false
      coachToDelete = nil
      showDeleteConfirmation = false
    }

    do {
      try await coachesService.deleteCoach(id: coach.id)
      allCoaches.removeAll { $0.id == coach.id }
      logger.info("Deleted coach: \(coachName)")
      successMessage = "Coach deleted"
      showSuccessToast = true
    } catch {
      logger.warning("Simple delete failed, attempting cascade: \(error.localizedDescription)")
      do {
        let result = try await coachesService.cascadeDeleteCoach(id: coach.id)
        allCoaches.removeAll { $0.id == coach.id }
        logger.info("Cascade deleted coach: \(coachName)")

        // Build detailed success message
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        if totalDeleted > 0 {
          successMessage = "Coach and \(totalDeleted) related record\(totalDeleted == 1 ? "" : "s") deleted"
        } else {
          successMessage = "Coach deleted"
        }
        showSuccessToast = true
      } catch {
        logger.error("Cascade delete failed: \(error.localizedDescription)")
        deleteErrorMessage = "Failed to delete coach. Please try again."
      }
    }
  }

  func clearFilters() {
    filters = CoachFilters()
  }

  func schoolName(for schoolId: String) -> String {
    EntityNameLookup.schoolName(for: schoolId, in: schoolNameMap)
  }

  func schoolLogoUrl(for schoolId: String) -> String? {
    schoolLogoMap[schoolId] ?? nil
  }

  func schoolInitials(for schoolId: String) -> String {
    schoolInitialsMap[schoolId] ?? "??"
  }

  // MARK: - Private

  private func sorted(_ coaches: [Coach]) -> [Coach] {
    switch filters.sortBy {
    case .name:
      return coaches.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
    case .school:
      return coaches.sorted { schoolName(for: $0.schoolId) < schoolName(for: $1.schoolId) }
    case .lastContacted:
      return coaches.sorted { lhs, rhs in
        let lhsDate = lhs.lastContactDateParsed ?? .distantPast
        let rhsDate = rhs.lastContactDateParsed ?? .distantPast
        return lhsDate > rhsDate
      }
    case .responsiveness:
      return coaches.sorted { $0.responsivenessScore > $1.responsivenessScore }
    case .role:
      return coaches.sorted { $0.role.displayName < $1.role.displayName }
    }
  }

  nonisolated deinit {}
}
