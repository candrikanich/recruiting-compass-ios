import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventsListViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: EventsListViewModel!
  private var mockService: MockEventsService!
  private var mockAuth: MockAuthManager!
  private var mockCache: InMemoryCache!

  override func setUp() {
    super.setUp()
    mockService = MockEventsService()
    mockAuth = MockAuthManager()
    // Fresh instance per test — InMemoryCache.shared would leak state across tests.
    mockCache = InMemoryCache()
    sut = EventsListViewModel(eventsService: mockService, authManager: mockAuth, cache: mockCache)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: "eventsSortBy")
    sut = nil
    mockService = nil
    mockAuth = nil
    mockCache = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState_isEmpty() {
    XCTAssertTrue(sut.events.isEmpty)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
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
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(mockService.fetchEventsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchEventsUserId, "user-1")
  }

  func testLoadEvents_onFailure_setsError() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.shouldThrowFetchEvents = true

    await sut.loadEvents()

    XCTAssertTrue(sut.events.isEmpty)
    XCTAssertNotNil(sut.errorMessage)
  }

  func testLoadEvents_noUser_skipsLoad() async {
    mockAuth.user = nil

    await sut.loadEvents()

    XCTAssertEqual(mockService.fetchEventsCallCount, 0)
  }

  func testLoadEvents_clearsErrorBeforeLoad() async {
    mockAuth.user = userMock(id: "user-1")
    sut.errorMessage = "Previous error"

    await sut.loadEvents()

    XCTAssertNil(sut.errorMessage)
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

  // MARK: - Date Range Filter

  func testFilteredEvents_byUpcoming_returnsOnlyFutureEvents() async {
    mockAuth.user = userMock(id: "user-1")
    let future = fullEventMock(id: "e1", name: "Future", startDate: "2099-01-01")
    let past = fullEventMock(id: "e2", name: "Past", startDate: "2020-01-01")
    mockService.stubbedEvents = [future, past]
    await sut.loadEvents()

    sut.dateRangeFilter = .upcoming

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.name, "Future")
  }

  func testFilteredEvents_byPast_returnsOnlyPastEvents() async {
    mockAuth.user = userMock(id: "user-1")
    let future = fullEventMock(id: "e1", name: "Future", startDate: "2099-01-01")
    let past = fullEventMock(id: "e2", name: "Past", startDate: "2020-01-01")
    mockService.stubbedEvents = [future, past]
    await sut.loadEvents()

    sut.dateRangeFilter = .past

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.name, "Past")
  }

  func testFilteredEvents_allDateRange_returnsAll() async {
    mockAuth.user = userMock(id: "user-1")
    let future = fullEventMock(id: "e1", startDate: "2099-01-01")
    let past = fullEventMock(id: "e2", startDate: "2020-01-01")
    mockService.stubbedEvents = [future, past]
    await sut.loadEvents()

    sut.dateRangeFilter = .all

    XCTAssertEqual(sut.filteredEvents.count, 2)
  }

  func testHasActiveFilters_withDateRangeFilter_returnsTrue() {
    sut.dateRangeFilter = .upcoming
    XCTAssertTrue(sut.hasActiveFilters)
  }

  func testClearFilters_resetsDateRangeFilter() {
    sut.dateRangeFilter = .upcoming
    sut.clearFilters()
    XCTAssertEqual(sut.dateRangeFilter, .all)
  }

  // MARK: - Sort

  func testFilteredEvents_sortByDateAsc_sortsOldestFirst() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      fullEventMock(id: "e1", name: "Later", startDate: "2026-06-01"),
      fullEventMock(id: "e2", name: "Earlier", startDate: "2026-03-01")
    ]
    await sut.loadEvents()

    sut.sortBy = .dateAsc

    XCTAssertEqual(sut.filteredEvents.first?.name, "Earlier")
    XCTAssertEqual(sut.filteredEvents.last?.name, "Later")
  }

  func testFilteredEvents_sortByName_sortsAlphabetically() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      fullEventMock(id: "e1", name: "Zebra Camp"),
      fullEventMock(id: "e2", name: "Alpha Showcase")
    ]
    await sut.loadEvents()

    sut.sortBy = .name

    XCTAssertEqual(sut.filteredEvents.first?.name, "Alpha Showcase")
    XCTAssertEqual(sut.filteredEvents.last?.name, "Zebra Camp")
  }

  func testSortBy_persistsAcrossViewModelRecreation() {
    sut.sortBy = .name

    let sut2 = EventsListViewModel(eventsService: mockService, authManager: mockAuth)

    XCTAssertEqual(sut2.sortBy, .name)
  }

  func testSortBy_defaultsToDateDescOnFirstLaunch() {
    UserDefaults.standard.removeObject(forKey: "eventsSortBy")
    let freshSut = EventsListViewModel(eventsService: mockService, authManager: mockAuth)
    XCTAssertEqual(freshSut.sortBy, .dateDesc)
  }

  // MARK: - Cached filteredEvents Staleness Tests
  // filteredEvents is a cached stored property (Phase 3.3), recomputed via
  // didSet on events/searchText/typeFilter/statusFilter/dateRangeFilter and
  // sortBy's custom setter — not read live.

  func testFilteredEvents_UpdatesWhenEventsReassigned_WithoutTouchingFilters() {
    sut.events = [fullEventMock(id: "1", type: "showcase")]
    sut.typeFilter = .showcase
    XCTAssertEqual(sut.filteredEvents.count, 1)

    sut.events = [
      fullEventMock(id: "2", type: "showcase"),
      fullEventMock(id: "3", type: "camp")
    ]

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.id, "2")
  }

  func testFilteredEvents_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = fullEventMock(id: "keep", type: "showcase")
    let remove = fullEventMock(id: "remove", type: "showcase")
    sut.events = [keep, remove]
    sut.typeFilter = .showcase
    XCTAssertEqual(sut.filteredEvents.count, 2)

    await sut.deleteEvent(id: "remove")

    XCTAssertEqual(sut.filteredEvents.count, 1)
    XCTAssertEqual(sut.filteredEvents.first?.id, "keep")
  }

  func testFilteredEvents_UpdatesWhenSortByChangedAfterLoad() {
    sut.events = [
      fullEventMock(id: "1", name: "Zebra Camp"),
      fullEventMock(id: "2", name: "Alpha Camp")
    ]
    sut.sortBy = .name

    XCTAssertEqual(sut.filteredEvents.first?.name, "Alpha Camp")
  }

  // MARK: - List Fetch Caching Tests (Phase 3.6)

  func testLoadEvents_SecondLoad_UsesCacheAndSkipsService() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "e1", name: "Spring Showcase")]

    await sut.loadEvents()
    XCTAssertEqual(mockService.fetchEventsCallCount, 1)

    mockService.stubbedEvents = [.mock(id: "e2", name: "Summer Camp")]
    await sut.loadEvents()

    XCTAssertEqual(mockService.fetchEventsCallCount, 1)
    XCTAssertEqual(sut.events.first?.id, "e1")
  }

  func testDeleteEvent_InvalidatesListCache_NextLoadRefetches() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "e1", name: "Event")]
    await sut.loadEvents()
    XCTAssertEqual(mockService.fetchEventsCallCount, 1)

    await sut.deleteEvent(id: "e1")

    mockService.stubbedEvents = []
    await sut.loadEvents()

    XCTAssertEqual(mockService.fetchEventsCallCount, 2)
  }

  func testEventDetailOrCreateViewModel_Mutation_InvalidatesEventsListCache() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "e1", name: "Event")]
    await sut.loadEvents()
    XCTAssertEqual(mockService.fetchEventsCallCount, 1)

    // Simulate what EventDetailViewModel/CreateEventViewModel do on
    // edit/attended-toggle/create/delete: invalidate the same cache key via
    // the shared ListCacheKeys builder.
    await mockCache.remove(forKey: ListCacheKeys.events(userId: "user-1"))

    mockService.stubbedEvents = [.mock(id: "e1", name: "Event"), .mock(id: "e2", name: "New Event")]
    await sut.loadEvents()

    XCTAssertEqual(mockService.fetchEventsCallCount, 2)
    XCTAssertEqual(sut.events.count, 2)
  }

  // MARK: - Delete

  func testDeleteEvent_removesEventFromList() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      .mock(id: "e1", name: "Keep"),
      .mock(id: "e2", name: "Delete Me")
    ]
    await sut.loadEvents()

    await sut.deleteEvent(id: "e2")

    XCTAssertEqual(sut.events.count, 1)
    XCTAssertEqual(sut.events.first?.name, "Keep")
    XCTAssertEqual(mockService.deleteEventCallCount, 1)
    XCTAssertEqual(mockService.lastDeleteEventId, "e2")
  }

  func testDeleteEvent_onFailure_setsError() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "e1", name: "Event")]
    await sut.loadEvents()
    mockService.shouldThrowDeleteEvent = true

    await sut.deleteEvent(id: "e1")

    XCTAssertEqual(sut.events.count, 1) // not removed on failure
    XCTAssertNotNil(sut.errorMessage)
  }

  func testDeleteEvent_callsServiceWithCorrectId() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [.mock(id: "abc-123", name: "Event")]
    await sut.loadEvents()

    await sut.deleteEvent(id: "abc-123")

    XCTAssertEqual(mockService.lastDeleteEventId, "abc-123")
  }

  // MARK: - Calendar

  func testCalendarDays_returns42Days() {
    XCTAssertEqual(sut.calendarDays.count, 42)
  }

  func testCalendarDays_firstDayIsSunday() {
    let calendar = Calendar.current
    let firstDay = sut.calendarDays.first!
    XCTAssertEqual(calendar.component(.weekday, from: firstDay), 1) // 1 = Sunday
  }

  func testCurrentMonthTitle_formatsCorrectly() {
    XCTAssertFalse(sut.currentMonthTitle.isEmpty)
    XCTAssertTrue(sut.currentMonthTitle.contains(String(Calendar.current.component(.year, from: Date()))))
  }

  func testHasEvent_returnsTrueWhenEventOnDate() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [fullEventMock(id: "e1", startDate: "2099-06-15")]
    await sut.loadEvents()

    var components = DateComponents()
    components.year = 2099; components.month = 6; components.day = 15
    let date = Calendar.current.date(from: components)!

    XCTAssertTrue(sut.hasEvent(on: date))
  }

  func testHasEvent_returnsFalseWhenNoEventOnDate() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [fullEventMock(id: "e1", startDate: "2099-06-15")]
    await sut.loadEvents()

    var components = DateComponents()
    components.year = 2099; components.month = 6; components.day = 16
    let date = Calendar.current.date(from: components)!

    XCTAssertFalse(sut.hasEvent(on: date))
  }

  func testNavigateToPreviousMonth_decrementsMonth() {
    let initial = sut.currentMonth
    sut.navigateToPreviousMonth()
    let previous = sut.currentMonth
    XCTAssertEqual(
      Calendar.current.dateComponents([.month], from: previous, to: initial).month, 1
    )
  }

  func testNavigateToNextMonth_incrementsMonth() {
    let initial = sut.currentMonth
    sut.navigateToNextMonth()
    let next = sut.currentMonth
    XCTAssertEqual(
      Calendar.current.dateComponents([.month], from: initial, to: next).month, 1
    )
  }

  func testEventsForDate_returnsMatchingEvents() async {
    mockAuth.user = userMock(id: "user-1")
    mockService.stubbedEvents = [
      fullEventMock(id: "e1", name: "June Event", startDate: "2099-06-15"),
      fullEventMock(id: "e2", name: "July Event", startDate: "2099-07-01")
    ]
    await sut.loadEvents()

    var components = DateComponents()
    components.year = 2099; components.month = 6; components.day = 15
    let date = Calendar.current.date(from: components)!

    let result = sut.eventsForDate(date)
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.name, "June Event")
  }

  func testNavigateToPreviousMonth_stopsAtTwoYearsBack() {
    for _ in 0..<25 {
      sut.navigateToPreviousMonth()
    }
    let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
    let limit = Calendar.current.dateComponents([.year, .month], from: twoYearsAgo)
    let current = Calendar.current.dateComponents([.year, .month], from: sut.currentMonth)
    XCTAssertEqual(current.year, limit.year)
    XCTAssertEqual(current.month, limit.month)
  }

  func testNavigateToNextMonth_stopsAtTwoYearsAhead() {
    for _ in 0..<25 {
      sut.navigateToNextMonth()
    }
    let twoYearsAhead = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
    let limit = Calendar.current.dateComponents([.year, .month], from: twoYearsAhead)
    let current = Calendar.current.dateComponents([.year, .month], from: sut.currentMonth)
    XCTAssertEqual(current.year, limit.year)
    XCTAssertEqual(current.month, limit.month)
  }

  // MARK: - Athlete Targeting

  func testLoadEvents_parentViewingAthlete_usesAthleteUserId() async {
    let familyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuth)
    sut = EventsListViewModel(
      eventsService: mockService,
      familyManager: familyManager,
      authManager: mockAuth
    )

    await sut.loadEvents()

    XCTAssertEqual(mockService.lastFetchEventsUserId, ParentViewingAthleteFixture.athleteUserId)
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
      userId: "user-1", createdAt: "2026-02-17T00:00:00Z", coachesPresent: nil, updatedAt: "2026-02-17T00:00:00Z"
    )
  }
}
