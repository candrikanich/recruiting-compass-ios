import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityFeedViewModel"
)

@Observable
@MainActor
final class ActivityFeedViewModel {

  nonisolated deinit {}
  var activities: [ActivityEvent] = [] {
    didSet { recomputeFilteredActivities() }
  }
  var isLoading = false
  var errorMessage: String?
  var selectedType: ActivityEventType? {
    didSet {
      if oldValue != selectedType { currentPage = 1 }
      recomputeFilteredActivities()
    }
  }
  var selectedDateRange: ActivityDateRange = .all {
    didSet {
      if oldValue != selectedDateRange { currentPage = 1 }
      recomputeFilteredActivities()
    }
  }
  var searchQuery: String = "" {
    didSet {
      if oldValue != searchQuery { currentPage = 1 }
      recomputeFilteredActivities()
    }
  }
  var currentPage: Int = 1
  let pageSize: Int = 20

  private let activityService: any ActivityFeedManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  /// The active family. The feed is scoped to it (family sees the same data), never to the signed-in
  /// user and never to all of a multi-family user's families.
  var familyUnitId: String? { familyManager.resolvedFamilyUnitId }

  /// "You" for the signed-in user, otherwise the member's name; a member who has left has no
  /// `family_members` row any more, so they fall back to a generic label.
  func actorLabel(for event: ActivityEvent) -> String? {
    guard let actorId = event.actorUserId else { return nil }
    if actorId == authManager.user?.id { return Self.youLabel }
    let user = familyManager.familyMembers.first { $0.userId == actorId }?.user
    let name = [user?.fullName, user?.email]
      .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .first { !$0.isEmpty }
    return name ?? Self.formerMemberLabel
  }

  static let youLabel = "You"
  static let formerMemberLabel = "Former member"

  // MARK: - Computed Properties

  /// Cached derived list — recomputed via `recomputeFilteredActivities()` whenever
  /// `activities`, `selectedType`, `selectedDateRange`, or `searchQuery` change.
  /// Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredActivities: [ActivityEvent] = []

  private func recomputeFilteredActivities() {
    var result = activities

    if let type = selectedType {
      result = result.filter { $0.type == type }
    }

    if let days = selectedDateRange.daysAgo {
      let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
      result = result.filter { $0.timestamp >= cutoff }
    }

    if !searchQuery.isEmpty {
      let query = searchQuery
      result = result.filter {
        $0.title.localizedStandardContains(query) ||
        $0.description.localizedStandardContains(query)
      }
    }

    filteredActivities = result
  }

  var paginatedActivities: [ActivityEvent] {
    let start = (currentPage - 1) * pageSize
    guard start < filteredActivities.count else { return [] }
    let end = min(start + pageSize, filteredActivities.count)
    return Array(filteredActivities[start..<end])
  }

  var totalPages: Int {
    max(1, Int(ceil(Double(filteredActivities.count) / Double(pageSize))))
  }

  var hasNextPage: Bool {
    currentPage < totalPages
  }

  var hasPreviousPage: Bool {
    currentPage > 1
  }

  var recentActivities: [ActivityEvent] {
    Array(activities.prefix(5))
  }

  // MARK: - Initialization

  private let cache: (any CacheManaging)?
  private let reloadDebounce: Duration
  private var pendingReload: Task<Void, Never>?

  /// TTL for cached activity feed (seconds). Short, and deliberately not
  /// invalidated from the many VMs that create interactions/status-changes/
  /// documents — this is an aggregated feed, not a primary source of truth
  /// for any one entity, so a bounded staleness window is expected UX (same
  /// tradeoff as any activity/social feed) rather than a correctness bug.
  private static let activitiesCacheTTL: TimeInterval = 60

  init(
    activityService: (any ActivityFeedManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil,
    reloadDebounce: Duration = .milliseconds(1500)
  ) {
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
    self.reloadDebounce = reloadDebounce
  }

  // Prevent compiler-synthesized main-actor-isolated deinit.
  // @MainActor classes otherwise get a deinit that calls swift_task_deinitOnExecutorImpl,
  // which crashes when ARC deallocates the object outside a task context (e.g. in tests).

  // MARK: - Data Loading

  /// - Parameter forceRefresh: skip the cache; used when a realtime signal says the data changed.
  func loadActivities(forceRefresh: Bool = false) async {
    guard let familyUnitId else {
      logger.warning("No active family for activity feed")
      errorMessage = "Unable to load activities. Please sign in."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.activities(familyUnitId: familyUnitId)
    let cacheToUse = cache ?? InMemoryCache.shared

    if !forceRefresh, let cached = await cacheToUse.get([ActivityEvent].self, forKey: cacheKey) {
      activities = cached
      currentPage = 1
      logger.info("Loaded \(cached.count) activity events from cache")
      return
    }

    do {
      async let interactionsTask = activityService.fetchInteractions(familyUnitId: familyUnitId)
      async let statusChangesTask = activityService.fetchStatusChanges(familyUnitId: familyUnitId)
      async let documentsTask = activityService.fetchDocuments(familyUnitId: familyUnitId)

      let (interactions, statusChanges, documents) = try await (
        interactionsTask, statusChangesTask, documentsTask
      )

      // Collect school IDs for hydration
      let interactionSchoolIds = interactions.compactMap(\.schoolId)
      let statusSchoolIds = statusChanges.map(\.schoolId)
      let allSchoolIds = Array(Set(interactionSchoolIds + statusSchoolIds))

      let schoolNames = try await activityService.fetchSchoolNames(schoolIds: allSchoolIds)

      // Transform to ActivityEvents
      var events: [ActivityEvent] = []

      events += interactions.map { interaction in
        ActivityEventFactory.fromInteraction(
          interaction,
          schoolName: interaction.schoolId.flatMap { schoolNames[$0] }
        )
      }

      events += statusChanges.map { change in
        ActivityEventFactory.fromStatusChange(
          change,
          schoolName: schoolNames[change.schoolId]
        )
      }

      events += documents.map { document in
        ActivityEventFactory.fromDocument(document)
      }

      // Sort by timestamp descending
      events.sort { $0.timestamp > $1.timestamp }

      activities = events
      currentPage = 1
      await cacheToUse.set(events, forKey: cacheKey, ttlSeconds: Self.activitiesCacheTTL)

      logger.info("Loaded \(events.count) activity events")
    } catch {
      logger.error("Failed to load activities: \(error.localizedDescription)")
      errorMessage = "Failed to load activities. Please try again."
    }
  }

  // MARK: - Pagination

  func nextPage() {
    guard hasNextPage else { return }
    currentPage += 1
  }

  func previousPage() {
    guard hasPreviousPage else { return }
    currentPage -= 1
  }

  // MARK: - Filters

  func clearFilters() {
    selectedType = nil
    selectedDateRange = .all
    searchQuery = ""
  }

  // MARK: - Realtime Updates

  /// Reloads once the burst settles. A status change is an UPDATE on `schools` and then a separate
  /// INSERT into `school_status_history`; reloading on the first signal would miss the history row.
  func scheduleDebouncedReload() {
    pendingReload?.cancel()
    pendingReload = Task { [weak self, reloadDebounce] in
      try? await Task.sleep(for: reloadDebounce)
      guard !Task.isCancelled else { return }
      await self?.loadActivities(forceRefresh: true)
    }
  }

  func cancelPendingReload() {
    pendingReload?.cancel()
    pendingReload = nil
  }

  /// Add a new activity event from realtime update (deduplicates by ID)
  func addRealtimeEvent(_ event: ActivityEvent) {
    if !activities.contains(where: { $0.id == event.id }) {
      activities.insert(event, at: 0)
      logger.debug("Added realtime event: \(event.id)")
    } else {
      logger.debug("Skipped duplicate realtime event: \(event.id)")
    }
  }
}
