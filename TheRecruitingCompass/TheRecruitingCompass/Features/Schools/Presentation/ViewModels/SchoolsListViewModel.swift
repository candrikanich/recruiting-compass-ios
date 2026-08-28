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
    didSet {
      recomputeFilteredSchools()
      recomputeAnalytics()
    }
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

  let schoolsService: any SchoolsManaging
  private let familyManager: FamilyManager
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let interactionsService: any InteractionsManaging
  private let eventsService: any EventsManaging
  private let filterAndSort = FilterAndSortSchoolsUseCase()
  private let computeAnalytics = ComputeSchoolAnalyticsUseCase()
  private let deleteSchoolUseCase: DeleteSchoolUseCase

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

  /// Full-list stats. One pass over `allSchools`, not on every filter keystroke.
  private(set) var analytics = SchoolAnalytics(
    totalCount: 0,
    favoritesCount: 0,
    visitedCount: 0,
    contactedCount: 0
  )

  private func recomputeFilteredSchools() {
    filteredSchools = filterAndSort.execute(
      schools: allSchools,
      filters: filters,
      homeLocation: homeLocation,
      overallFit: { overallFit(for: $0) },
      distance: { cachedDistance(for: $0, from: $1) }
    )
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

  private func recomputeAnalytics() {
    let next = computeAnalytics.execute(
      schools: allSchools,
      visitedSchoolIds: visitedSchoolIds,
      contactedSchoolIds: contactedSchoolIds
    )
    guard analytics != next else { return }
    analytics = next
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
    cache: (any CacheManaging)? = nil,
    deleteSchool: DeleteSchoolUseCase? = nil
  ) {
    let repository: any SchoolsManaging = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.schoolsService = repository
    self.familyManager = familyManager ?? .shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.eventsService = eventsService ?? EventsServiceImpl(supabaseManager: .shared)
    self.cache = cache
    self.deleteSchoolUseCase = deleteSchool ?? DeleteSchoolUseCase(repository: repository)
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
      let result = try await cacheToUse.getOrFetch(
        [School].self,
        forKey: cacheKey,
        ttlSeconds: Self.schoolsListCacheTTL
      ) {
        try await schoolsService.fetchSchools(familyUnitId: familyUnitId)
      }
      allSchools = result.value
      if result.cacheHit {
        logger.info("Loaded \(self.allSchools.count) schools from cache")
      } else {
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
    recomputeAnalytics()
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
      let outcome = try await deleteSchoolUseCase.execute(id: school.id)
      allSchools.removeAll { $0.id == school.id }
      distanceCache.removeValue(forKey: school.id)
      distanceCacheOrderedKeys.removeAll { $0 == school.id }
      switch outcome {
      case .simple:
        successMessage = String(localized: "School deleted successfully")
        logger.info("School deleted: \(school.name)")
      case .cascade(let result):
        let totalDeleted = result.deletedInteractions + result.deletedNotes
        successMessage = totalDeleted > 0
          ? String(localized: "School and \(totalDeleted) related items deleted")
          : String(localized: "School deleted successfully")
        logger.info("Cascade delete successful: \(school.name)")
      }
      showSuccessToast = true
      await invalidateSchoolsListCache()
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

}
