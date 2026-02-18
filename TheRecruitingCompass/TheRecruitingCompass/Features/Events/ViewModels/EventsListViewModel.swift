import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EventsListViewModel"
)

@Observable
@MainActor
final class EventsListViewModel {

  // MARK: - State

  var events: [FullEvent] = []
  var isLoading = false
  var error: String?
  var searchText = ""
  var typeFilter: EventType?
  var statusFilter: StatusFilter = .all
  var dateRangeFilter: DateRangeFilter = .all
  var sortBy: SortOption = .dateDesc

  // MARK: - Computed

  var filteredEvents: [FullEvent] {
    var result = events

    if !searchText.isEmpty {
      let query = searchText.lowercased()
      result = result.filter {
        $0.name.lowercased().contains(query)
        || ($0.city?.lowercased().contains(query) ?? false)
        || ($0.description?.lowercased().contains(query) ?? false)
        || ($0.address?.lowercased().contains(query) ?? false)
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

    return result.sorted { a, b in
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

  // MARK: - Dependencies

  private let eventsService: EventsManaging
  private let authManager: any AuthManaging

  // MARK: - Init

  init(
    eventsService: (any EventsManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.eventsService = eventsService ?? EventsServiceImpl()
    self.authManager = authManager ?? AuthManager.shared
  }

  // MARK: - Load

  func loadEvents() async {
    guard let userId = authManager.user?.id else {
      logger.warning("No userId available for events list")
      return
    }

    logger.debug("Loading events for user: \(userId)")
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      events = try await eventsService.fetchEvents(userId: userId)
      logger.info("Loaded \(self.events.count) events")
    } catch {
      logger.error("Failed to load events: \(error.localizedDescription)")
      self.error = "Failed to load events. Please try again."
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
    } catch {
      logger.error("Failed to delete event \(id): \(error.localizedDescription)")
      self.error = "Failed to delete event. Please try again."
    }
  }

  // MARK: - Private Helpers

  private func isoToday() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private func isoNextMonthPrefix() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date()) else {
      return ""
    }
    return formatter.string(from: nextMonth)
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
