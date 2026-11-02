import XCTest
@testable import TheRecruitingCompass

/// Family-scoped Recent Activity feed (#507): scoping, "You"/name labels, debounced reload.
@MainActor
final class ActivityFeedFamilyScopeTests: XCTestCase {
  nonisolated deinit {}
  var sut: ActivityFeedViewModel!
  var mockService: MockActivityFeedService!
  var mockAuthManager: MockAuthManager!
  var mockCache: InMemoryCache!
  var familyManager: FamilyManager!

  override func setUp() {
    super.setUp()
    mockService = MockActivityFeedService()
    mockAuthManager = MockAuthManager()
    mockCache = InMemoryCache()
    familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuthManager)
    familyManager.currentMember = Self.member(id: "m-me", userId: "test-user-id", familyUnitId: "family-1")
    sut = ActivityFeedViewModel(
      activityService: mockService,
      familyManager: familyManager,
      authManager: mockAuthManager,
      cache: mockCache,
      reloadDebounce: .milliseconds(50)
    )
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    mockCache = nil
    familyManager = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private static func member(
    id: String,
    userId: String,
    familyUnitId: String = "family-1",
    fullName: String? = nil,
    email: String = "member@example.com"
  ) -> FamilyMember {
    FamilyMember(
      id: id, userId: userId, familyUnitId: familyUnitId, role: "parent",
      addedAt: "2024-01-01T00:00:00Z",
      user: FamilyMemberUser(id: userId, email: email, fullName: fullName, role: "parent")
    )
  }

  private func authenticateUser(id: String = "test-user-id") {
    mockAuthManager.setMockUser(User(
      id: id, email: "test@example.com", emailConfirmedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", role: nil
    ))
  }

  private func makeInteraction(id: String, loggedBy: String = "test-user-id") -> Interaction {
    Interaction(
      id: id, type: .email, direction: .outbound, schoolId: "school-1", coachId: nil,
      subject: "Subject", content: "Content", sentiment: nil,
      occurredAt: "2026-02-10T10:00:00.000Z", loggedBy: loggedBy, attachments: nil,
      familyUnitId: "family-1", createdAt: "2026-02-10T10:00:00.000Z", updatedAt: nil
    )
  }

  private func makeStatusChange(id: String, changedBy: String) -> SchoolStatusHistory {
    SchoolStatusHistory(
      id: id, schoolId: "school-1", previousStatus: nil, newStatus: "researching",
      changedBy: changedBy, changedAt: Date(), notes: nil, createdAt: Date()
    )
  }

  // MARK: - Scoping

  func testLoadActivities_ScopesEveryFetchToActiveFamily_NotSignedInUser() async {
    authenticateUser(id: "specific-user")
    familyManager.currentMember = Self.member(id: "m", userId: "specific-user", familyUnitId: "active-family")

    await sut.loadActivities()

    XCTAssertEqual(mockService.lastFetchInteractionsFamilyUnitId, "active-family")
    XCTAssertEqual(mockService.lastFetchStatusChangesFamilyUnitId, "active-family")
    XCTAssertEqual(mockService.lastFetchDocumentsFamilyUnitId, "active-family")
  }

    func testLoadActivities_parentViewingAthlete_stillScopesToFamilyNotAthleteUser() async {
    let parentManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuthManager)
    sut = ActivityFeedViewModel(
      activityService: mockService,
      familyManager: parentManager,
      authManager: mockAuthManager,
      cache: mockCache
    )

    await sut.loadActivities()

    XCTAssertEqual(mockService.lastFetchInteractionsFamilyUnitId, ParentViewingAthleteFixture.familyUnitId)
    XCTAssertEqual(mockService.lastFetchDocumentsFamilyUnitId, ParentViewingAthleteFixture.familyUnitId)
  }

  func testLoadActivities_cacheIsPerFamily() async {
    authenticateUser()
    mockService.mockInteractions = [makeInteraction(id: "a")]
    await sut.loadActivities()

    familyManager.currentMember = Self.member(id: "m", userId: "test-user-id", familyUnitId: "family-2")
    mockService.mockInteractions = [makeInteraction(id: "b")]
    await sut.loadActivities()

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
    XCTAssertEqual(sut.activities.map(\.id), ["interaction-b"])
  }

  func testActorLabel_signedInUser_isYou() {
    authenticateUser(id: "me")
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "me"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "You")
  }

  func testActorLabel_otherMember_isTheirName() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m2", userId: "dad", fullName: "Dad Smith")]
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "dad"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "Dad Smith")
  }

  func testActorLabel_memberWithoutName_fallsBackToEmail() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m2", userId: "dad", fullName: " ", email: "dad@example.com")]
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "dad"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "dad@example.com")
  }

  func testActorLabel_memberWhoLeft_usesFallback() {
    authenticateUser(id: "me")
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "gone"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "Former member")
  }

  func testActorLabel_statusChangeAndDocument_resolveTheirActors() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m2", userId: "mom", fullName: "Mom")]
    let status = ActivityEventFactory.fromStatusChange(
      makeStatusChange(id: "s", changedBy: "mom"), schoolName: "UCLA")
    let document = ActivityEventFactory.fromDocument(
      DocumentRecord(id: "d", title: "T", type: nil, createdAt: "2026-02-10T10:00:00.000Z", userId: "me"))

    XCTAssertEqual(sut.actorLabel(for: status), "Mom")
    XCTAssertEqual(sut.actorLabel(for: document), "You")
  }

  func testScheduleDebouncedReload_burstCollapsesToOneForcedReload() async throws {
    authenticateUser()
    await sut.loadActivities()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    sut.scheduleDebouncedReload()
    sut.scheduleDebouncedReload()
    sut.scheduleDebouncedReload()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1, "must not reload before the debounce elapses")

    try await Task.sleep(for: .milliseconds(400))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2, "one reload, bypassing the 60s cache")
  }

  func testCancelPendingReload_preventsReload() async throws {
    authenticateUser()
    await sut.loadActivities()

    sut.scheduleDebouncedReload()
    sut.cancelPendingReload()
    try await Task.sleep(for: .milliseconds(300))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
  }
}
