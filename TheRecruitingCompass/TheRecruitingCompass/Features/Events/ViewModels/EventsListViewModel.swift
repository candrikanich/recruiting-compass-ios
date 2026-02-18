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

  // MARK: - Computed

  var filteredEvents: [FullEvent] {
    var result = events

    if !searchText.isEmpty {
      let query = searchText.lowercased()
      result = result.filter {
        $0.name.lowercased().contains(query)
        || ($0.city?.lowercased().contains(query) ?? false)
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

    return result
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
    !searchText.isEmpty || typeFilter != nil || statusFilter != .all
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
  }

  // MARK: - Private Helpers

  private func isoToday() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

// MARK: - StatusFilter

enum StatusFilter: String, CaseIterable {
  case all = "All"
  case attended = "Attended"
  case registered = "Registered"
  case notRegistered = "Not Registered"
}
