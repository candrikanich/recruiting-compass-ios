import XCTest
@testable import TheRecruitingCompass

/// Follow-up to ios#491: the view-facing values (what Home's card and the Timeline pills render), the no-family
/// fail-closed path, the what-matters-now failure, and the first-run signals refresh.
@MainActor
final class TimelineViewModelFirstRunFollowUpTests: XCTestCase {
  nonisolated deinit {}

  private var api: MockTimelineAPIService!
  private var dashboard: MockDashboardService!
  private var auth: MockAuthManager!
  private var family: FamilyManager!
  private var sut: TimelineViewModel!

  override func setUp() async throws {
    api = MockTimelineAPIService()
    dashboard = MockDashboardService()
    auth = MockAuthManager()
    family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    sut = TimelineViewModel(
      tasksService: MockTasksService(),
      apiService: api,
      preferenceService: MockPreferenceManager(),
      authManager: auth,
      familyManager: family,
      dashboardService: dashboard
    )
  }

  override func tearDown() {
    sut = nil
    family = nil
    auth = nil
    dashboard = nil
    api = nil
  }

  private func step(_ id: String) -> WhatMattersItem {
    WhatMattersItem(taskId: id, title: "Step \(id)", whyItMatters: "why", category: "c", priority: 1, isRequired: true)
  }

  private func signals(coaches: Int, conversations: Int, favorite: String? = nil) -> FirstRunSignals {
    FirstRunSignals(coachCount: coaches, conversationCount: conversations, favoriteSchoolName: favorite)
  }

  // MARK: - Home card state

  func testSummaryCard_newAccount_hidesAtRiskScore_evenWhenServerSaysAtRisk() async {
    api.stubbedStatusScore = 8
    api.stubbedStatusLabel = .atRisk
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)

    await sut.loadSummary()

    XCTAssertNil(sut.summaryCard.status)
  }

  func testSummaryCard_showsScoreOnceCoachAndConversationExist() async {
    api.stubbedStatusScore = 42
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1, favorite: "State")

    await sut.loadSummary()

    XCTAssertEqual(sut.summaryCard.status?.score, 42)
    XCTAssertEqual(sut.summaryCard.favoriteSchoolName, "State")
  }

  func testSummaryCard_phaseUnresolved_hidesPhaseAndSaysStepsUnavailable() async {
    api.stubbedPhase = .sophomore
    api.shouldThrowError = true

    await sut.loadSummary()

    XCTAssertNil(sut.summaryCard.phase)
    XCTAssertTrue(sut.summaryCard.stepsUnavailable)
    XCTAssertTrue(sut.summaryCard.nextSteps.isEmpty)
  }

  func testSummaryCard_beforeAnyLoad_doesNotPassFreshmanDefaultOffAsThePhase() {
    XCTAssertNil(sut.summaryCard.phase)
  }

  func testSummaryCard_phaseResolved_showsThatPhaseAndSteps() async {
    api.stubbedPhase = .junior
    api.stubbedWhatMatters = [step("1")]

    await sut.loadSummary()

    XCTAssertEqual(sut.summaryCard.phase, .junior)
    XCTAssertFalse(sut.summaryCard.stepsUnavailable)
    XCTAssertEqual(sut.summaryCard.nextSteps.map(\.taskId), ["1"])
  }

  // MARK: - Timeline screen stat pills

  func testStatPillsStatus_newAccount_isNil_evenWhenServerSaysAtRisk() async {
    api.stubbedStatusScore = 8
    api.stubbedStatusLabel = .atRisk
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)

    await sut.loadSummary()

    XCTAssertNil(sut.statPillsStatus)
  }

  func testStatPillsStatus_withCoachAndConversation_carriesScoreAndLabel() async {
    api.stubbedStatusScore = 64
    api.stubbedStatusLabel = .onTrack
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)

    await sut.loadSummary()

    XCTAssertEqual(sut.statPillsStatus, .init(score: 64, label: .onTrack))
  }

  // MARK: - No family

  func testScore_whenTheFamilyDisappearsForTheSameAthlete_hidesAgain() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 2, conversations: 2, favorite: "State")
    await sut.loadSummary()
    XCTAssertNotNil(sut.visibleStatus)
    XCTAssertEqual(sut.favoriteSchoolName, "State")

    family.currentMember = nil
    family.familyUnit = nil
    await sut.loadSummary()

    XCTAssertNil(family.familyUnitId)
    XCTAssertEqual(sut.currentAthleteId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertNil(sut.visibleStatus)
    XCTAssertNil(sut.favoriteSchoolName)
  }

  // MARK: - What-matters-now failure

  func testStepsFailure_saysUnavailable_notNoPendingPriorities() async {
    api.stubbedWhatMatters = [step("1")]
    api.shouldThrowWhatMatters = true

    await sut.loadSummary()

    XCTAssertTrue(sut.isPhaseResolved)
    XCTAssertTrue(sut.summaryCard.nextSteps.isEmpty)
    XCTAssertTrue(sut.summaryCard.stepsUnavailable)
    XCTAssertTrue(sut.shouldShowNextStepsCard)
  }

  func testStepsRecovery_clearsTheFailure() async {
    api.shouldThrowWhatMatters = true
    await sut.loadSummary()
    XCTAssertTrue(sut.summaryCard.stepsUnavailable)

    api.shouldThrowWhatMatters = false
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()

    XCTAssertFalse(sut.summaryCard.stepsUnavailable)
    XCTAssertEqual(sut.summaryCard.nextSteps.count, 1)
  }

  func testNoStepsAtAll_isNotAFailure() async {
    api.stubbedWhatMatters = []

    await sut.loadSummary()

    XCTAssertFalse(sut.summaryCard.stepsUnavailable)
  }

  // MARK: - Signals refresh

  func testRefreshFirstRunSignals_picksUpANewCoachAndConversation() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)
    await sut.loadSummary()
    XCTAssertNil(sut.visibleStatus)

    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1, favorite: "State")
    await sut.refreshFirstRunSignals()

    XCTAssertNotNil(sut.visibleStatus)
    XCTAssertEqual(sut.favoriteSchoolName, "State")
  }

  func testRefreshFirstRunSignals_doesNotReloadThePhaseOrSteps() async {
    await sut.loadSummary()
    let phaseCalls = api.phaseCallCount

    await sut.refreshFirstRunSignals()

    XCTAssertEqual(api.phaseCallCount, phaseCalls)
    XCTAssertTrue(sut.isPhaseResolved)
  }

  func testRefreshFirstRunSignals_failureFailsClosed() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)
    await sut.loadSummary()
    XCTAssertNotNil(sut.visibleStatus)

    dashboard.shouldThrowFetchFirstRunSignals = true
    await sut.refreshFirstRunSignals()

    XCTAssertNil(sut.visibleStatus)
  }

  func testInitialLoadFailure_stillFailsClosed() async {
    api.stubbedStatusScore = 8
    api.stubbedStatusLabel = .atRisk
    dashboard.shouldThrowFetchFirstRunSignals = true

    await sut.loadSummary()

    XCTAssertNil(sut.visibleStatus)
    XCTAssertNil(sut.summaryCard.status)
    XCTAssertNil(sut.statPillsStatus)
  }

  func testRefreshAfterAFailedInitialLoad_recovers() async {
    dashboard.shouldThrowFetchFirstRunSignals = true
    await sut.loadSummary()

    dashboard.shouldThrowFetchFirstRunSignals = false
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)
    await sut.refreshFirstRunSignals()

    XCTAssertNotNil(sut.visibleStatus)
  }

  func testRefreshBeforeAnyLoad_sendsNoRequest() async {
    await sut.refreshFirstRunSignals()

    XCTAssertTrue(dashboard.requestedFirstRunSignalFamilyUnitIds.isEmpty)
  }

  func testRefreshAfterSwitchingAthlete_beforeTheirLoad_doesNotKeepTheOthersSignals() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 2, conversations: 2, favorite: "A School")
    await sut.loadSummary()
    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    dashboard.shouldThrowFetchFirstRunSignals = true

    await sut.refreshFirstRunSignals()
    await sut.loadSummary()

    XCTAssertNil(sut.visibleStatus)
    XCTAssertNil(sut.favoriteSchoolName)
  }

  // MARK: - Refresh while a load is in flight (a write landed after the load's counts request was sent)

  func testRefreshDuringInFlightLoad_isNotDropped_andItsNewerAnswerWins() async {
    let gate = AsyncGate(blockedEntries: 1)
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)
    let load = Task { await sut.loadSummary() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    XCTAssertTrue(sut.isLoading)

    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1, favorite: "State")
    await sut.refreshFirstRunSignals()
    gate.open()
    await load.value

    XCTAssertEqual(dashboard.requestedFirstRunSignalFamilyUnitIds.count, 2)
    XCTAssertNotNil(sut.visibleStatus)
    XCTAssertEqual(sut.favoriteSchoolName, "State")
  }

  func testOlderSignalsResponseLandingLate_doesNotOverwriteANewerOne() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)
    await sut.loadSummary()
    let gate = AsyncGate(blockedEntries: 1)
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }

    let older = Task { await sut.refreshFirstRunSignals() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)
    await sut.refreshFirstRunSignals()
    XCTAssertNotNil(sut.visibleStatus)
    gate.open()
    await older.value

    XCTAssertNotNil(sut.visibleStatus)
  }

  func testOlderSignalsFailureLandingLate_doesNotDisturbANewerAnswer() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)
    await sut.loadSummary()
    let gate = AsyncGate(blockedEntries: 1)
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    dashboard.shouldThrowFetchFirstRunSignals = true

    let older = Task { await sut.refreshFirstRunSignals() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    dashboard.shouldThrowFetchFirstRunSignals = false
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)
    await sut.refreshFirstRunSignals()
    gate.open()
    await older.value

    XCTAssertNotNil(sut.visibleStatus)
  }

  // MARK: - Returning to the screen

  func testRefreshIfIdle_whileALoadIsInFlight_sendsNoSecondRequest() async {
    let gate = AsyncGate()
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    let load = Task { await sut.loadSummary() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)

    await sut.refreshFirstRunSignalsIfIdle()
    gate.open()
    await load.value

    XCTAssertEqual(dashboard.requestedFirstRunSignalFamilyUnitIds.count, 1)
  }

  /// A coalesced load is still registered while `isLoading` is false: before its body starts (`.task(id:)` on
  /// re-appear registers it, then the appear Task runs) and after its body ends, until its caller resumes. The
  /// first gap can't be held from a test on iOS 18 (no `Task.immediate`), so this holds the second: a joiner wakes
  /// before the load's own caller has cleared it. The appear trigger must still see the load there.
  func testRefreshIfIdle_whileACoalescedLoadIsRegisteredButNotLoading_sendsNoSecondRequest() async {
    await sut.loadSummary()
    let gate = AsyncGate()
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    var reloadReturned = false
    let reload = Task {
      await sut.loadSummary()
      reloadReturned = true
    }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    let opener = Task { gate.open() }

    await sut.loadSummary()
    XCTAssertFalse(sut.isLoading, "precondition: the reload's body has finished")
    XCTAssertFalse(reloadReturned, "precondition: the reload's caller has not cleared it yet")
    XCTAssertEqual(dashboard.requestedFirstRunSignalFamilyUnitIds.count, 2, "precondition: one per load")

    await sut.refreshFirstRunSignalsIfIdle()
    await opener.value
    await reload.value

    XCTAssertEqual(dashboard.requestedFirstRunSignalFamilyUnitIds.count, 2)
  }

  func testRefreshIfIdle_afterTheLoad_refreshes() async {
    dashboard.stubbedFirstRunSignals = signals(coaches: 0, conversations: 0)
    await sut.loadSummary()
    dashboard.stubbedFirstRunSignals = signals(coaches: 1, conversations: 1)

    await sut.refreshFirstRunSignalsIfIdle()

    XCTAssertNotNil(sut.visibleStatus)
  }

  // MARK: - The steps card

  func testStepsCard_showsWhileTheCountsRequestIsStillPending() async {
    let gate = AsyncGate()
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    api.stubbedWhatMatters = [step("1")]
    let load = Task { await sut.loadSummary() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    for _ in 0..<50 where !sut.shouldShowNextStepsCard { await Task.yield() }

    XCTAssertTrue(sut.shouldShowNextStepsCard)
    XCTAssertEqual(sut.summaryCard.nextSteps.count, 1)
    XCTAssertNil(sut.summaryCard.status)

    gate.open()
    await load.value
  }

  func testStepsDoNotWaitForTheSignalsRequest() async {
    let gate = AsyncGate()
    dashboard.fetchFirstRunSignalsGate = { await gate.wait() }
    api.stubbedWhatMatters = [step("1")]

    let load = Task { await sut.loadSummary() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    for _ in 0..<50 where !sut.isPhaseResolved { await Task.yield() }

    XCTAssertTrue(sut.isPhaseResolved)
    XCTAssertEqual(sut.nextSteps.count, 1)
    XCTAssertNil(sut.visibleStatus)

    gate.open()
    await load.value
  }
}
