import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventDetailViewModelTests: XCTestCase {

  private var sut: EventDetailViewModel!
  private var mockService: MockEventsService!

  override func setUp() {
    super.setUp()
    mockService = MockEventsService()
    sut = EventDetailViewModel(eventsService: mockService, eventId: "test-event-id")
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState_isNotLoading() {
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.event)
    XCTAssertNil(sut.error)
  }

  // MARK: - Load Event

  func testLoadEvent_onSuccess_populatesEvent() async {
    mockService.stubbedFetchedEvent = .mock(id: "test-event-id", name: "Spring Showcase")

    await sut.loadEvent()

    XCTAssertNotNil(sut.event)
    XCTAssertEqual(sut.event?.id, "test-event-id")
    XCTAssertEqual(sut.event?.name, "Spring Showcase")
    XCTAssertNil(sut.error)
    XCTAssertEqual(mockService.fetchEventCallCount, 1)
    XCTAssertEqual(mockService.lastFetchEventId, "test-event-id")
  }

  func testLoadEvent_onFailure_setsError() async {
    mockService.shouldThrowFetchEvent = true

    await sut.loadEvent()

    XCTAssertNil(sut.event)
    XCTAssertNotNil(sut.error)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadEvent_clearsLoadingAfterSuccess() async {
    await sut.loadEvent()

    XCTAssertFalse(sut.isLoading)
  }

  func testLoadEvent_clearsLoadingAfterFailure() async {
    mockService.shouldThrowFetchEvent = true

    await sut.loadEvent()

    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - Formatted Date Range

  func testFormattedDateRange_singleDay_returnsStartDate() async {
    mockService.stubbedFetchedEvent = .mock(startDate: "2026-04-15")
    await sut.loadEvent()

    let result = sut.formattedDateRange

    XCTAssertFalse(result.isEmpty)
    XCTAssertTrue(result.contains("Apr") || result.contains("15"))
  }

  func testFormattedDateRange_endDateSameAsStart_returnsSingleDate() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil,
      endDate: "2026-04-15", endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadEvent()

    XCTAssertFalse(sut.formattedDateRange.contains("–"))
  }

  func testFormattedDateRange_differentEndDate_returnsRange() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "camp",
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: "2026-06-01", startTime: nil,
      endDate: "2026-06-05", endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadEvent()

    XCTAssertTrue(sut.formattedDateRange.contains("–"))
  }

  // MARK: - Location

  func testHasLocation_withAddress_returnsTrue() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: "123 Main St", city: nil, state: nil,
      startDate: "2026-04-15", startTime: nil, endDate: nil, endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadEvent()

    XCTAssertTrue(sut.hasLocation)
  }

  func testHasLocation_withCity_returnsTrue() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: nil, city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: nil, endDate: nil, endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadEvent()

    XCTAssertTrue(sut.hasLocation)
  }

  func testHasLocation_noLocation_returnsFalse() async {
    await sut.loadEvent()

    XCTAssertFalse(sut.hasLocation)
  }

  // MARK: - Directions URL

  func testGetDirectionsURL_withFullAddress_buildsURL() async {
    mockService.stubbedFetchedEvent = FullEvent(
      id: "e1", name: "Test", type: "showcase",
      schoolId: nil, location: nil, address: "123 Main St", city: "Atlanta", state: "GA",
      startDate: "2026-04-15", startTime: nil, endDate: nil, endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil,
      userId: "u1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
    await sut.loadEvent()

    let url = sut.getDirectionsURL()

    XCTAssertNotNil(url)
    XCTAssertTrue(url?.absoluteString.hasPrefix("maps://") ?? false)
    XCTAssertTrue(url?.absoluteString.contains("Atlanta") ?? false)
  }

  func testGetDirectionsURL_noLocation_returnsNil() async {
    await sut.loadEvent()

    XCTAssertNil(sut.getDirectionsURL())
  }
}
