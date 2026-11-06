import XCTest
@testable import TheRecruitingCompass

/// Adding a recommended school must keep it off the widget even when the recommendations API serves a cached list
/// that still contains it (the web API caches per athlete for 2 minutes; iOS adds bypass that cache).
@MainActor
final class DashboardViewModelRecommendationsTests: XCTestCase {
  nonisolated deinit {}
  private var sut: DashboardViewModel!
  private var mockAuthManager: MockAuthManager!
  private var mockFamilyService: MockFamilyService!
  private var mockSchoolsService: MockSchoolsService!
  private var recommendationService: StubRecommendationService!
  private var familyManager: FamilyManager!
  private var clock: TestClock!

  private let ballState = SchoolRecommendation(
    catalogKey: "ball state university", name: "Ball State University", division: "D1", state: "IN",
    score: 2, reasons: []
  )
  private let mountUnion = SchoolRecommendation(
    catalogKey: "university of mount union", name: "University of Mount Union", division: "D3", state: "OH",
    score: 1, reasons: []
  )

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockSchoolsService = MockSchoolsService()
    mockSchoolsService.stubbedCreatedSchool = .mock(id: "school-1", name: "Ball State University")
    recommendationService = StubRecommendationService()
    familyManager = FamilyManager(familyService: mockFamilyService, authManager: mockAuthManager)
    clock = TestClock()
    let clock = clock!
    sut = DashboardViewModel(
      authManager: mockAuthManager,
      dashboardService: MockDashboardService(),
      taskStorage: MockQuickTaskStorage(),
      familyManager: familyManager,
      preferenceService: MockPreferenceService(),
      recommendationService: recommendationService,
      deadlinesService: MockDeadlinesService(),
      videoLinksService: MockVideoLinksService(),
      schoolsService: mockSchoolsService,
      now: { clock.now }
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    mockFamilyService = nil
    mockSchoolsService = nil
    recommendationService = nil
    familyManager = nil
    clock = nil
    super.tearDown()
  }

  func testAddedSchoolStaysHiddenWhenRefetchReturnsStaleList() async {
    await signInAsParent()
    recommendationService.stubbedRecommendations = [ballState, mountUnion]
    await sut.fetchRecommendations()

    await sut.addRecommendedSchool(ballState)

    XCTAssertEqual(mockSchoolsService.createSchoolCallCount, 1)
    XCTAssertEqual(sut.recommendations.map(\.catalogKey), [mountUnion.catalogKey])
    XCTAssertGreaterThan(recommendationService.fetchCallCount, 1, "add should refetch the dashboard")
  }

  func testAddedSchoolStaysHiddenOnLaterRefresh() async {
    await signInAsParent()
    recommendationService.stubbedRecommendations = [ballState, mountUnion]
    await sut.addRecommendedSchool(ballState)

    await sut.fetchRecommendations()

    XCTAssertEqual(sut.recommendations.map(\.catalogKey), [mountUnion.catalogKey])
  }

  func testFailedAddKeepsSchoolRecommended() async {
    await signInAsParent()
    recommendationService.stubbedRecommendations = [ballState, mountUnion]
    await sut.fetchRecommendations()
    mockSchoolsService.shouldThrowError = true

    await sut.addRecommendedSchool(ballState)
    await sut.fetchRecommendations()

    XCTAssertEqual(sut.recommendations.map(\.catalogKey), [ballState.catalogKey, mountUnion.catalogKey])
    XCTAssertNotNil(sut.errorMessage)
  }

  func testNoFamily_refusesToAddAndKeepsSchoolRecommended() async {
    mockAuthManager.setMockUser(User(
      id: "parent-user-id", email: "parent@example.com", emailConfirmedAt: nil, fullName: nil,
      createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", role: nil, dateOfBirth: nil
    ))
    recommendationService.stubbedRecommendations = [ballState, mountUnion]
    await sut.fetchRecommendations()

    await sut.addRecommendedSchool(ballState)

    XCTAssertEqual(mockSchoolsService.createSchoolCallCount, 0)
    XCTAssertEqual(sut.errorMessage, FamilyUnitID.MissingError.missing.errorDescription)
    XCTAssertEqual(sut.recommendations.map(\.catalogKey), [ballState.catalogKey, mountUnion.catalogKey])
  }

  func testAddedSchoolCanReturnOnceServerCacheExpires() async {
    await signInAsParent()
    recommendationService.stubbedRecommendations = [ballState, mountUnion]
    await sut.addRecommendedSchool(ballState)

    // E.g. the school was deleted from the Schools tab and the server recommends it again.
    clock.now = clock.now.addingTimeInterval(121)
    await sut.fetchRecommendations()

    XCTAssertEqual(sut.recommendations.map(\.catalogKey), [ballState.catalogKey, mountUnion.catalogKey])
  }

  func testOverFetchesByHiddenCountToFillWidget() async {
    await signInAsParent()
    let recs = (0..<8).map { index in
      SchoolRecommendation(catalogKey: "school \(index)", name: "School \(index)", score: 1, reasons: [])
    }
    recommendationService.stubbedRecommendations = recs
    await sut.addRecommendedSchool(recs[0])

    await sut.fetchRecommendations()

    XCTAssertEqual(recommendationService.lastLimit, 7)
    XCTAssertEqual(sut.recommendations.map(\.catalogKey), recs[1...6].map(\.catalogKey))
  }

  // MARK: - Helpers

  private func signInAsParent() async {
    mockAuthManager.setMockUser(
      User(
        id: "parent-user-id",
        email: "parent@example.com",
        emailConfirmedAt: "2024-01-01T00:00:00Z",
        fullName: nil,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        role: nil,
        dateOfBirth: nil
      )
    )
    mockFamilyService.stubbedFamilyUnit = FamilyUnit(
      id: "family-unit-1",
      createdByUserId: "parent-user-id",
      familyName: "Test Family",
      familyCode: "FAM-123",
      codeGeneratedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
    mockFamilyService.stubbedCurrentMember = FamilyMember(
      id: "parent-member-id",
      userId: "parent-user-id",
      familyUnitId: "family-unit-1",
      role: "parent",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    await familyManager.loadFamilyData()
  }
}

/// Serves the same list on every fetch, like the API's 2-minute cache does right after an add.
private final class StubRecommendationService: SchoolRecommendationManaging, @unchecked Sendable {
  var stubbedRecommendations: [SchoolRecommendation] = []
  var fetchCallCount = 0
  var lastLimit: Int?

  func fetchRecommendations(athleteId: String, limit: Int) async throws -> [SchoolRecommendation] {
    fetchCallCount += 1
    lastLimit = limit
    return Array(stubbedRecommendations.prefix(limit))
  }

  func dismissRecommendation(catalogKey: String, athleteId: String) async throws {}
}

private final class TestClock: @unchecked Sendable {
  var now = Date(timeIntervalSince1970: 1_800_000_000)
}
