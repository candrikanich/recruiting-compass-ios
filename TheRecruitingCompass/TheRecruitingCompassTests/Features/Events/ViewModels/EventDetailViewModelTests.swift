import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventDetailViewModelTests: XCTestCase {

  private var sut: EventDetailViewModel!
  private var mockService: MockEventsService!
  private var mockAuthManager: MockAuthManager!

  override func setUp() async throws {
    mockService = MockEventsService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(User(
      id: "test-user-id",
      email: "test@example.com",
      emailConfirmedAt: "2025-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      role: .player
    ))
    mockService.stubbedFetchedEvent = .mock()
    sut = EventDetailViewModel(
      eventsService: mockService,
      authManager: mockAuthManager,
      eventId: "test-event-id"
    )
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.event)
    XCTAssertNil(sut.error)
    XCTAssertTrue(sut.schoolCoaches.isEmpty)
    XCTAssertTrue(sut.metrics.isEmpty)
    XCTAssertFalse(sut.showEditSheet)
    XCTAssertFalse(sut.showQuickLogSheet)
    XCTAssertFalse(sut.showDeleteConfirmation)
    XCTAssertFalse(sut.showMetricForm)
    XCTAssertFalse(sut.isSaving)
    XCTAssertFalse(sut.isLoggingInteraction)
    XCTAssertFalse(sut.isSavingMetric)
    XCTAssertFalse(sut.shouldDismiss)
    XCTAssertNil(sut.successMessage)
    XCTAssertFalse(sut.showSuccessToast)
    XCTAssertNil(sut.selectedCoachId)
  }

  // MARK: - loadAll

  func testLoadAll_populatesEventMetricsAndCoaches() async {
    let event = FullEvent.mock(schoolId: "school-1")
    mockService.stubbedFetchedEvent = event
    mockService.stubbedCoaches = [makeTestCoach(id: "c1"), makeTestCoach(id: "c2")]
    mockService.stubbedMetrics = [makeTestMetric(id: "m1")]

    await sut.loadAll()

    XCTAssertNotNil(sut.event)
    XCTAssertEqual(sut.event?.id, "event-1")
    XCTAssertEqual(sut.schoolCoaches.count, 2)
    XCTAssertEqual(sut.metrics.count, 1)
    XCTAssertNil(sut.error)
    XCTAssertFalse(sut.isLoading)
    XCTAssertEqual(mockService.fetchEventCallCount, 1)
    XCTAssertEqual(mockService.lastFetchEventId, "test-event-id")
    XCTAssertEqual(mockService.fetchCoachesCallCount, 1)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 1)
  }

  func testLoadAll_eventNotFound_setsError() async {
    mockService.shouldThrowFetchEvent = true

    await sut.loadAll()

    XCTAssertNil(sut.event)
    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to load event"))
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadAll_networkError_setsError() async {
    mockService.shouldThrowFetchEvent = true

    await sut.loadAll()

    XCTAssertNil(sut.event)
    XCTAssertNotNil(sut.error)
    XCTAssertFalse(sut.isLoading)
    XCTAssertEqual(mockService.fetchCoachesCallCount, 0)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 0)
  }

  func testLoadAll_noSchoolId_skipsCoachesFetch() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: nil)

    await sut.loadAll()

    XCTAssertEqual(mockService.fetchCoachesCallCount, 0)
    XCTAssertEqual(mockService.fetchMetricsCallCount, 1)
  }

  func testLoadAll_clearsErrorOnRetry() async {
    mockService.shouldThrowFetchEvent = true
    await sut.loadAll()
    XCTAssertNotNil(sut.error)

    mockService.shouldThrowFetchEvent = false
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    XCTAssertNil(sut.error)
    XCTAssertNotNil(sut.event)
  }

  func testLoadAll_clearsLoadingAfterSuccess() async {
    await sut.loadAll()
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadAll_clearsLoadingAfterFailure() async {
    mockService.shouldThrowFetchEvent = true
    await sut.loadAll()
    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - Mark as Attended

  func testMarkAsAttended_updatesEventAndShowsModal() async {
    mockService.stubbedFetchedEvent = .mock(attended: false)
    await sut.loadAll()

    let updatedEvent = FullEvent.mock(attended: true)
    mockService.stubbedUpdatedEvent = updatedEvent

    await sut.markAsAttended()

    XCTAssertEqual(sut.event?.attended, true)
    XCTAssertTrue(sut.showQuickLogSheet)
    XCTAssertFalse(sut.isSaving)
    XCTAssertEqual(sut.successMessage, "Marked as attended")
    XCTAssertEqual(mockService.updateEventCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateEventRequest?.attended, true)
  }

  func testMarkAsAttended_alreadyAttended_doesNothing() async {
    mockService.stubbedFetchedEvent = .mock(attended: true)
    await sut.loadAll()

    await sut.markAsAttended()

    XCTAssertEqual(mockService.updateEventCallCount, 0)
  }

  func testMarkAsAttended_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock(attended: false)
    await sut.loadAll()
    mockService.shouldThrowUpdateEvent = true

    await sut.markAsAttended()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to update event"))
    XCTAssertFalse(sut.isSaving)
  }

  // MARK: - Edit Event

  func testOpenEditForm_prefillsEditFormDataFromEvent() async {
    let event = FullEvent(
      id: "e1", name: "Spring Showcase", type: "showcase",
      schoolId: "s1", location: "Field 1", address: "123 Main St",
      city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: "09:00",
      endDate: "2026-04-16", endTime: "17:00", checkinTime: "08:00",
      url: "https://example.com", description: "A great event",
      eventSource: "prep_baseball", cost: 150.0,
      registered: true, attended: false,
      performanceNotes: "Good arm",
      userId: "test-user-id",
      createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: ["c1"],
      updatedAt: "2026-02-17T00:00:00Z"
    )
    mockService.stubbedFetchedEvent = event
    await sut.loadAll()

    sut.openEditForm()

    XCTAssertTrue(sut.showEditSheet)
    XCTAssertEqual(sut.editData.name, "Spring Showcase")
    XCTAssertEqual(sut.editData.type, .showcase)
    XCTAssertEqual(sut.editData.startDate, "2026-04-15")
    XCTAssertEqual(sut.editData.endDate, "2026-04-16")
    XCTAssertEqual(sut.editData.city, "Atlanta")
    XCTAssertEqual(sut.editData.state, "GA")
    XCTAssertEqual(sut.editData.cost, "150.0")
    XCTAssertEqual(sut.editData.performanceNotes, "Good arm")
    XCTAssertEqual(sut.editData.description, "A great event")
  }

  func testOpenEditForm_noEvent_doesNotShowSheet() {
    sut.openEditForm()
    XCTAssertFalse(sut.showEditSheet)
  }

  func testUpdateEvent_success_updatesEventAndClosesSheet() async {
    mockService.stubbedFetchedEvent = .mock(name: "Original")
    await sut.loadAll()
    sut.openEditForm()

    let updatedEvent = FullEvent.mock(name: "Updated Name")
    mockService.stubbedUpdatedEvent = updatedEvent

    await sut.updateEvent()

    XCTAssertEqual(sut.event?.name, "Updated Name")
    XCTAssertFalse(sut.showEditSheet)
    XCTAssertFalse(sut.isSaving)
    XCTAssertEqual(sut.successMessage, "Event updated")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(mockService.updateEventCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateEventId, "test-event-id")
  }

  func testUpdateEvent_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.openEditForm()
    mockService.shouldThrowUpdateEvent = true

    await sut.updateEvent()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to update event"))
    XCTAssertFalse(sut.isSaving)
  }

  // MARK: - Delete Event

  func testConfirmDelete_showsConfirmation() {
    sut.confirmDelete()
    XCTAssertTrue(sut.showDeleteConfirmation)
  }

  func testDeleteEvent_success_setsShouldDismiss() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    await sut.deleteEvent()

    XCTAssertTrue(sut.shouldDismiss)
    XCTAssertEqual(mockService.deleteEventCallCount, 1)
    XCTAssertEqual(mockService.lastDeleteEventId, "test-event-id")
  }

  func testDeleteEvent_failure_setsError() async {
    mockService.shouldThrowDeleteEvent = true

    await sut.deleteEvent()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to delete event"))
    XCTAssertFalse(sut.shouldDismiss)
  }

  // MARK: - Coach Management

  func testAddCoach_appendsToCoachesPresentAndUpdates() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: [])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1"), makeTestCoach(id: "c2")]
    await sut.loadAll()

    sut.selectedCoachId = "c1"
    let updatedEvent = FullEvent.mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedUpdatedEvent = updatedEvent

    await sut.addCoach()

    XCTAssertEqual(sut.event?.coachesPresent, ["c1"])
    XCTAssertNil(sut.selectedCoachId)
    XCTAssertEqual(mockService.updateEventCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateEventRequest?.coachesPresent, ["c1"])
    XCTAssertEqual(sut.successMessage, "Coach added")
  }

  func testRemoveCoach_removesFromCoachesPresentAndUpdates() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1", "c2"])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1"), makeTestCoach(id: "c2")]
    await sut.loadAll()

    let updatedEvent = FullEvent.mock(schoolId: "school-1", coachesPresent: ["c2"])
    mockService.stubbedUpdatedEvent = updatedEvent

    await sut.removeCoach(id: "c1")

    XCTAssertEqual(sut.event?.coachesPresent, ["c2"])
    XCTAssertEqual(mockService.updateEventCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateEventRequest?.coachesPresent, ["c2"])
    XCTAssertEqual(sut.successMessage, "Coach removed")
  }

  func testAvailableCoaches_filtersOutAlreadyPresentCoaches() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1"), makeTestCoach(id: "c2"), makeTestCoach(id: "c3")]
    await sut.loadAll()

    XCTAssertEqual(sut.availableCoaches.count, 2)
    XCTAssertTrue(sut.availableCoaches.contains(where: { $0.id == "c2" }))
    XCTAssertTrue(sut.availableCoaches.contains(where: { $0.id == "c3" }))
    XCTAssertFalse(sut.availableCoaches.contains(where: { $0.id == "c1" }))
  }

  func testCoachesAtEvent_filtersToOnlyPresentCoaches() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1"), makeTestCoach(id: "c2")]
    await sut.loadAll()

    XCTAssertEqual(sut.coachesAtEvent.count, 1)
    XCTAssertEqual(sut.coachesAtEvent.first?.id, "c1")
  }

  // MARK: - Quick Log Interaction

  func testStartQuickLog_resetsDataAndShowsSheet() {
    sut.interactionData.notes = "old notes"
    sut.startQuickLog()

    XCTAssertTrue(sut.showQuickLogSheet)
    XCTAssertTrue(sut.interactionData.notes.isEmpty)
    XCTAssertEqual(sut.interactionData.type, .inPersonVisit)
    XCTAssertEqual(sut.interactionData.direction, .inbound)
    XCTAssertEqual(sut.interactionData.sentiment, .neutral)
  }

  func testLogInteraction_success_closesModal() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.startQuickLog()
    sut.interactionData.notes = "Met coach at showcase"
    sut.interactionData.type = .inPersonVisit
    sut.interactionData.direction = .outbound
    sut.interactionData.sentiment = .positive

    await sut.logInteraction()

    XCTAssertFalse(sut.showQuickLogSheet)
    XCTAssertFalse(sut.isLoggingInteraction)
    XCTAssertEqual(sut.successMessage, "Interaction logged")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(mockService.createInteractionCallCount, 1)
    XCTAssertEqual(mockService.lastCreateInteractionRequest?.eventId, "test-event-id")
    XCTAssertEqual(mockService.lastCreateInteractionRequest?.userId, "test-user-id")
    XCTAssertEqual(mockService.lastCreateInteractionRequest?.type, "in_person_visit")
    XCTAssertEqual(mockService.lastCreateInteractionRequest?.direction, "outbound")
    XCTAssertEqual(mockService.lastCreateInteractionRequest?.sentiment, "positive")
  }

  func testLogInteraction_noContent_doesNotSubmit() async {
    mockAuthManager.user = nil
    sut.startQuickLog()
    sut.interactionData.notes = "Some notes"

    await sut.logInteraction()

    XCTAssertEqual(mockService.createInteractionCallCount, 0)
  }

  func testLogInteraction_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    mockService.shouldThrowCreateInteraction = true
    sut.startQuickLog()
    sut.interactionData.notes = "Test"

    await sut.logInteraction()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to log interaction"))
    XCTAssertFalse(sut.isLoggingInteraction)
  }

  func testLogInteraction_emptyNotes_sendsNilNotes() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.startQuickLog()
    sut.interactionData.notes = ""

    await sut.logInteraction()

    XCTAssertNil(mockService.lastCreateInteractionRequest?.notes)
  }

  // MARK: - Metrics

  func testStartAddMetric_resetsDataAndShowsForm() {
    sut.newMetricData.valueText = "92.5"
    sut.newMetricData.unit = "mph"
    sut.startAddMetric()

    XCTAssertTrue(sut.showMetricForm)
    XCTAssertTrue(sut.newMetricData.valueText.isEmpty)
    XCTAssertTrue(sut.newMetricData.unit.isEmpty)
  }

  func testAddMetric_success_appendsToMetrics() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    let createdMetric = makeTestMetric(id: "new-metric-1")
    mockService.stubbedCreatedMetric = createdMetric
    sut.startAddMetric()
    sut.newMetricData.valueText = "92.5"
    sut.newMetricData.metricType = .velocity
    sut.newMetricData.unit = "mph"

    await sut.addMetric()

    XCTAssertEqual(sut.metrics.count, 1)
    XCTAssertEqual(sut.metrics.first?.id, "new-metric-1")
    XCTAssertFalse(sut.showMetricForm)
    XCTAssertFalse(sut.isSavingMetric)
    XCTAssertEqual(sut.successMessage, "Metric recorded")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(mockService.createMetricCallCount, 1)
    XCTAssertEqual(mockService.lastCreateMetricRequest?.metricType, "velocity")
    XCTAssertEqual(mockService.lastCreateMetricRequest?.value, 92.5)
    XCTAssertEqual(mockService.lastCreateMetricRequest?.unit, "mph")
    XCTAssertEqual(mockService.lastCreateMetricRequest?.eventId, "test-event-id")
    XCTAssertEqual(mockService.lastCreateMetricRequest?.userId, "test-user-id")
  }

  func testAddMetric_invalidValue_doesNotSubmit() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.startAddMetric()
    sut.newMetricData.valueText = "not-a-number"

    await sut.addMetric()

    XCTAssertEqual(mockService.createMetricCallCount, 0)
  }

  func testAddMetric_noUser_doesNotSubmit() async {
    mockAuthManager.user = nil
    sut.startAddMetric()
    sut.newMetricData.valueText = "92.5"

    await sut.addMetric()

    XCTAssertEqual(mockService.createMetricCallCount, 0)
  }

  func testAddMetric_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    mockService.shouldThrowCreateMetric = true
    mockService.stubbedCreatedMetric = makeTestMetric(id: "will-fail")
    sut.startAddMetric()
    sut.newMetricData.valueText = "92.5"

    await sut.addMetric()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to save metric"))
    XCTAssertFalse(sut.isSavingMetric)
  }

  func testAddMetric_usesDefaultUnit_whenUnitEmpty() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    mockService.stubbedCreatedMetric = makeTestMetric(id: "m-default-unit")
    sut.startAddMetric()
    sut.newMetricData.valueText = "88.0"
    sut.newMetricData.metricType = .velocity
    sut.newMetricData.unit = ""

    await sut.addMetric()

    XCTAssertEqual(mockService.lastCreateMetricRequest?.unit, "mph")
  }

  func testAddMetric_resetsFormAfterSuccess() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    mockService.stubbedCreatedMetric = makeTestMetric(id: "m-reset")
    sut.startAddMetric()
    sut.newMetricData.valueText = "88.0"
    sut.newMetricData.metricType = .velocity
    sut.newMetricData.unit = "mph"
    sut.newMetricData.notes = "Good velocity"

    await sut.addMetric()

    XCTAssertTrue(sut.newMetricData.valueText.isEmpty)
    XCTAssertTrue(sut.newMetricData.unit.isEmpty)
    XCTAssertTrue(sut.newMetricData.notes.isEmpty)
  }

  func testDeleteMetric_removesFromList() async {
    mockService.stubbedFetchedEvent = .mock()
    mockService.stubbedMetrics = [makeTestMetric(id: "m1"), makeTestMetric(id: "m2")]
    await sut.loadAll()
    XCTAssertEqual(sut.metrics.count, 2)

    await sut.deleteMetric(id: "m1")

    XCTAssertEqual(sut.metrics.count, 1)
    XCTAssertEqual(sut.metrics.first?.id, "m2")
    XCTAssertEqual(mockService.deleteMetricCallCount, 1)
    XCTAssertEqual(mockService.lastDeleteMetricId, "m1")
    XCTAssertEqual(sut.successMessage, "Metric deleted")
  }

  // MARK: - Directions URL

  func testGetDirectionsURL_withAddress_returnsValidURL() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: "123 Main St",
      city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    let url = sut.getDirectionsURL()

    XCTAssertNotNil(url)
    XCTAssertTrue(url!.absoluteString.hasPrefix("maps://"))
    XCTAssertTrue(url!.absoluteString.contains("Atlanta"))
    XCTAssertTrue(url!.absoluteString.contains("123"))
  }

  func testGetDirectionsURL_noAddress_returnsNil() {
    XCTAssertNil(sut.getDirectionsURL())
  }

  // MARK: - Formatted Date Range

  func testFormattedDateRange_singleDay() async {
    mockService.stubbedFetchedEvent = .mock(startDate: "2026-04-15")
    await sut.loadAll()

    let result = sut.formattedDateRange
    XCTAssertFalse(result.isEmpty)
    XCTAssertFalse(result.contains("–"))
  }

  func testFormattedDateRange_multiDay() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Camp", type: "camp",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-06-01", startTime: nil,
      endDate: "2026-06-05", endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertTrue(sut.formattedDateRange.contains("–"))
  }

  func testFormattedDateRange_sameStartAndEnd_returnsSingleDate() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil,
      endDate: "2026-04-15", endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertFalse(sut.formattedDateRange.contains("–"))
  }

  func testFormattedDateRange_noEvent_returnsEmpty() {
    XCTAssertEqual(sut.formattedDateRange, "")
  }

  // MARK: - hasLocation

  func testHasLocation_withAddress_returnsTrue() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: "123 Main St",
      city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertTrue(sut.hasLocation)
  }

  func testHasLocation_withCityOnly_returnsTrue() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil,
      city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertTrue(sut.hasLocation)
  }

  func testHasLocation_noLocation_returnsFalse() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    XCTAssertFalse(sut.hasLocation)
  }

  // MARK: - eventTypeDisplay

  func testEventTypeDisplay_knownType_returnsDisplayName() async {
    mockService.stubbedFetchedEvent = .mock(type: "showcase")
    await sut.loadAll()

    XCTAssertEqual(sut.eventTypeDisplay, "Showcase")
  }

  func testEventTypeDisplay_unknownType_returnsRawValue() async {
    mockService.stubbedFetchedEvent = .mock(type: "unknown_type")
    await sut.loadAll()

    XCTAssertEqual(sut.eventTypeDisplay, "unknown_type")
  }

  // MARK: - formattedLocation

  func testFormattedLocation_cityAndState() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil,
      city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertEqual(sut.formattedLocation, "Atlanta, GA")
  }

  func testFormattedLocation_noLocation_returnsNil() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    XCTAssertNil(sut.formattedLocation)
  }

  // MARK: - formattedCost

  func testFormattedCost_withCost_returnsFormattedString() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: 150.0,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertEqual(sut.formattedCost, "$150.00")
  }

  func testFormattedCost_zeroCost_returnsFree() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: 0,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertEqual(sut.formattedCost, "Free")
  }

  func testFormattedCost_noCost_returnsNil() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    XCTAssertNil(sut.formattedCost)
  }

  // MARK: - Mark as Attended (isSaving)

  func testMarkAsAttended_clearsIsSavingAfterSuccess() async {
    mockService.stubbedFetchedEvent = .mock(attended: false)
    await sut.loadAll()
    mockService.stubbedUpdatedEvent = .mock(attended: true)

    await sut.markAsAttended()

    XCTAssertFalse(sut.isSaving)
  }

  func testMarkAsAttended_clearsIsSavingAfterFailure() async {
    mockService.stubbedFetchedEvent = .mock(attended: false)
    await sut.loadAll()
    mockService.shouldThrowUpdateEvent = true

    await sut.markAsAttended()

    XCTAssertFalse(sut.isSaving)
  }

  // MARK: - Update Event (service args)

  func testUpdateEvent_callsServiceWithCorrectId() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.openEditForm()
    mockService.stubbedUpdatedEvent = .mock()

    await sut.updateEvent()

    XCTAssertEqual(mockService.lastUpdateEventId, "test-event-id")
  }

  func testUpdateEvent_doesNotCloseSheet_onFailure() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()
    sut.openEditForm()
    XCTAssertTrue(sut.showEditSheet)
    mockService.shouldThrowUpdateEvent = true

    await sut.updateEvent()

    XCTAssertTrue(sut.showEditSheet)
  }

  // MARK: - Delete Event (edge cases)

  func testDeleteEvent_failure_doesNotSetShouldDismiss() async {
    mockService.shouldThrowDeleteEvent = true

    await sut.deleteEvent()

    XCTAssertFalse(sut.shouldDismiss)
    XCTAssertFalse(sut.isDeleting)
  }

  // MARK: - Add Coach (edge cases)

  func testAddCoach_noSelectedCoachId_doesNotCallService() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: [])
    await sut.loadAll()
    sut.selectedCoachId = nil

    await sut.addCoach()

    XCTAssertEqual(mockService.updateEventCallCount, 0)
  }

  func testAddCoach_duplicateCoach_doesNotCallService() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1")]
    await sut.loadAll()
    sut.selectedCoachId = "c1"

    await sut.addCoach()

    XCTAssertEqual(mockService.updateEventCallCount, 0)
  }

  func testAddCoach_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: [])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1")]
    await sut.loadAll()
    sut.selectedCoachId = "c1"
    mockService.shouldThrowUpdateEvent = true

    await sut.addCoach()

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to add coach"))
    XCTAssertFalse(sut.isUpdatingCoaches)
  }

  func testAddCoach_clearsSelectedCoachIdAfterSuccess() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: [])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1")]
    await sut.loadAll()
    sut.selectedCoachId = "c1"
    mockService.stubbedUpdatedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])

    await sut.addCoach()

    XCTAssertNil(sut.selectedCoachId)
    XCTAssertFalse(sut.showAddCoach)
  }

  // MARK: - Remove Coach (edge cases)

  func testRemoveCoach_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedCoaches = [makeTestCoach(id: "c1")]
    await sut.loadAll()
    mockService.shouldThrowUpdateEvent = true

    await sut.removeCoach(id: "c1")

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to remove coach"))
    XCTAssertFalse(sut.isUpdatingCoaches)
  }

  func testRemoveCoach_noEvent_doesNotCallService() async {
    await sut.removeCoach(id: "c1")

    XCTAssertEqual(mockService.updateEventCallCount, 0)
  }

  // MARK: - Delete Metric (edge cases)

  func testDeleteMetric_failure_setsError() async {
    mockService.stubbedFetchedEvent = .mock()
    mockService.stubbedMetrics = [makeTestMetric(id: "m1")]
    await sut.loadAll()
    mockService.shouldThrowDeleteMetric = true

    await sut.deleteMetric(id: "m1")

    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Failed to delete metric"))
    XCTAssertEqual(sut.metrics.count, 1, "Metric should not be removed on failure")
  }

  // MARK: - Clear Metric Form

  func testClearMetricForm_resetsDataAndHidesForm() {
    sut.newMetricData.valueText = "92.5"
    sut.newMetricData.unit = "mph"
    sut.showMetricForm = true

    sut.clearMetricForm()

    XCTAssertFalse(sut.showMetricForm)
    XCTAssertTrue(sut.newMetricData.valueText.isEmpty)
    XCTAssertTrue(sut.newMetricData.unit.isEmpty)
  }

  // MARK: - costAccessibilityLabel

  func testCostAccessibilityLabel_withCost_returnsLabel() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: 75.0,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertEqual(sut.costAccessibilityLabel, "Cost: $75.00")
  }

  func testCostAccessibilityLabel_zeroCost_returnsFreeEvent() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil,
      endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: 0,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z",
      coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadAll()

    XCTAssertEqual(sut.costAccessibilityLabel, "Free event")
  }

  func testCostAccessibilityLabel_noCost_returnsNil() async {
    mockService.stubbedFetchedEvent = .mock()
    await sut.loadAll()

    XCTAssertNil(sut.costAccessibilityLabel)
  }

  // MARK: - Load Related Data (silent failures)

  func testLoadAll_coachesFetchFails_doesNotSetError() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1")
    mockService.shouldThrowFetchCoaches = true

    await sut.loadAll()

    XCTAssertNotNil(sut.event)
    XCTAssertNil(sut.error, "Coaches fetch failure should be silent")
    XCTAssertTrue(sut.schoolCoaches.isEmpty)
  }

  func testLoadAll_metricsFetchFails_doesNotSetError() async {
    mockService.stubbedFetchedEvent = .mock()
    mockService.shouldThrowFetchMetrics = true

    await sut.loadAll()

    XCTAssertNotNil(sut.event)
    XCTAssertNil(sut.error, "Metrics fetch failure should be silent")
    XCTAssertTrue(sut.metrics.isEmpty)
  }

  // MARK: - Helpers

  private func makeTestCoach(id: String) -> Coach {
    Coach(
      id: id,
      firstName: "John",
      lastName: "Smith",
      email: "john@school.edu",
      phone: "555-1234",
      position: "Head Coach",
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      privateNotes: nil,
      responsivenessScore: 5.0,
      lastContactDate: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeTestMetric(id: String) -> PerformanceMetric {
    PerformanceMetric(
      id: id,
      userId: "test-user-id",
      metricType: .velocity,
      value: 92.5,
      unit: "mph",
      recordedDate: Date(),
      eventId: "test-event-id",
      verified: false,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
