import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EventDetailFamilyStampTests: XCTestCase {
  nonisolated deinit {}

  private var sut: EventDetailViewModel!
  private var mockService: MockEventsService!

  override func setUp() async throws {
    mockService = MockEventsService()
    let mockAuth = MockAuthManager()
    let familyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuth)
    mockService.stubbedFetchedEvent = .mock()
    mockService.stubbedCreatedMetric = PerformanceMetric(
      id: "m-new", userId: ParentViewingAthleteFixture.athleteUserId, metricType: .velocity, value: 92.5,
      unit: "mph", recordedDate: Date(), eventId: "test-event-id", verified: false, notes: nil,
      createdAt: Date(), updatedAt: Date()
    )
    sut = EventDetailViewModel(
      eventsService: mockService,
      familyManager: familyManager,
      authManager: mockAuth,
      eventId: "test-event-id"
    )
    await sut.loadAll()
  }

  override func tearDown() {
    sut = nil
    mockService = nil
  }

  func testAddMetric_stampsActiveFamilyUnitId() async {
    sut.startAddMetric()
    sut.newMetricData.valueText = "92.5"
    sut.newMetricData.metricType = .velocity

    await sut.addMetric()

    XCTAssertEqual(mockService.lastCreateMetricRequest?.familyUnitId, ParentViewingAthleteFixture.familyUnitId)
  }

  func testLogInteraction_stampsActiveFamilyUnitId() async {
    sut.startQuickLog()
    sut.interactionData.notes = "Met coach"
    sut.interactionData.type = .inPersonVisit

    await sut.logInteraction()

    XCTAssertEqual(mockService.lastCreateInteractionRequest?.familyUnitId, ParentViewingAthleteFixture.familyUnitId)
  }
}
