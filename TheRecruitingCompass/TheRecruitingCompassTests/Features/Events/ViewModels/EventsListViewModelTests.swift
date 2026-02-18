import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventsListViewModelTests: XCTestCase {

  private var sut: EventsListViewModel!
  private var mockService: MockEventsService!
  private var mockAuth: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockService = MockEventsService()
    mockAuth = MockAuthManager()
    sut = EventsListViewModel(eventsService: mockService, authManager: mockAuth)
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuth = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState_isEmpty() {
    XCTAssertTrue(sut.events.isEmpty)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.error)
    XCTAssertEqual(sut.statusFilter, .all)
    XCTAssertNil(sut.typeFilter)
    XCTAssertEqual(sut.searchText, "")
  }

  // MARK: - Load Events

  func testLoadEvents_onSuccess_populatesEvents() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      .mock(id: "e1", name: "Spring Showcase"),
      .mock(id: "e2", name: "Summer Camp")
    ]

    await sut.loadEvents()

    XCTAssertEqual(sut.events.count, 2)
    XCTAssertNil(sut.error)
    XCTAssertEqual(mockService.fetchEventsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchEventsUserId, "user-1")
  }

  func testLoadEvents_onFailure_setsError() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.shouldThrowFetchEvents = true

    await sut.loadEvents()

    XCTAssertTrue(sut.events.isEmpty)
    XCTAssertNotNil(sut.error)
  }

  func testLoadEvents_noUser_skipsLoad() async {
    mockAuth.user = nil

    await sut.loadEvents()

    XCTAssertEqual(mockService.fetchEventsCallCount, 0)
  }

  func testLoadEvents_clearsErrorBeforeLoad() async {
    mockAuth.user = userMock(id: "user-1")
    sut.error = "Previous error"

    await sut.loadEvents()

    XCTAssertNil(sut.error)
  }

  func testLoadEvents_clearsLoadingAfterCompletion() async {
    mockAuth.user = userMock(id: "user-1")

    await sut.loadEvents()

    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - Filtering

  func testFilteredEvents_noFilters_returnsAll() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      .mock(id: "e1", name: "Showcase"),
      .mock(id: "e2", name: "Camp")
    ]
    await sut.loadEvents()

    XCTAssertEqual(sut.filteredEvents.count, 2)
  }

  func testFilteredEvents_bySearchText_filtersCorrectly() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      .mock(id: "e1", name: "Spring Showcase"),
      .mock(id: "e2", name: "Summer Camp")
    ]
    await sut.loadEvents()

    sut.searchText = "spring"

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.name, "Spring Showcase")
  }

  func testFilteredEvents_byType_filtersCorrectly() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      .mock(id: "e1", name: "Showcase Event", type: "showcase"),
      .mock(id: "e2", name: "Camp Event", type: "camp")
    ]
    await sut.loadEvents()

    sut.typeFilter = .camp

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.name, "Camp Event")
  }

  func testFilteredEvents_byAttendedStatus_filtersCorrectly() async {
    mockAuth.user = userMock(id: "user-1")
    let attended = fullEventMock(id: "e1", name: "Attended", registered: true, attended: true)
    let notAttended = fullEventMock(id: "e2", name: "Not Attended", registered: false, attended: false)
    mockService.stubbedEvents = [attended, notAttended]
    await sut.loadEvents()

    sut.statusFilter = .attended

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.name, "Attended")
  }

  func testFilteredEvents_caseInsensitiveSearch() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "e1", name: "Spring Showcase")]
    await sut.loadEvents()

    sut.searchText = "SPRING"

    XCTAssertEqual(sut.filteredEvents.count, 1)
  }

  // MARK: - Clear Filters

  func testClearFilters_resetsAllFilters() {
    sut.searchText = "test"
    sut.typeFilter = .showcase
    sut.statusFilter = .attended

    sut.clearFilters()

    XCTAssertEqual(sut.searchText, "")
    XCTAssertNil(sut.typeFilter)
    XCTAssertEqual(sut.statusFilter, .all)
  }

  // MARK: - Has Active Filters

  func testHasActiveFilters_noFilters_returnsFalse() {
    XCTAssertFalse(sut.hasActiveFilters)
  }

  func testHasActiveFilters_withSearch_returnsTrue() {
    sut.searchText = "something"
    XCTAssertTrue(sut.hasActiveFilters)
  }

  func testHasActiveFilters_withTypeFilter_returnsTrue() {
    sut.typeFilter = .camp
    XCTAssertTrue(sut.hasActiveFilters)
  }

  func testHasActiveFilters_withStatusFilter_returnsTrue() {
    sut.statusFilter = .registered
    XCTAssertTrue(sut.hasActiveFilters)
  }

  // MARK: - Upcoming / Past

  func testUpcomingEvents_returnsEventsOnOrAfterToday() async {
    mockAuth.user = userMock(id: "user-1")
    let future = fullEventMock(id: "e1", name: "Future", startDate: "2099-01-01")
    let past = fullEventMock(id: "e2", name: "Past", startDate: "2020-01-01")
    mockService.stubbedEvents = [future, past]
    await sut.loadEvents()

    XCTAssertEqual(sut.upcomingEvents.count, 1)
    XCTAssertEqual(sut.upcomingEvents.first?.name, "Future")
    XCTAssertEqual(sut.pastEvents.count, 1)
    XCTAssertEqual(sut.pastEvents.first?.name, "Past")
  }

  // MARK: - Helpers

  private func userMock(id: String) -> User {
    User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-02-17T00:00:00Z",
      updatedAt: "2026-02-17T00:00:00Z",
      role: .player
    )
  }

  private func fullEventMock(
    id: String = "e1",
    name: String = "Test Event",
    type: String = "showcase",
    startDate: String = "2026-04-15",
    registered: Bool = false,
    attended: Bool = false
  ) -> FullEvent {
    FullEvent(
      id: id, name: name, type: type,
      schoolId: nil, location: nil, address: nil, city: nil, state: nil,
      startDate: startDate, startTime: nil, endDate: nil, endTime: nil, checkinTime: nil,
      url: nil, description: nil, eventSource: nil, cost: nil,
      registered: registered, attended: attended, performanceNotes: nil,
      userId: "user-1", createdAt: "2026-02-17T00:00:00Z", updatedAt: "2026-02-17T00:00:00Z"
    )
  }
}
