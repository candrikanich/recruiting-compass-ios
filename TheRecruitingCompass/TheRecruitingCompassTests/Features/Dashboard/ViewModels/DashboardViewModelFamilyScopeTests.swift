import XCTest
@testable import TheRecruitingCompass

/// The dashboard shows family-wide interaction data: a parent and the athlete in one family see the same thing.
@MainActor
final class DashboardViewModelFamilyScopeTests: XCTestCase {
  nonisolated deinit {}
  private var sut: DashboardViewModel!
  private var mockAuthManager: MockAuthManager!
  private var mockDashboardService: MockDashboardService!
  private var mockFamilyService: MockFamilyService!
  private var familyManager: FamilyManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    mockDashboardService = MockDashboardService()
    mockFamilyService = MockFamilyService()
    familyManager = FamilyManager(familyService: mockFamilyService, authManager: mockAuthManager)
    sut = DashboardViewModel(
      authManager: mockAuthManager,
      dashboardService: mockDashboardService,
      taskStorage: MockQuickTaskStorage(),
      familyManager: familyManager,
      preferenceService: MockPreferenceService(),
      videoLinksService: MockVideoLinksService()
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    mockDashboardService = nil
    mockFamilyService = nil
    familyManager = nil
    super.tearDown()
  }

  func testTrendsScopeWindowAndLatestLookupToFamily() async {
    await signIn(userId: "parent-user-id", role: "parent")
    mockDashboardService.stubbedInteractions = [makeInteraction(id: "stale", date: "2024-01-15T10:00:00Z")]

    await sut.fetchInteractionTrends()

    XCTAssertEqual(mockDashboardService.lastFetchInteractionsSinceFamilyUnitId, "family-unit-1")
    XCTAssertEqual(mockDashboardService.lastFetchLatestInteractionFamilyUnitId, "family-unit-1")
  }

  func testParentAndAthleteSeeSameTrends() async {
    let recent = ISO8601DateFormatter().string(from: Date.now.addingTimeInterval(-86_400))
    mockDashboardService.stubbedInteractions = [
      makeInteraction(id: "by-parent", date: recent, loggedBy: "parent-user-id"),
      makeInteraction(id: "by-athlete", date: recent, loggedBy: "athlete-user-id"),
      makeInteraction(id: "other-family", date: recent, familyUnitId: "family-unit-2")
    ]

    await signIn(userId: "parent-user-id", role: "parent")
    await sut.fetchInteractionTrends()
    let parentCounts = sut.interactionTrends.map(\.count)

    familyManager.reset()
    await signIn(userId: "athlete-user-id", role: "player")
    await sut.fetchInteractionTrends()

    XCTAssertEqual(parentCounts.reduce(0, +), 2)
    XCTAssertEqual(sut.interactionTrends.map(\.count), parentCounts)
  }

  func testTrendsWithoutFamilyQueryNothing() async {
    mockAuthManager.setMockUser(makeUser(id: "parent-user-id"))

    await sut.fetchInteractionTrends()

    XCTAssertEqual(mockDashboardService.fetchInteractionsSinceCallCount, 0)
    XCTAssertTrue(sut.interactionTrends.isEmpty)
  }

  // MARK: - Helpers

  private func makeUser(id: String) -> User {
    User(
      id: id,
      email: "\(id)@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil,
      dateOfBirth: nil
    )
  }

  private func signIn(userId: String, role: String) async {
    mockAuthManager.setMockUser(makeUser(id: userId))
    mockFamilyService.stubbedFamilyUnit = FamilyUnit(
      id: "family-unit-1",
      createdByUserId: userId,
      familyName: "Test Family",
      familyCode: "FAM-123",
      codeGeneratedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
    mockFamilyService.stubbedCurrentMember = FamilyMember(
      id: "\(role)-member-id",
      userId: userId,
      familyUnitId: "family-unit-1",
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    await familyManager.loadFamilyData()
  }

  private func makeInteraction(
    id: String,
    date: String,
    loggedBy: String = "parent-user-id",
    familyUnitId: String = "family-unit-1"
  ) -> Interaction {
    Interaction(
      id: id,
      type: .email,
      direction: .outbound,
      schoolId: nil,
      coachId: nil,
      subject: nil,
      content: nil,
      sentiment: nil,
      occurredAt: date,
      loggedBy: loggedBy,
      attachments: nil,
      familyUnitId: familyUnitId,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }
}
