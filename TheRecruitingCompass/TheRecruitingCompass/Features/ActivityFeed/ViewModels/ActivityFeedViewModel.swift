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
  var activities: [ActivityEvent] = []
  var isLoading = false
  var errorMessage: String?
  var selectedType: ActivityEventType? {
    didSet { if oldValue != selectedType { currentPage = 1 } }
  }
  var selectedDateRange: ActivityDateRange = .all {
    didSet { if oldValue != selectedDateRange { currentPage = 1 } }
  }
  var searchQuery: String = "" {
    didSet { if oldValue != searchQuery { currentPage = 1 } }
  }
  var currentPage: Int = 1
  let pageSize: Int = 20

  private let activityService: any ActivityFeedManaging
  private let authManager: any AuthManaging

  var userId: String? {
    authManager.user?.id
  }

  // MARK: - Computed Properties

  var filteredActivities: [ActivityEvent] {
    var result = activities

    if let type = selectedType {
      result = result.filter { $0.type == type }
    }

    if let days = selectedDateRange.daysAgo {
      let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
      result = result.filter { $0.timestamp >= cutoff }
    }

    if !searchQuery.isEmpty {
      let query = searchQuery.lowercased()
      result = result.filter {
        $0.title.lowercased().contains(query) ||
        $0.description.lowercased().contains(query)
      }
    }

    return result
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

  init(
    activityService: (any ActivityFeedManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  // Prevent compiler-synthesized main-actor-isolated deinit.
  // @MainActor classes otherwise get a deinit that calls swift_task_deinitOnExecutorImpl,
  // which crashes when ARC deallocates the object outside a task context (e.g. in tests).
  nonisolated deinit {}

  // MARK: - Data Loading

  func loadActivities() async {
    guard let userId = authManager.user?.id else {
      logger.warning("No user ID available for activity feed")
      errorMessage = "Unable to load activities. Please sign in."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let interactionsTask = activityService.fetchInteractions(userId: userId)
      async let statusChangesTask = activityService.fetchStatusChanges(userId: userId)
      async let documentsTask = activityService.fetchDocuments(userId: userId)

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
