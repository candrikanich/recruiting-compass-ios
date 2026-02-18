import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EventDetailViewModel"
)

@Observable
@MainActor
final class EventDetailViewModel {

  // MARK: - State

  var event: FullEvent?
  var isLoading = false
  var error: String?

  // MARK: - Dependencies

  private let eventsService: EventsManaging
  private let eventId: String

  // MARK: - Computed

  var formattedDateRange: String {
    guard let event else { return "" }
    let start = formatDate(event.startDate)
    guard let endDate = event.endDate, endDate != event.startDate else { return start }
    return "\(start) – \(formatDate(endDate))"
  }

  var formattedLocation: String? {
    guard let event else { return nil }
    var parts: [String] = []
    if let city = event.city, !city.isEmpty { parts.append(city) }
    if let state = event.state, !state.isEmpty { parts.append(state) }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  var hasLocation: Bool {
    guard let event else { return false }
    return !(event.address ?? "").isEmpty || !(event.city ?? "").isEmpty
  }

  // MARK: - Init

  nonisolated init(eventsService: EventsManaging, eventId: String) {
    self.eventsService = eventsService
    self.eventId = eventId
  }

  // MARK: - Load

  func loadEvent() async {
    logger.debug("Loading event: \(self.eventId)")
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      event = try await eventsService.fetchEvent(id: eventId)
      logger.info("Loaded event: \(self.eventId)")
    } catch {
      logger.error("Failed to load event: \(error.localizedDescription)")
      self.error = "Failed to load event. Please try again."
    }
  }

  // MARK: - Directions

  func getDirectionsURL() -> URL? {
    guard let event else { return nil }
    var parts: [String] = []
    if let address = event.address, !address.isEmpty { parts.append(address) }
    if let city = event.city, !city.isEmpty { parts.append(city) }
    if let state = event.state, !state.isEmpty { parts.append(state) }

    let query = parts.joined(separator: ", ")
    guard !query.isEmpty,
          let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return nil
    }
    return URL(string: "maps://?q=\(encoded)")
  }

  // MARK: - Private Helpers

  private func formatDate(_ isoDate: String) -> String {
    let components = isoDate.split(separator: "-").compactMap { Int($0) }
    guard components.count == 3 else { return isoDate }
    let date = DateComponents(
      calendar: .current,
      year: components[0],
      month: components[1],
      day: components[2]
    ).date
    return date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? isoDate
  }
}
