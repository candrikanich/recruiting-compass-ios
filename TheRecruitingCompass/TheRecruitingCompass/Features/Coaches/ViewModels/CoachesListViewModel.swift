import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachesListViewModel")

@Observable
@MainActor
final class CoachesListViewModel {

  nonisolated deinit {}
  var allCoaches: [Coach] = [] {
    didSet { recomputeFilteredCoaches() }
  }
  var allSchools: [School] = [] {
    didSet { recomputeFilteredCoaches() }
  }
  var isLoading = false
  var errorMessage: String?
  var filters = CoachFilters() {
    didSet { recomputeFilteredCoaches() }
  }
  var showDeleteConfirmation = false
  var coachToDelete: Coach?
  var isDeleting = false
  var deleteErrorMessage: String?

  /// Drives the delete-error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingDeleteError: Bool {
    get { deleteErrorMessage != nil }
    set { if !newValue { deleteErrorMessage = nil } }
  }
  var successMessage: String?
  var showSuccessToast = false

  let coachesService: any CoachesManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  /// Cached derived list — recomputed via `recomputeFilteredCoaches()` whenever
  /// `allCoaches`, `allSchools` (sort-by-school reads schoolName(for:)), or
  /// `filters` change. Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredCoaches: [Coach] = []

  private func recomputeFilteredCoaches() {
    var result = allCoaches

    if !filters.searchText.isEmpty {
      let query = filters.searchText
      result = result.filter { coach in
        coach.fullName.localizedStandardContains(query)
          || (coach.email?.localizedStandardContains(query) ?? false)
          || (coach.phone?.localizedStandardContains(query) ?? false)
          || (coach.notes?.localizedStandardContains(query) ?? false)
          || (coach.twitterHandle?.localizedStandardContains(query) ?? false)
          || (coach.instagramHandle?.localizedStandardContains(query) ?? false)
      }
    }

    if let role = filters.role {
      result = result.filter { $0.role == role }
    }

    if let days = filters.lastContactDays {
      let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date.now) ?? Date.now
      result = result.filter { coach in
        guard let contactDate = coach.lastContactDateParsed else { return false }
        return contactDate >= cutoff
      }
    }

    if let schoolId = filters.schoolId {
      result = result.filter { $0.schoolId == schoolId }
    }

    filteredCoaches = sorted(result)
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
    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date.now) ?? Date.now

    return CoachAnalytics(
      totalCount: allCoaches.count,
      headCoachCount: allCoaches.count(where: { $0.role == .head }),
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

  private let cache: (any CacheManaging)?

  /// TTL for cached coaches list (seconds).
  private static let coachesListCacheTTL: TimeInterval = 60

  init(
    coachesService: (any CoachesManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  /// Invalidates the cached coaches list so the next `loadCoaches()`
  /// refetches. Call after any mutation (delete). `AddCoachViewModel`,
  /// `AddInteractionViewModel.createNewCoach()`, and `CoachDetailViewModel`
  /// invalidate the same key (via `ListCacheKeys.coaches`) after create/edit.
  private func invalidateCoachesListCache() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.coaches(familyUnitId: familyUnitId))
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

    let cacheKey = ListCacheKeys.coaches(familyUnitId: familyUnitId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      let schools = try await coachesService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools

      if let cachedCoaches = await cacheToUse.get([Coach].self, forKey: cacheKey) {
        allCoaches = cachedCoaches
        logger.info("Loaded \(self.allCoaches.count) coaches from cache")
      } else {
        let schoolIds = schools.map(\.id)
        let fetched = try await coachesService.fetchCoaches(schoolIds: schoolIds)
        allCoaches = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.coachesListCacheTTL)
        logger.info("Loaded \(self.allCoaches.count) coaches from \(schools.count) schools")
      }
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
      successMessage = String(localized: "Coach deleted")
      showSuccessToast = true
      await invalidateCoachesListCache()
    } catch {
      logger.warning("Simple delete failed, attempting cascade: \(error.localizedDescription)")
      do {
        let result = try await coachesService.cascadeDeleteCoach(id: coach.id)
        allCoaches.removeAll { $0.id == coach.id }
        logger.info("Cascade deleted coach: \(coachName)")

        // Build detailed success message
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        if totalDeleted > 0 {
          successMessage = String(localized: "Coach and \(totalDeleted) related record\(totalDeleted == 1 ? "" : "s") deleted")
        } else {
          successMessage = String(localized: "Coach deleted")
        }
        showSuccessToast = true
        await invalidateCoachesListCache()
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
    schoolLogoMap[schoolId].flatMap { $0 }
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
    case .role:
      return coaches.sorted { $0.role.displayName < $1.role.displayName }
    }
  }

}
