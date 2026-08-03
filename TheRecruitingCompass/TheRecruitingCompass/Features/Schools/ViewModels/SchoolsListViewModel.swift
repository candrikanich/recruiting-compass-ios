import CoreLocation
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolsListViewModel")

@Observable
@MainActor
final class SchoolsListViewModel {

  nonisolated deinit {}
  var allSchools: [School] = [] {
    didSet { recomputeFilteredSchools() }
  }
  var isLoading = false
  var errorMessage: String?
  var filters = SchoolFilters() {
    didSet { recomputeFilteredSchools() }
  }
  var showDeleteConfirmation = false
  var schoolToDelete: School?
  var isDeleting = false
  var deleteErrorMessage: String?

  /// Drives the delete-error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingDeleteError: Bool {
    get { deleteErrorMessage != nil }
    set { if !newValue { deleteErrorMessage = nil } }
  }
  var successMessage: String?
  var showSuccessToast = false

  /// Home location for distance filter and sort. Uses family unit coordinates when present, otherwise location saved in Settings (user_preferences).
  var homeLocation: CLLocationCoordinate2D? {
    get {
      if let lat = familyManager.familyUnit?.homeLatitude,
         let lon = familyManager.familyUnit?.homeLongitude {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
      }
      return homeLocationFromPreferences
    }
    set {
      homeLocationFromPreferences = newValue
      recomputeFilteredSchools()
    }
  }

  /// Cached home location from user_preferences (Settings → Home Location). Loaded in loadSchools().
  private var homeLocationFromPreferences: CLLocationCoordinate2D?

  let schoolsService: any SchoolsManaging
  private let familyManager: FamilyManager
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private var distanceCache: [String: Double] = [:]
  private var distanceCacheOrderedKeys: [String] = []
  private static let maxDistanceCacheEntries = 300

  /// Cached derived list — recomputed via `recomputeFilteredSchools()` whenever
  /// `allSchools`, `filters`, or `homeLocation` change (see their didSet/setter hooks).
  /// Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredSchools: [School] = []

  private func recomputeFilteredSchools() {
    var result = allSchools

    if !filters.searchText.isEmpty {
      let query = filters.searchText
      result = result.filter { school in
        school.name.localizedStandardContains(query)
          || (school.location?.localizedStandardContains(query) ?? false)
          || (school.city?.localizedStandardContains(query) ?? false)
          || (school.state?.localizedStandardContains(query) ?? false)
          || (school.conference?.localizedStandardContains(query) ?? false)
          || (school.notes?.localizedStandardContains(query) ?? false)
      }
    }

    if let division = filters.division {
      result = result.filter { $0.division == division.rawValue }
    }

    if let status = filters.status {
      result = result.filter { $0.status == status.rawValue }
    }

    if let state = filters.state {
      result = result.filter { $0.state == state }
    }

    if filters.isFavoritesOnly {
      result = result.filter { $0.isFavorite }
    }

    if let minScore = filters.fitScoreMin {
      result = result.filter { ($0.fitScore ?? 0) >= minScore }
    }

    if let maxScore = filters.fitScoreMax {
      result = result.filter { ($0.fitScore ?? 100) <= maxScore }
    }

    if let maxDistance = filters.maxDistance, let home = homeLocation {
      result = result.filter { school in
        guard let distance = cachedDistance(for: school, from: home) else { return false }
        return distance <= maxDistance
      }
    }

    filteredSchools = sorted(result)
  }

  var availableStates: [String] {
    let states = allSchools.compactMap { $0.state }
    return Array(Set(states)).sorted()
  }

  var resultCount: Int {
    filteredSchools.count
  }

  var activeFilterCount: Int {
    filters.activeFilterCount
  }

  var showWarningBanner: Bool {
    allSchools.count >= 30
  }

  /// Summary stats for the full school list (unfiltered), matching web app behavior.
  var analytics: SchoolAnalytics {
    SchoolAnalytics(
      totalCount: allSchools.count,
      favoritesCount: allSchools.filter(\.isFavorite).count,
      visitedCount: allSchools.filter { school in
        school.status == SchoolStatus.officialVisitScheduled.rawValue
          || school.status == SchoolStatus.officialVisitInvited.rawValue
      }.count
    )
  }

  private let cache: (any CacheManaging)?

  /// TTL for cached school list (seconds). Short — schools change relatively
  /// often (status updates, new adds) and this only smooths back-navigation.
  private static let schoolsListCacheTTL: TimeInterval = 60

  init(
    schoolsService: (any SchoolsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  /// Invalidates the cached school list so the next `loadSchools()` refetches.
  /// Call after any mutation (delete, favorite toggle) so a cached stale list
  /// isn't served on next screen appearance. `AddSchoolViewModel` invalidates
  /// the same key (via `ListCacheKeys.schools`) after creating a school.
  private func invalidateSchoolsListCache() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.schools(familyUnitId: familyUnitId))
  }

  func loadSchools() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load schools. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    distanceCache.removeAll()
    distanceCacheOrderedKeys.removeAll()
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.schools(familyUnitId: familyUnitId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      if let cachedSchools = await cacheToUse.get([School].self, forKey: cacheKey) {
        allSchools = cachedSchools
        logger.info("Loaded \(self.allSchools.count) schools from cache")
      } else {
        let fetched = try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
        allSchools = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.schoolsListCacheTTL)
        logger.info("Loaded \(self.allSchools.count) schools")
      }

      // Load home location from Settings (user_preferences) when family unit has no coordinates
      if familyManager.familyUnit?.homeLatitude == nil || familyManager.familyUnit?.homeLongitude == nil {
        do {
          if let location: HomeLocation = try await preferenceService.fetchPreferences(category: .location),
             let lat = location.latitude, let lon = location.longitude {
            homeLocationFromPreferences = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            logger.debug("Using home location from preferences")
          } else {
            homeLocationFromPreferences = nil
          }
        } catch {
          // intentionally silent: distance-based sort just falls back to
          // having no reference point (schools sort as if distance is
          // unknown) rather than blocking the schools list on a preferences
          // fetch failure.
          logger.debug("Could not load home location from preferences: \(error.localizedDescription)")
          homeLocationFromPreferences = nil
        }
      } else {
        homeLocationFromPreferences = nil
      }
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      errorMessage = "Failed to load schools. Please try again."
    }
  }

  func confirmDelete(school: School) {
    schoolToDelete = school
    showDeleteConfirmation = true
  }

  func deleteSchool() async {
    guard let school = schoolToDelete else { return }

    isDeleting = true
    deleteErrorMessage = nil
    defer {
      isDeleting = false
      showDeleteConfirmation = false
    }

    do {
      do {
        try await schoolsService.deleteSchool(id: school.id)
        allSchools.removeAll { $0.id == school.id }
        distanceCache.removeValue(forKey: school.id)
        distanceCacheOrderedKeys.removeAll { $0 == school.id }
        successMessage = "School deleted successfully"
        showSuccessToast = true
        logger.info("School deleted: \(school.name)")
        await invalidateSchoolsListCache()
      } catch {
        logger.warning("Simple delete failed, attempting cascade delete: \(error.localizedDescription)")
        let result = try await schoolsService.cascadeDeleteSchool(id: school.id)
        allSchools.removeAll { $0.id == school.id }
        distanceCache.removeValue(forKey: school.id)
        distanceCacheOrderedKeys.removeAll { $0 == school.id }
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        successMessage = totalDeleted > 0
          ? "School and \(totalDeleted) related items deleted"
          : "School deleted successfully"
        showSuccessToast = true
        logger.info("Cascade delete successful: \(school.name)")
        await invalidateSchoolsListCache()
      }
    } catch {
      logger.error("Delete failed: \(error.localizedDescription)")
      deleteErrorMessage = "Failed to delete school. Please try again."
    }
  }

  func toggleFavorite(school: School) async {
    let originalSchool = school
    let newFavoriteState = !school.isFavorite

    if let index = allSchools.firstIndex(where: { $0.id == school.id }) {
      allSchools[index] = school.with(isFavorite: newFavoriteState)
    }

    do {
      try await schoolsService.toggleFavorite(id: school.id, isFavorite: newFavoriteState)
      logger.info("Favorite toggled for school: \(school.name)")
      await invalidateSchoolsListCache()
    } catch {
      logger.error("Failed to toggle favorite: \(error.localizedDescription)")

      if let index = allSchools.firstIndex(where: { $0.id == school.id }) {
        allSchools[index] = originalSchool
      }

      errorMessage = "Failed to update favorite. Please try again."
    }
  }

  func clearFilters() {
    filters = SchoolFilters(sortBy: filters.sortBy)
  }

  func cachedDistance(for school: School, from coordinate: CLLocationCoordinate2D) -> Double? {
    if let cached = distanceCache[school.id] {
      return cached
    }

    guard let distance = school.distanceTo(from: coordinate) else {
      return nil
    }

    if distanceCacheOrderedKeys.count >= Self.maxDistanceCacheEntries, let keyToEvict = distanceCacheOrderedKeys.first {
      distanceCache.removeValue(forKey: keyToEvict)
      distanceCacheOrderedKeys.removeFirst()
    }
    distanceCache[school.id] = distance
    distanceCacheOrderedKeys.append(school.id)
    return distance
  }

  private func sorted(_ schools: [School]) -> [School] {
    switch filters.sortBy {
    case .nameAZ:
      return schools.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    case .fitScore:
      return schools.sorted { ($0.fitScore ?? 0) > ($1.fitScore ?? 0) }

    case .distance:
      guard let home = homeLocation else { return schools }
      return schools.sorted { lhs, rhs in
        let lhsDistance = cachedDistance(for: lhs, from: home) ?? Double.infinity
        let rhsDistance = cachedDistance(for: rhs, from: home) ?? Double.infinity
        return lhsDistance < rhsDistance
      }

    case .lastContact:
      return schools.sorted { lhs, rhs in
        guard let lhsDate = lhs.statusChangedAt else { return false }
        guard let rhsDate = rhs.statusChangedAt else { return true }
        return lhsDate > rhsDate
      }
    }
  }


}

extension SchoolFilters {
  var activeFilterCount: Int {
    var count = 0
    if !searchText.isEmpty { count += 1 }
    if division != nil { count += 1 }
    if status != nil { count += 1 }
    if state != nil { count += 1 }
    if isFavoritesOnly { count += 1 }
    if fitScoreMin != nil || fitScoreMax != nil { count += 1 }
    if maxDistance != nil { count += 1 }
    return count
  }
}
