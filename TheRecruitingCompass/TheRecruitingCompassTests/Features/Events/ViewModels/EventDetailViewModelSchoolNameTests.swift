import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventDetailViewModelSchoolNameTests: XCTestCase {
  nonisolated deinit {}

  private var sut: EventDetailViewModel!
  private var mockService: MockEventsService!

  override func setUp() async throws {
    mockService = MockEventsService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "test-user-id",
      email: "test@example.com",
      emailConfirmedAt: "2025-01-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      role: .player
    ))
    sut = EventDetailViewModel(eventsService: mockService, authManager: auth, eventId: "test-event-id")
  }

  override func tearDown() {
    sut = nil
    mockService = nil
  }

  func testLoadAll_resolvesSchoolNameFromEventSchool() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.stubbedSchoolName = "Stanford"

    await sut.loadAll()

    XCTAssertEqual(sut.schoolName, "Stanford")
    XCTAssertEqual(mockService.fetchSchoolNameCallCount, 1)
  }

  func testLoadAll_schoolNameLookupFailure_leavesNameNilAndEventLoaded() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: "school-1", coachesPresent: ["c1"])
    mockService.shouldThrowFetchSchoolName = true

    await sut.loadAll()

    XCTAssertNil(sut.schoolName)
    XCTAssertNotNil(sut.event)
    XCTAssertNil(sut.errorMessage)
  }

  func testLoadAll_eventWithoutSchool_skipsSchoolNameLookup() async {
    mockService.stubbedFetchedEvent = .mock(schoolId: nil)

    await sut.loadAll()

    XCTAssertNil(sut.schoolName)
    XCTAssertEqual(mockService.fetchSchoolNameCallCount, 0)
  }
}
