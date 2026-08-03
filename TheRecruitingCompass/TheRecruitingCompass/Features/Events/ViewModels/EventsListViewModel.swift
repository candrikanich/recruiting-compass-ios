import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EventsListViewModel"
)

private let eventsSortByKey = "eventsSortBy"

@Observable
@MainActor
final class EventsListViewModel {

  nonisolated deinit {}

  // MARK: - State

  var events: [FullEvent] = [] {
    didSet { recomputeFilteredEvents() }
  }
  var isLoading = false
  var errorMessage: String?

  /// Drives the error alert directly, without a view-local Binding(get:set:) wrapper.
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var searchText = "" {
    didSet { recomputeFilteredEvents() }
  }
  var typeFilter: EventType? {
    didSet { recomputeFilteredEvents() }
  }
  var statusFilter: StatusFilter = .all {
    didSet { recomputeFilteredEvents() }
  }
  var dateRangeFilter: DateRangeFilter = .all {
    didSet { recomputeFilteredEvents() }
  }
  private var _sortBy: SortOption
  var sortBy: SortOption {
    get { _sortBy }
    set {
      _sortBy = newValue
      UserDefaults.standard.set(newValue.rawValue, forKey: eventsSortByKey)
      recomputeFilteredEvents()
    }
  }
  var currentMonth: Date = {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: .now)
    return calendar.date(from: components) ?? .now
  }()
  var selectedCalendarDate: Date?

  // MARK: - Computed

  /// Cached derived list — recomputed via `recomputeFilteredEvents()` whenever
  /// `events`, `searchText`, `typeFilter`, `statusFilter`, `dateRangeFilter`, or
  /// `sortBy` change. Do not compute this inline elsewhere; it would go stale
  /// silently. Note: the date-range filter's "today" cutoff is computed once
  /// per recompute (not live), same as the prior computed-property behavior —
  /// it only advances when a mutation triggers a recompute.
  private(set) var filteredEvents: [FullEvent] = []

  private func recomputeFilteredEvents() {
    var result = events

    if !searchText.isEmpty {
      let query = searchText
      result = result.filter {
        $0.name.localizedStandardContains(query)
        || ($0.city?.localizedStandardContains(query) ?? false)
        || ($0.description?.localizedStandardContains(query) ?? false)
        || ($0.address?.localizedStandardContains(query) ?? false)
      }
    }

    if let typeFilter {
      result = result.filter { $0.type == typeFilter.rawValue }
    }

    switch statusFilter {
    case .all: break
    case .attended: result = result.filter { $0.attended }
    case .registered: result = result.filter { $0.registered && !$0.attended }
    case .notRegistered: result = result.filter { !$0.registered && !$0.attended }
    }

    let today = isoToday()
    switch dateRangeFilter {
    case .all: break
    case .upcoming: result = result.filter { $0.startDate >= today }
    case .past: result = result.filter { $0.startDate < today }
    case .thisMonth:
      let prefix = String(today.prefix(7))
      result = result.filter { $0.startDate.hasPrefix(prefix) }
    case .nextMonth:
      let nextMonthPrefix = isoNextMonthPrefix()
      result = result.filter { $0.startDate.hasPrefix(nextMonthPrefix) }
    }

    filteredEvents = result.sorted { a, b in
      switch sortBy {
      case .dateAsc: return a.startDate < b.startDate
      case .dateDesc: return a.startDate > b.startDate
      case .name: return a.name.localizedCompare(b.name) == .orderedAscending
      case .type: return a.type < b.type
      }
    }
  }

  var upcomingEvents: [FullEvent] {
    let today = isoToday()
    return filteredEvents.filter { $0.startDate >= today }
  }

  var pastEvents: [FullEvent] {
    let today = isoToday()
    return filteredEvents.filter { $0.startDate < today }
  }

  var hasActiveFilters: Bool {
    !searchText.isEmpty || typeFilter != nil || statusFilter != .all || dateRangeFilter != .all
  }

  /// Summary stats for the full event list (unfiltered), matching web app behavior.
  var analytics: EventAnalytics {
    let today = isoToday()
    return EventAnalytics(
      totalCount: events.count,
      upcomingCount: events.count(where: { $0.startDate >= today }),
      registeredCount: events.count(where: { $0.registered && !$0.attended }),
      attendedCount: events.filter(\.attended).count
    )
  }

  private static let monthTitleFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMMM yyyy"
    return f
  }()

  private static let dayPrefixFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private static let monthPrefixFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM"
    return f
  }()

  var currentMonthTitle: String {
    EventsListViewModel.monthTitleFormatter.string(from: currentMonth)
  }

  var calendarDays: [Date] {
    let calendar = Calendar.current
    guard let firstOfMonth = calendar.date(
      from: calendar.dateComponents([.year, .month], from: currentMonth)
    ) else { return [] }
    let weekday = calendar.component(.weekday, from: firstOfMonth)
    let startOffset = -(weekday - 1)
    return (0..<42).compactMap {
      calendar.date(byAdding: .day, value: startOffset + $0, to: firstOfMonth)
    }
  }

  func hasEvent(on date: Date) -> Bool {
    let prefix = EventsListViewModel.dayPrefixFormatter.string(from: date)
    return events.contains { $0.startDate.hasPrefix(prefix) }
  }

  func isCurrentMonth(_ date: Date) -> Bool {
    Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
  }

  func eventsForDate(_ date: Date) -> [FullEvent] {
    let prefix = EventsListViewModel.dayPrefixFormatter.string(from: date)
    return filteredEvents.filter { $0.startDate.hasPrefix(prefix) }
  }

  // MARK: - Dependencies

  private let eventsService: any EventsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging

  /// The user whose events we read/write. When a parent is viewing an athlete,
  /// events belong to the athlete (mirrors web + OffersListViewModel); otherwise
  /// the logged-in user's own id.
  var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  // MARK: - Init

  private let cache: (any CacheManaging)?

  /// TTL for cached events list (seconds).
  private static let eventsListCacheTTL: TimeInterval = 60

  init(
    eventsService: (any EventsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.eventsService = eventsService ?? EventsServiceImpl()
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
    let raw = UserDefaults.standard.string(forKey: eventsSortByKey)
    self._sortBy = SortOption(rawValue: raw ?? "") ?? .dateDesc
  }

  /// Invalidates the cached events list so the next `loadEvents()` refetches.
  /// Call after any mutation (delete). `EventDetailViewModel` and
  /// `CreateEventViewModel` invalidate the same key (via `ListCacheKeys.events`)
  /// after edit/attended-toggle/create/delete.
  private func invalidateEventsListCache() async {
    guard let userId = targetUserId else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.events(userId: userId))
  }

  // MARK: - Load

  func loadEvents() async {
    guard let userId = targetUserId else {
      logger.warning("No userId available for events list")
      return
    }

    logger.debug("Loading events for user: \(userId)")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let cacheKey = ListCacheKeys.events(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared

    do {
      if let cached = await cacheToUse.get([FullEvent].self, forKey: cacheKey) {
        events = cached
        logger.info("Loaded \(self.events.count) events from cache")
      } else {
        let fetched = try await eventsService.fetchEvents(userId: userId)
        events = fetched
        await cacheToUse.set(fetched, forKey: cacheKey, ttlSeconds: Self.eventsListCacheTTL)
        logger.info("Loaded \(self.events.count) events")
      }
    } catch is CancellationError {
      logger.debug("Load events cancelled (view disappeared)")
    } catch let error as URLError where error.code == .cancelled {
      logger.debug("Load events cancelled (request cancelled)")
    } catch where (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
      logger.debug("Load events cancelled (URL cancelled)")
    } catch {
      logger.error("Failed to load events: \(error.localizedDescription)")
      self.errorMessage = "Failed to load events. Please try again."
    }
  }

  func clearFilters() {
    searchText = ""
    typeFilter = nil
    statusFilter = .all
    dateRangeFilter = .all
  }

  func deleteEvent(id: String) async {
    do {
      try await eventsService.deleteEvent(id: id)
      events.removeAll { $0.id == id }
      await invalidateEventsListCache()
    } catch {
      logger.error("Failed to delete event \(id): \(error.localizedDescription)")
      self.errorMessage = "Failed to delete event. Please try again."
    }
  }

  /// Allowed range: [ref − 2 years, ref + 2 years]. Use strict inequality so we can land on
  /// the boundary month but never navigate past it (e.g. > limit, not >=, for previous).
  func navigateToPreviousMonth() {
    let limit = Calendar.current.date(byAdding: .year, value: -2, to: referenceDate()) ?? currentMonth
    if currentMonth > limit {
      currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
  }

  func navigateToNextMonth() {
    let limit = Calendar.current.date(byAdding: .year, value: 2, to: referenceDate()) ?? currentMonth
    if currentMonth < limit {
      currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
  }

  // MARK: - Private Helpers

  private func isoToday() -> String {
    EventsListViewModel.dayPrefixFormatter.string(from: .now)
  }

  private func isoNextMonthPrefix() -> String {
    guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: .now) else {
      return ""
    }
    return EventsListViewModel.monthPrefixFormatter.string(from: nextMonth)
  }

  /// First day of the current calendar month (for ±2 year limit).
  private func referenceDate() -> Date {
    let components = Calendar.current.dateComponents([.year, .month], from: .now)
    return Calendar.current.date(from: components) ?? .now
  }

}

// MARK: - StatusFilter

enum StatusFilter: String, CaseIterable {
  case all = "All"
  case attended = "Attended"
  case registered = "Registered"
  case notRegistered = "Not Registered"
}

// MARK: - DateRangeFilter

enum DateRangeFilter: String, CaseIterable {
  case all = "All Dates"
  case upcoming = "Upcoming"
  case past = "Past"
  case thisMonth = "This Month"
  case nextMonth = "Next Month"
}

// MARK: - SortOption

enum SortOption: String, CaseIterable {
  case dateDesc = "Date (Newest First)"
  case dateAsc = "Date (Oldest First)"
  case name = "Name"
  case type = "Type"
}
