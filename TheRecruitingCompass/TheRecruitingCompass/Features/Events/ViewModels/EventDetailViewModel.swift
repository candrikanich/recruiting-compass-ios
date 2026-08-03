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

  nonisolated deinit {}

  // MARK: - State

  var event: FullEvent?
  var schoolCoaches: [Coach] = []
  var metrics: [PerformanceMetric] = []
  var isLoading = false
  var errorMessage: String?
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

  // MARK: - Haptic Triggers

  var hapticSuccessTrigger = 0
  var hapticErrorTrigger = 0
  var hapticWarningTrigger = 0

  // MARK: - Dependencies

  private let eventsService: any EventsManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging
  private let exportService = MetricsExportService()
  let eventId: String

  // MARK: - Computed

  /// The user whose event data we read/write. When a parent is viewing an
  /// athlete, events and metrics belong to the athlete (mirrors web +
  /// OffersListViewModel); otherwise the logged-in user's own id.
  private var userId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  var formattedDateRange: String {
    guard let event else { return "" }
    return DateFormatting.isoDateRangeString(from: event.startDate, to: event.endDate)
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
    return cost == 0 ? "Free" : cost.formatted(.currency(code: "USD").precision(.fractionLength(2)))
  }

  var costAccessibilityLabel: String? {
    guard let event, let cost = event.cost else { return nil }
    return cost == 0 ? "Free event" : "Cost: \(cost.formatted(.currency(code: "USD").precision(.fractionLength(2))))"
  }

  // MARK: - Init

  init(
    eventsService: (any EventsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    eventId: String
  ) {
    self.eventsService = eventsService ?? EventsServiceImpl()
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.eventId = eventId
  }

  // MARK: - Loading Helper

  // MARK: - Load

  func loadAll() async {
    logger.debug("Loading event: \(self.eventId)")
    isLoading = true
    errorMessage = nil
    isNotFound = false
    defer { isLoading = false }

    guard let userId else {
      self.errorMessage = "You must be signed in to view this event."
      return
    }

    do {
      event = try await eventsService.fetchEvent(id: eventId, userId: userId)
      logger.info("Loaded event: \(self.eventId)")

      await loadRelatedData()
    } catch is CancellationError {
      logger.debug("Load event cancelled")
    } catch let error as URLError where error.code == .cancelled {
      logger.debug("Load event cancelled (request cancelled)")
    } catch {
      logger.error("Failed to load event: \(error.localizedDescription)")
      if Self.isEventNotFound(error) {
        event = nil
        isNotFound = true
        self.errorMessage = nil
      } else {
        self.errorMessage = "Failed to load event. Please try again."
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
      // intentionally silent: the event itself loaded fine; an empty
      // coaches-present list here just means the check-in picker is empty.
      logger.error("Failed to load coaches: \(error.localizedDescription)")
    }
  }

  private func loadMetrics(userId: String) async {
    do {
      metrics = try await eventsService.fetchMetrics(eventId: eventId, userId: userId)
      logger.info("Loaded \(self.metrics.count) metrics")
    } catch {
      // intentionally silent: secondary section on an already-loaded event;
      // an empty metrics list here just means nothing to show, not an error.
      logger.error("Failed to load metrics: \(error.localizedDescription)")
    }
  }

  // MARK: - Mark as Attended

  func markAsAttended() async {
    guard event?.attended != true else { return }
    await ViewModelHelpers.withLoading(set: { self.isSaving = $0 }) {
      do {
        let request = EventUpdateRequest(attended: true)
        let updated = try await eventsService.updateEvent(id: eventId, request: request)
        event = updated
        hapticSuccessTrigger += 1
        showSuccess("Marked as attended")
        showQuickLogSheet = true
        logger.info("Event marked as attended: \(self.eventId)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to update event. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
    }
  }

  // MARK: - Edit Event

  func openEditForm() {
    guard let event else { return }
    editData = EditEventData.from(event)
    showEditSheet = true
  }

  func updateEvent() async {
    await ViewModelHelpers.withLoading(set: { self.isSaving = $0 }) {
      do {
        let request = editData.toUpdateRequest()
        let updated = try await eventsService.updateEvent(id: eventId, request: request)
        event = updated
        showEditSheet = false
        hapticSuccessTrigger += 1
        showSuccess("Event updated")
        logger.info("Event updated: \(self.eventId)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to update event. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
    }
  }

  // MARK: - Delete Event

  func confirmDelete() {
    hapticWarningTrigger += 1
    showDeleteConfirmation = true
  }

  func deleteEvent() async {
    await ViewModelHelpers.withLoading(set: { self.isDeleting = $0 }) {
      do {
        try await eventsService.deleteEvent(id: eventId)
        hapticSuccessTrigger += 1
        shouldDismiss = true
        logger.info("Event deleted: \(self.eventId)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to delete event. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
    }
  }

  // MARK: - Quick Log Interaction

  func startQuickLog() {
    interactionData = InteractionData()
    showQuickLogSheet = true
  }

  func logInteraction() async {
    guard let userId else { return }
    await ViewModelHelpers.withLoading(set: { self.isLoggingInteraction = $0 }) {
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
        hapticSuccessTrigger += 1
        showSuccess("Interaction logged")
        logger.info("Interaction logged for event: \(self.eventId)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to log interaction. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
    }
  }

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
      let request = EventUpdateRequest(coachesPresent: currentCoaches)
      let updated = try await eventsService.updateEvent(id: eventId, request: request)
      self.event = updated
      hapticSuccessTrigger += 1
      showSuccess("Coach added")
      logger.info("Coach added to event: \(self.eventId)")
    } catch {
      logger.error("Failed to add coach: \(error.localizedDescription)")
      self.errorMessage = "Failed to add coach. Please try again."
      hapticErrorTrigger += 1
    }
  }

  func removeCoach(id coachId: String) async {
    guard let event else { return }
    let currentCoaches = (event.coachesPresent ?? []).filter { $0 != coachId }

    await ViewModelHelpers.withLoading(set: { self.isUpdatingCoaches = $0 }) {
      do {
        let request = EventUpdateRequest(coachesPresent: currentCoaches)
        let updated = try await eventsService.updateEvent(id: eventId, request: request)
        self.event = updated
        hapticSuccessTrigger += 1
        showSuccess("Coach removed")
        logger.info("Coach removed from event: \(self.eventId)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to remove coach. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
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
    await ViewModelHelpers.withLoading(set: { self.isSavingMetric = $0 }) {
      do {
        let request = CreateMetricRequest(
          userId: userId,
          metricType: newMetricData.metricType.rawValue,
          value: value,
          unit: newMetricData.unit.isEmpty ? newMetricData.metricType.defaultUnit : newMetricData.unit,
          recordedDate: DateFormatting.isoExportFormatter.string(from: Date()),
          eventId: eventId,
          verified: false,
          notes: newMetricData.notes.isEmpty ? nil : newMetricData.notes
        )
        let metric = try await eventsService.createMetric(request)
        metrics.append(metric)
        showMetricForm = false
        newMetricData = NewMetricData()
        hapticSuccessTrigger += 1
        showSuccess("Metric recorded")
        logger.info("Metric created: \(metric.id)")
      } catch {
        ViewModelHelpers.handleError(error, userMessage: "Failed to save metric. Please try again.", logger: logger) { self.errorMessage = $0 }
        hapticErrorTrigger += 1
      }
    }
  }

  func deleteMetric(id metricId: String) async {
    do {
      try await eventsService.deleteMetric(id: metricId)
      metrics.removeAll { $0.id == metricId }
      hapticSuccessTrigger += 1
      showSuccess("Metric deleted")
      logger.info("Metric deleted: \(metricId)")
    } catch {
      logger.error("Failed to delete metric: \(error.localizedDescription)")
      self.errorMessage = "Failed to delete metric. Please try again."
      hapticErrorTrigger += 1
    }
  }

  // MARK: - Export Metrics

  func prepareCSVExport() {
    guard let event, !metrics.isEmpty else { return }
    do {
      exportFileURL = try exportService.prepareCSV(metrics: metrics, eventName: event.name)
    } catch {
      logger.error("Failed to write CSV: \(error.localizedDescription)")
      self.errorMessage = "Failed to prepare export."
    }
  }

  func clearExport() {
    if let url = exportFileURL {
      exportService.cleanup(url: url)
    }
    exportFileURL = nil
  }

  func cleanupExport(url: URL) {
    exportService.cleanup(url: url)
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

  private func showSuccess(_ message: String) {
    successMessage = message
    showSuccessToast = true
  }


}