import Foundation
import Observation
import OSLog

private let metricDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "yyyy-MM-dd"
  return formatter
}()

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EventDetailViewModel"
)

@Observable
@MainActor
final class EventDetailViewModel {

  // MARK: - State

  var event: FullEvent?
  var schoolCoaches: [Coach] = []
  var metrics: [PerformanceMetric] = []
  var isLoading = false
  var error: String?
  var isNotFound = false
  var shouldDismiss = false

  // MARK: - Sheet State

  var showEditSheet = false
  var showQuickLogSheet = false
  var showDeleteConfirmation = false
  var showMetricForm = false
  var showAddCoach = false

  // MARK: - Edit State

  var editData = EditEventData()
  var isSaving = false

  // MARK: - Interaction State

  var interactionData = InteractionData()
  var isLoggingInteraction = false

  // MARK: - Metric State

  var newMetricData = NewMetricData()
  var isSavingMetric = false

  // MARK: - Coach State

  var selectedCoachId: String?
  var isUpdatingCoaches = false

  // MARK: - Delete State

  var isDeleting = false

  // MARK: - Success/Toast

  var successMessage: String?
  var showSuccessToast = false

  // MARK: - Export

  var exportFileURL: URL?

  // MARK: - Dependencies

  private let eventsService: EventsManaging
  private let authManager: any AuthManaging
  private let haptics = HapticFeedbackManager.shared
  let eventId: String

  // MARK: - Computed

  private var userId: String? {
    authManager.user?.id
  }

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

  var eventTypeDisplay: String {
    guard let event else { return "" }
    return EventType(rawValue: event.type)?.displayName ?? event.type
  }

  var coachesAtEvent: [Coach] {
    guard let presentIds = event?.coachesPresent else { return [] }
    return schoolCoaches.filter { presentIds.contains($0.id) }
  }

  var availableCoaches: [Coach] {
    let presentIds = Set(event?.coachesPresent ?? [])
    return schoolCoaches.filter { !presentIds.contains($0.id) }
  }

  var formattedCost: String? {
    guard let event, let cost = event.cost else { return nil }
    return cost == 0 ? "Free" : String(format: "$%.2f", cost)
  }

  var costAccessibilityLabel: String? {
    guard let event, let cost = event.cost else { return nil }
    return cost == 0 ? "Free event" : String(format: "Cost: $%.2f", cost)
  }

  // MARK: - Init

  nonisolated init(
    eventsService: EventsManaging = EventsServiceImpl(),
    authManager: any AuthManaging = AuthManager.shared,
    eventId: String
  ) {
    self.eventsService = eventsService
    self.authManager = authManager
    self.eventId = eventId
  }

  // MARK: - Load

  func loadAll() async {
    logger.debug("Loading event: \(self.eventId)")
    isLoading = true
    error = nil
    isNotFound = false
    defer { isLoading = false }

    guard let userId else {
      self.error = "You must be signed in to view this event."
      return
    }

    do {
      event = try await eventsService.fetchEvent(id: eventId, userId: userId)
      logger.info("Loaded event: \(self.eventId)")

      await loadRelatedData()
    } catch {
      logger.error("Failed to load event: \(error.localizedDescription)")
      if Self.isEventNotFound(error) {
        event = nil
        isNotFound = true
        self.error = nil
      } else {
        self.error = "Failed to load event. Please try again."
      }
    }
  }

  private static func isEventNotFound(_ error: Error) -> Bool {
    let ns = error as NSError
    if ns.code == 404 { return true }
    let msg = error.localizedDescription.lowercased()
    return msg.contains("not found") || msg.contains("404") || msg.contains("pgrst116")
  }

  private func loadRelatedData() async {
    guard let userId, let event else { return }

    async let coachesTask: () = loadCoaches(event: event, userId: userId)
    async let metricsTask: () = loadMetrics(userId: userId)

    _ = await (coachesTask, metricsTask)
  }

  private func loadCoaches(event: FullEvent, userId: String) async {
    guard let schoolId = event.schoolId, !schoolId.isEmpty else { return }
    do {
      schoolCoaches = try await eventsService.fetchCoaches(schoolId: schoolId, userId: userId)
      logger.info("Loaded \(self.schoolCoaches.count) coaches")
    } catch {
      logger.error("Failed to load coaches: \(error.localizedDescription)")
    }
  }

  private func loadMetrics(userId: String) async {
    do {
      metrics = try await eventsService.fetchMetrics(eventId: eventId, userId: userId)
      logger.info("Loaded \(self.metrics.count) metrics")
    } catch {
      logger.error("Failed to load metrics: \(error.localizedDescription)")
    }
  }

  // MARK: - Mark as Attended

  func markAsAttended() async {
    guard event?.attended != true else { return }
    isSaving = true
    defer { isSaving = false }

    do {
      let request = EventUpdateRequest(
        name: nil, type: nil, startDate: nil, endDate: nil,
        startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
        location: nil, address: nil, city: nil, state: nil,
        url: nil, description: nil, eventSource: nil, cost: nil,
        registered: nil, attended: true, performanceNotes: nil, coachesPresent: nil
      )
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      event = updated
      haptics.success()
      showSuccess("Marked as attended")
      showQuickLogSheet = true
      logger.info("Event marked as attended: \(self.eventId)")
    } catch {
      logger.error("Failed to mark attended: \(error.localizedDescription)")
      self.error = "Failed to update event. Please try again."
      haptics.error()
    }
  }

  // MARK: - Edit Event

  func openEditForm() {
    guard let event else { return }
    editData = EditEventData.from(event)
    showEditSheet = true
  }

  func updateEvent() async {
    isSaving = true
    defer { isSaving = false }

    do {
      let request = editData.toUpdateRequest()
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      event = updated
      showEditSheet = false
      haptics.success()
      showSuccess("Event updated")
      logger.info("Event updated: \(self.eventId)")
    } catch {
      logger.error("Failed to update event: \(error.localizedDescription)")
      self.error = "Failed to update event. Please try again."
      haptics.error()
    }
  }

  // MARK: - Delete Event

  func confirmDelete() {
    haptics.warning()
    showDeleteConfirmation = true
  }

  func deleteEvent() async {
    isDeleting = true
    defer { isDeleting = false }

    do {
      try await eventsService.deleteEvent(id: eventId)
      haptics.success()
      shouldDismiss = true
      logger.info("Event deleted: \(self.eventId)")
    } catch {
      logger.error("Failed to delete event: \(error.localizedDescription)")
      self.error = "Failed to delete event. Please try again."
      haptics.error()
    }
  }

  // MARK: - Quick Log Interaction

  func startQuickLog() {
    interactionData = InteractionData()
    showQuickLogSheet = true
  }

  func logInteraction() async {
    guard let userId else { return }
    isLoggingInteraction = true
    defer { isLoggingInteraction = false }

    do {
      let request = CreateInteractionRequest(
        userId: userId,
        eventId: eventId,
        coachId: interactionData.coachId,
        type: interactionData.type.rawValue,
        direction: interactionData.direction.rawValue,
        sentiment: interactionData.sentiment.rawValue,
        notes: interactionData.notes.isEmpty ? nil : interactionData.notes
      )
      try await eventsService.createInteraction(request)
      showQuickLogSheet = false
      haptics.success()
      showSuccess("Interaction logged")
      logger.info("Interaction logged for event: \(self.eventId)")
    } catch {
      logger.error("Failed to log interaction: \(error.localizedDescription)")
      self.error = "Failed to log interaction. Please try again."
      haptics.error()
    }
  }

  // MARK: - Metrics

  // MARK: - Coach Management

  func addCoach() async {
    guard let selectedCoachId, let event else { return }
    var currentCoaches = event.coachesPresent ?? []
    guard !currentCoaches.contains(selectedCoachId) else { return }

    isUpdatingCoaches = true
    defer {
      isUpdatingCoaches = false
      self.selectedCoachId = nil
      showAddCoach = false
    }

    currentCoaches.append(selectedCoachId)

    do {
      let request = EventUpdateRequest(
        name: nil, type: nil, startDate: nil, endDate: nil,
        startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
        location: nil, address: nil, city: nil, state: nil,
        url: nil, description: nil, eventSource: nil, cost: nil,
        registered: nil, attended: nil, performanceNotes: nil,
        coachesPresent: currentCoaches
      )
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      self.event = updated
      haptics.success()
      showSuccess("Coach added")
      logger.info("Coach added to event: \(self.eventId)")
    } catch {
      logger.error("Failed to add coach: \(error.localizedDescription)")
      self.error = "Failed to add coach. Please try again."
      haptics.error()
    }
  }

  func removeCoach(id coachId: String) async {
    guard let event else { return }
    let currentCoaches = (event.coachesPresent ?? []).filter { $0 != coachId }

    isUpdatingCoaches = true
    defer { isUpdatingCoaches = false }

    do {
      let request = EventUpdateRequest(
        name: nil, type: nil, startDate: nil, endDate: nil,
        startTime: nil, endTime: nil, checkinTime: nil, schoolId: nil,
        location: nil, address: nil, city: nil, state: nil,
        url: nil, description: nil, eventSource: nil, cost: nil,
        registered: nil, attended: nil, performanceNotes: nil,
        coachesPresent: currentCoaches
      )
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      self.event = updated
      haptics.success()
      showSuccess("Coach removed")
      logger.info("Coach removed from event: \(self.eventId)")
    } catch {
      logger.error("Failed to remove coach: \(error.localizedDescription)")
      self.error = "Failed to remove coach. Please try again."
      haptics.error()
    }
  }

  // MARK: - Metrics

  func startAddMetric() {
    newMetricData = NewMetricData()
    showMetricForm = true
  }

  func clearMetricForm() {
    newMetricData = NewMetricData()
    showMetricForm = false
  }

  func addMetric() async {
    guard let userId, let value = newMetricData.parsedValue else { return }
    isSavingMetric = true
    defer { isSavingMetric = false }

    do {
      let request = CreateMetricRequest(
        userId: userId,
        metricType: newMetricData.metricType.rawValue,
        value: value,
        unit: newMetricData.unit.isEmpty ? newMetricData.metricType.defaultUnit : newMetricData.unit,
        recordedDate: metricDateFormatter.string(from: Date()),
        eventId: eventId,
        verified: false,
        notes: newMetricData.notes.isEmpty ? nil : newMetricData.notes
      )
      let metric = try await eventsService.createMetric(request)
      metrics.append(metric)
      showMetricForm = false
      newMetricData = NewMetricData()
      haptics.success()
      showSuccess("Metric recorded")
      logger.info("Metric created: \(metric.id)")
    } catch {
      logger.error("Failed to save metric: \(error.localizedDescription)")
      self.error = "Failed to save metric. Please try again."
      haptics.error()
    }
  }

  func deleteMetric(id metricId: String) async {
    do {
      try await eventsService.deleteMetric(id: metricId)
      metrics.removeAll { $0.id == metricId }
      haptics.success()
      showSuccess("Metric deleted")
      logger.info("Metric deleted: \(metricId)")
    } catch {
      logger.error("Failed to delete metric: \(error.localizedDescription)")
      self.error = "Failed to delete metric. Please try again."
      haptics.error()
    }
  }

  // MARK: - Export Metrics

  func prepareCSVExport() {
    guard let event, !metrics.isEmpty else { return }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd"
    var rows: [String] = ["Metric Type,Value,Unit,Recorded Date,Verified,Notes"]
    for m in metrics {
      let notesEscaped = (m.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
      let notes = notesEscaped.isEmpty ? "" : "\"\(notesEscaped)\""
      let dateStr = dateFormatter.string(from: m.recordedDate)
      rows.append("\(m.displayName),\(m.value),\(m.unit),\(dateStr),\(m.verified),\(notes)")
    }
    let csv = rows.joined(separator: "\n")
    let fileName = "event-metrics-\(event.name.filter { $0.isLetter || $0.isNumber }).csv"
      .replacingOccurrences(of: " ", with: "-")
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(fileName)
    do {
      try csv.write(to: fileURL, atomically: true, encoding: .utf8)
      exportFileURL = fileURL
      logger.info("CSV export prepared: \(fileName)")
    } catch {
      logger.error("Failed to write CSV: \(error.localizedDescription)")
      self.error = "Failed to prepare export."
    }
  }

  func clearExport() {
    if let url = exportFileURL {
      try? FileManager.default.removeItem(at: url)
    }
    exportFileURL = nil
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

  private func showSuccess(_ message: String) {
    successMessage = message
    showSuccessToast = true
  }
}