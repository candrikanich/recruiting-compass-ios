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
  var mockRealtime: MockActivityRealtimeService!

  override func setUp() {
    super.setUp()
    mockService = MockActivityFeedService()
    mockAuthManager = MockAuthManager()
    mockCache = InMemoryCache()
    mockRealtime = MockActivityRealtimeService()
    familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuthManager)
    familyManager.currentMember = Self.member(id: "m-me", userId: "test-user-id", familyUnitId: "family-1")
    sut = ActivityFeedViewModel(
      activityService: mockService,
      familyManager: familyManager,
      authManager: mockAuthManager,
      cache: mockCache,
      reloadDebounce: .milliseconds(50),
      realtime: mockRealtime
    )
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    mockCache = nil
    familyManager = nil
    mockRealtime = nil
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

  private func makeStatusChange(id: String, changedBy: String?) -> SchoolStatusHistory {
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

  func testActorLabel_membersNotLoaded_isNeutralNotFormer() {
    authenticateUser(id: "me")
    familyManager.familyMembers = []
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "dad"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "A family member")
  }

  func testActorLabel_membersOfPreviousFamilyOnly_isNeutralNotFormer() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m2", userId: "dad", familyUnitId: "other-family", fullName: "Dad")]
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "dad"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "A family member")
  }

  func testActorLabel_nilActor_isFormerMember() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m-me", userId: "me")]
    let event = ActivityEventFactory.fromStatusChange(makeStatusChange(id: "s", changedBy: nil), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "A former family member")
  }

  func testActorLabel_memberWhoLeft_usesFallback() {
    authenticateUser(id: "me")
    familyManager.familyMembers = [Self.member(id: "m-me", userId: "me")]
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "i", loggedBy: "gone"), schoolName: nil)

    XCTAssertEqual(sut.actorLabel(for: event), "A former family member")
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

  func testScheduleDebouncedReload_callsInsideTheWindowRestartTheTimer() async throws {
    authenticateUser()
    let slow = ActivityFeedViewModel(
      activityService: mockService, familyManager: familyManager, authManager: mockAuthManager,
      cache: mockCache, reloadDebounce: .milliseconds(400), realtime: mockRealtime
    )
    await slow.loadActivities()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    slow.scheduleDebouncedReload()
    try await Task.sleep(for: .milliseconds(200))
    slow.scheduleDebouncedReload()
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1, "500 ms in, but only 300 ms since the last call")

    try await Task.sleep(for: .milliseconds(500))
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2, "one reload, bypassing the 60 s cache")
  }

  func testCancelPendingReload_preventsReload() async throws {
    authenticateUser()
    await sut.loadActivities()

    sut.scheduleDebouncedReload()
    sut.cancelPendingReload()
    try await Task.sleep(for: .milliseconds(300))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
  }

  func testAddRealtimeEvent_alreadyInFeedAfterReload_isNotDoubled() async {
    authenticateUser()
    mockService.mockInteractions = [makeInteraction(id: "dup")]
    await sut.loadActivities()
    let racing = ActivityEventFactory.fromInteraction(makeInteraction(id: "dup"), schoolName: nil)

    sut.addRealtimeEvent(racing, forFamily: "family-1")

    XCTAssertEqual(sut.activities.map(\.id), ["interaction-dup"])
  }

  // MARK: - Races and lifecycle

  func testLoadActivities_staleFetchForPreviousFamily_doesNotOverwriteNewFamilyFeed() async {
    authenticateUser()
    mockService.interactionsByFamily = [
      "family-A": [makeInteraction(id: "from-A")],
      "family-B": [makeInteraction(id: "from-B")]
    ]
    let gate = FetchGate()
    mockService.beforeFetchInteractions = { family in
      if family == "family-A" { await gate.wait() }
    }
    familyManager.currentMember = Self.member(id: "m", userId: "test-user-id", familyUnitId: "family-A")
    let staleLoad = Task { await sut.loadActivities(forceRefresh: true) }
    await gate.waitUntilWaiting()

    familyManager.currentMember = Self.member(id: "m", userId: "test-user-id", familyUnitId: "family-B")
    await sut.loadActivities()
    await gate.open()
    await staleLoad.value

    XCTAssertEqual(sut.activities.map(\.id), ["interaction-from-B"])
    XCTAssertNil(sut.errorMessage)
  }

  func testLoadActivities_cancelledLoad_doesNotShowError() async {
    authenticateUser()
    mockService.shouldThrowOnInteractions = true
    let task = Task { await sut.loadActivities(forceRefresh: true) }
    task.cancel()
    await task.value

    XCTAssertNil(sut.errorMessage)
  }

  func testAddRealtimeEvent_fromInactiveFamily_isDropped() {
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "late"), schoolName: nil)

    sut.addRealtimeEvent(event, forFamily: "previous-family")

    XCTAssertTrue(sut.activities.isEmpty)
  }

  func testAddRealtimeEvent_fromActiveFamily_isAdded() {
    let event = ActivityEventFactory.fromInteraction(makeInteraction(id: "now"), schoolName: nil)

    sut.addRealtimeEvent(event, forFamily: "family-1")

    XCTAssertEqual(sut.activities.map(\.id), ["interaction-now"])
  }

  func testFamilyDidChange_resubscribesForNewFamilyAndReloads() async {
    authenticateUser()
    mockService.interactionsByFamily = [
      "family-1": [makeInteraction(id: "one")],
      "family-2": [makeInteraction(id: "two")]
    ]
    await sut.loadAndSubscribe()
    XCTAssertEqual(sut.activities.map(\.id), ["interaction-one"])

    familyManager.currentMember = Self.member(id: "m", userId: "test-user-id", familyUnitId: "family-2")
    await sut.familyDidChange()

    XCTAssertEqual(mockRealtime.events, ["subscribe:family-1", "unsubscribe", "subscribe:family-2"])
    XCTAssertEqual(mockService.lastFetchInteractionsFamilyUnitId, "family-2")
    XCTAssertEqual(sut.activities.map(\.id), ["interaction-two"])
  }

  func testLoadAndSubscribe_twice_subscribesOnce() async {
    authenticateUser()
    await sut.loadAndSubscribe()
    await sut.loadAndSubscribe()

    XCTAssertEqual(mockRealtime.subscribeCallCount, 1)
  }

  func testLoadActivities_familyBecomesNil_clearsEntries() async {
    authenticateUser()
    mockService.mockInteractions = [makeInteraction(id: "x")]
    await sut.loadActivities()
    XCTAssertFalse(sut.activities.isEmpty)

    familyManager.currentMember = nil
    await sut.loadActivities()

    XCTAssertTrue(sut.activities.isEmpty)
  }

  func testRefresh_bypassesTheCache() async {
    authenticateUser()
    await sut.loadActivities()
    await sut.loadActivities()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1, "second plain load is served from cache")

    await sut.refresh()

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
  }

  func testTearDownRealtime_cancelsPendingReloadAndUnsubscribes() async throws {
    authenticateUser()
    await sut.loadAndSubscribe()
    sut.scheduleDebouncedReload()

    await sut.tearDownRealtime()
    try await Task.sleep(for: .milliseconds(300))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockRealtime.events.last, "unsubscribe")
  }

  func testSchoolsChangeCallback_schedulesDebouncedReload() async throws {
    authenticateUser()
    await sut.loadAndSubscribe()

    mockRealtime.simulateSchoolsChange()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    try await Task.sleep(for: .milliseconds(400))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
  }

  func testInteractionChangeCallback_forcesImmediateReload() async throws {
    authenticateUser()
    await sut.loadAndSubscribe()

    mockRealtime.simulateChange()
    try await Task.sleep(for: .milliseconds(600))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
  }

  func testStatusHistoryInsert_triggersExactlyOneDebouncedForcedReload_andAppendsNothing() async throws {
    authenticateUser()
    mockService.mockInteractions = [makeInteraction(id: "loaded")]
    await sut.loadAndSubscribe()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    mockRealtime.simulateStatusHistoryInsert()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1, "debounced, not immediate")
    XCTAssertEqual(sut.activities.map(\.id), ["interaction-loaded"], "the payload is never appended")
    try await Task.sleep(for: .milliseconds(500))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
  }

  func testStatusHistoryInsert_afterFamilySwitch_isDropped() async throws {
    authenticateUser()
    await sut.loadAndSubscribe()
    let staleCallback = try XCTUnwrap(mockRealtime.lastOnStatusHistoryInsert)
    familyManager.currentMember = Self.member(id: "m", userId: "test-user-id", familyUnitId: "family-2")
    await sut.familyDidChange()
    let fetchesAfterSwitch = mockService.fetchInteractionsCallCount

    staleCallback()
    try await Task.sleep(for: .milliseconds(500))

    XCTAssertEqual(mockService.fetchInteractionsCallCount, fetchesAfterSwitch)
  }
}

/// Holds a suspended call open until the test opens it.
actor FetchGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var isOpen = false

  func wait() async {
    guard !isOpen else { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func waitUntilWaiting() async {
    while continuation == nil { try? await Task.sleep(for: .milliseconds(5)) }
  }

  func open() {
    isOpen = true
    continuation?.resume()
    continuation = nil
  }
}
