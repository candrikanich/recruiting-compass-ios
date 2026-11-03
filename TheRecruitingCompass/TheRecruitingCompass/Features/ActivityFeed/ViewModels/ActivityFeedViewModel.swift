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
  func actorLabel(for event: ActivityEvent) -> String {
    // No actor at all (the member who did it was deleted) needs no member list to answer.
    guard let actorId = event.actorUserId else { return Self.formerMemberLabel }
    if actorId == authManager.user?.id { return Self.youLabel }
    // Until the active family's members are loaded (cold start, failed lookup, mid family switch) nobody can be
    // called "former" — absence from an unloaded list says nothing.
    guard familyManager.familyMembers.contains(where: { $0.familyUnitId == familyUnitId }) else {
      return Self.unknownMemberLabel
    }
    let user = familyManager.familyMembers.first { $0.userId == actorId }?.user
    let name = [user?.fullName, user?.email]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
    return name ?? Self.formerMemberLabel
  }

  static let youLabel = "You"
  static let unknownMemberLabel = "A family member"
  static let formerMemberLabel = "A former family member"

  // MARK: - Computed Properties

  enum Presentation: Equatable {
    case loading
    case failed(String)
    case empty
    case content
  }

  /// What the feed surfaces (widget and page) should show. A failure with nothing to show is an error, never "empty".
  var presentation: Presentation {
    if isLoading && activities.isEmpty { return .loading }
    // Like web: the error stays until a load succeeds, even if live entries arrive meanwhile.
    if let errorMessage { return .failed(errorMessage) }
    return activities.isEmpty ? .empty : .content
  }

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
  private let realtime: any ActivityRealtimeManaging
  private var subscribedFamilyUnitId: String?
  /// The family the entries in `activities` belong to; a load for any other family clears them first.
  private var displayedFamilyUnitId: String?
  private var loadSequence = 0

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
    reloadDebounce: Duration = .milliseconds(1500),
    realtime: (any ActivityRealtimeManaging)? = nil
  ) {
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
    self.reloadDebounce = reloadDebounce
    self.realtime = realtime ?? ActivityRealtimeService(supabaseManager: .shared)
  }

  // Prevent compiler-synthesized main-actor-isolated deinit.
  // @MainActor classes otherwise get a deinit that calls swift_task_deinitOnExecutorImpl,
  // which crashes when ARC deallocates the object outside a task context (e.g. in tests).

  // MARK: - Data Loading

  /// - Parameters:
  ///   - forceRefresh: skip the cache; used when a realtime signal says the data changed.
  ///   - loud: the user asked for this load (pull-to-refresh, Refresh button), so a failure is reported even when
  ///     entries are showing. Silent (realtime/debounced) reloads keep the list on failure.
  func loadActivities(forceRefresh: Bool = false, loud: Bool = false) async {
    guard let familyUnitId else {
      logger.warning("No active family for activity feed")
      // Leaving the last family must not leave that family's entries on screen.
      activities = []
      displayedFamilyUnitId = nil
      errorMessage = "Unable to load activities. Please sign in."
      return
    }

    // Never show one family's entries (or label them with another family's members) while another loads.
    if let displayedFamilyUnitId, displayedFamilyUnitId != familyUnitId {
      activities = []
      self.displayedFamilyUnitId = nil
    }

    loadSequence += 1
    let thisLoad = loadSequence
    isLoading = true
    errorMessage = nil
    // Only the newest load may switch the spinner off; a stale one finishing first would flash the empty state.
    defer { if thisLoad == loadSequence { isLoading = false } }

    let cacheKey = ListCacheKeys.activities(familyUnitId: familyUnitId)
    let cacheToUse = cache ?? InMemoryCache.shared

    if !forceRefresh, let cached = await cacheToUse.get([ActivityEvent].self, forKey: cacheKey) {
      guard isStillActive(familyUnitId) else { return }
      show(cached, for: familyUnitId)
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

      await cacheToUse.set(events, forKey: cacheKey, ttlSeconds: Self.activitiesCacheTTL)
      // The family can change while the fetches are in flight; a late result must not replace the new feed.
      guard isStillActive(familyUnitId) else { return }
      show(events, for: familyUnitId)
      currentPage = 1

      logger.info("Loaded \(events.count) activity events")
    } catch {
      // A superseded load (cancelled task, or the family changed meanwhile) must not flash an error.
      if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
        || !isStillActive(familyUnitId) { return }
      logger.error("Failed to load activities: \(error.localizedDescription)")
      // A failed silent reload keeps the list the user is looking at. A failed manual refresh reports the error.
      if loud || activities.isEmpty {
        activities = []
        displayedFamilyUnitId = nil
        errorMessage = "Failed to load activities. Please try again."
      }
    }
  }

  /// The only place entries are written, so the family they belong to can never be forgotten.
  private func show(_ events: [ActivityEvent], for familyUnitId: String) {
    activities = events
    displayedFamilyUnitId = familyUnitId
  }

  private func isStillActive(_ familyUnitId: String) -> Bool { self.familyUnitId == familyUnitId }

  /// Pull-to-refresh / Refresh button: the user asked for fresh data, so skip the 60 s cache.
  func refresh() async { await loadActivities(forceRefresh: true, loud: true) }

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

  // MARK: - Realtime lifecycle

  func loadAndSubscribe() async {
    let loadedFamilyUnitId = familyUnitId
    await loadActivities()
    // Subscribe to the family that was loaded. If it changed meanwhile, `familyDidChange()` owns the new one.
    guard let loadedFamilyUnitId, isStillActive(loadedFamilyUnitId) else { return }
    await startRealtime(for: loadedFamilyUnitId)
  }

  /// Single teardown path (disappear, background, family switch): no live channels, no pending reload.
  func tearDownRealtime() async {
    cancelPendingReload()
    subscribedFamilyUnitId = nil
    await realtime.unsubscribe()
  }

  /// The active family changed: drop the old family's entries and channels, then load and subscribe for the new one.
  func familyDidChange() async {
    await tearDownRealtime()
    await loadAndSubscribe()
  }

  private func startRealtime(for familyUnitId: String) async {
    // `.task` and the scenePhase `.active` transition can both fire on appear; one live subscription only.
    guard subscribedFamilyUnitId != familyUnitId else { return }
    subscribedFamilyUnitId = familyUnitId
    do {
      try await realtime.subscribe(
        familyUnitId: familyUnitId,
        onInsert: { [weak self] event in self?.addRealtimeEvent(event, forFamily: familyUnitId) },
        onChange: { [weak self] in
          guard let self, self.isStillActive(familyUnitId) else { return }
          Task { await self.loadActivities(forceRefresh: true) }
        },
        onSchoolsChange: { [weak self] in
          guard let self, self.isStillActive(familyUnitId) else { return }
          self.scheduleDebouncedReload()
        },
        onStatusHistoryInsert: { [weak self] in
          guard let self, self.isStillActive(familyUnitId) else { return }
          self.scheduleDebouncedReload()
        }
      )
    } catch {
      // Superseded or failed: either way there is no live subscription, so allow the next start to try again.
      if subscribedFamilyUnitId == familyUnitId { subscribedFamilyUnitId = nil }
      logger.error("Realtime subscription not established: \(error.localizedDescription)")
    }
  }

  /// Add a new activity event from realtime update (deduplicates by ID).
  /// - Parameter familyUnitId: the family whose subscription delivered it; an event from a family that is no
  ///   longer active (insert handlers outlive `unsubscribe()`) is dropped.
  func addRealtimeEvent(_ event: ActivityEvent, forFamily familyUnitId: String) {
    guard isStillActive(familyUnitId) else {
      logger.debug("Dropped realtime event from inactive family: \(event.id)")
      return
    }
    if !activities.contains(where: { $0.id == event.id }) {
      // Rows already on screen from another family must not be re-tagged as this event's family.
      let onScreen = displayedFamilyUnitId == nil || displayedFamilyUnitId == familyUnitId ? activities : []
      show([event] + onScreen, for: familyUnitId)
      logger.debug("Added realtime event: \(event.id)")
    } else {
      logger.debug("Skipped duplicate realtime event: \(event.id)")
    }
  }
}
