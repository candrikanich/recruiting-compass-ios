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

  /// Home location for distance filter and sort, from Settings (user_preferences).
  var homeLocation: CLLocationCoordinate2D? {
    get { homeLocationFromPreferences }
    set {
      homeLocationFromPreferences = newValue
      recomputeFilteredSchools()
    }
  }

  /// Cached home location from user_preferences (Settings → Home Location). Loaded in loadSchools().
  private var homeLocationFromPreferences: CLLocationCoordinate2D?

  /// Cached athlete profile for Personal Fit signals. Loaded in loadSchools().
  private var athleteProfile: PlayerDetails?

  func overallFit(for school: School) -> OverallPersonalFit? {
    PersonalFitCalculator.overall(PersonalFitCalculator.calculate(athlete: athleteProfile, school: school))
  }

  private func rank(_ strength: OverallPersonalFit.Strength?) -> Int {
    switch strength {
    case .strong: return 2
    case .good: return 1
    case .stretch: return 0
    case nil: return -1
    }
  }

  let schoolsService: any SchoolsManaging
  private let familyManager: FamilyManager
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let interactionsService: any InteractionsManaging
  private let eventsService: any EventsManaging

  /// School IDs with a real logged visit — a visit-type interaction or a past-dated
  /// visit event. Drives the "Visited" stat (see `analytics`); populated in `loadSchools()`.
  /// Status is deliberately NOT a visit signal (invited/scheduled ≠ visited).
  private(set) var visitedSchoolIds: Set<String> = []

  /// School IDs with ≥1 logged interaction of any type. Drives the "Contacted"
  /// stat (activity-derived, matching the dashboard's interaction count — NOT the
  /// `status` field). Populated alongside `visitedSchoolIds` in `loadSchools()`.
  private(set) var contactedSchoolIds: Set<String> = []
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
      visitedCount: allSchools.filter { visitedSchoolIds.contains($0.id) }.count,
      contactedCount: allSchools.filter { contactedSchoolIds.contains($0.id) }.count
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
    interactionsService: (any InteractionsManaging)? = nil,
    eventsService: (any EventsManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.eventsService = eventsService ?? EventsServiceImpl(supabaseManager: .shared)
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
      errorMessage = String(localized: "Unable to load schools. Please try again.")
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

      await refreshInteractionDerivedIds(familyUnitId: familyUnitId)

      // Load home location from Settings (user_preferences).
      do {
        if let location: HomeLocation = try await preferenceService.fetchPreferences(category: .location, userId: familyManager.selectedAthlete?.userId),
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

      // Load athlete profile for Personal Fit signals.
      athleteProfile = try? await preferenceService.fetchPreferences(
        category: .player, userId: familyManager.selectedAthlete?.userId)
      recomputeFilteredSchools()
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load schools. Please try again.")
    }
  }

  /// Recomputes `visitedSchoolIds` and `contactedSchoolIds` from interaction/event
  /// signals. Fetches run independently so a failure in one (or a missing athlete for
  /// events) never blocks the schools list; we union what succeeds.
  ///
  /// - `contactedSchoolIds`: any interaction of any type (activity = contact made).
  /// - `visitedSchoolIds`: a visit-type interaction OR a past-dated visit event.
  ///   Status is deliberately NOT a visit signal (invited/scheduled ≠ visited).
  private func refreshInteractionDerivedIds(familyUnitId: String) async {
    async let interactions = fetchVisitInteractions(familyUnitId: familyUnitId)
    async let events = fetchVisitEvents(userId: familyManager.selectedAthlete?.userId)

    var visited: Set<String> = []
    var contacted: Set<String> = []
    for interaction in await interactions {
      guard let schoolId = interaction.schoolId else { continue }
      contacted.insert(schoolId)
      if interaction.type == .inPersonVisit { visited.insert(schoolId) }
    }
    let now = Date()
    for event in await events {
      guard event.type == EventType.officialVisit.rawValue
        || event.type == EventType.unofficialVisit.rawValue,
        let schoolId = event.schoolId,
        let start = Self.parseDate(event.startDate), start <= now
      else { continue }
      visited.insert(schoolId)
    }
    visitedSchoolIds = visited
    contactedSchoolIds = contacted
  }

  private func fetchVisitInteractions(familyUnitId: String) async -> [Interaction] {
    do {
      return try await interactionsService.fetchInteractions(familyUnitId: familyUnitId)
    } catch {
      logger.debug("Could not load interactions for visit signal: \(error.localizedDescription)")
      return []
    }
  }

  private func fetchVisitEvents(userId: String?) async -> [FullEvent] {
    guard let userId else { return [] }
    do {
      return try await eventsService.fetchEvents(userId: userId)
    } catch {
      logger.debug("Could not load events for visit signal: \(error.localizedDescription)")
      return []
    }
  }

  /// Parses an event `start_date`, tolerating ISO8601 (with/without fractional seconds)
  /// and plain `yyyy-MM-dd` date-only values.
  private static func parseDate(_ value: String) -> Date? {
    if let date = Interaction.iso8601Formatter.date(from: value) { return date }
    if let date = Interaction.iso8601FallbackFormatter.date(from: value) { return date }
    return dateOnlyFormatter.date(from: value)
  }

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

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
        successMessage = String(localized: "School deleted successfully")
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
          ? String(localized: "School and \(totalDeleted) related items deleted")
          : String(localized: "School deleted successfully")
        showSuccessToast = true
        logger.info("Cascade delete successful: \(school.name)")
        await invalidateSchoolsListCache()
      }
    } catch {
      logger.error("Delete failed: \(error.localizedDescription)")
      deleteErrorMessage = String(localized: "Failed to delete school. Please try again.")
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

      errorMessage = String(localized: "Failed to update favorite. Please try again.")
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

    case .personalFit:
      return schools.sorted { rank(overallFit(for: $0)?.strength) > rank(overallFit(for: $1)?.strength) }

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
