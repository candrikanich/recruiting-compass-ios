import XCTest
@testable import TheRecruitingCompass

/// ios#630: the next-steps card hides only before the first resolution for the athlete on screen; later reloads keep
/// what is showing, and a switch never shows one athlete's steps as the other's.
@MainActor
final class TimelineViewModelNextStepsCardRefreshTests: XCTestCase {
  nonisolated deinit {}

  private var api: MockTimelineAPIService!
  private var auth: MockAuthManager!
  private var family: FamilyManager!
  private var sut: TimelineViewModel!

  override func setUp() async throws {
    api = MockTimelineAPIService()
    auth = MockAuthManager()
    family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    sut = TimelineViewModel(
      tasksService: MockTasksService(),
      apiService: api,
      preferenceService: MockPreferenceManager(),
      authManager: auth,
      familyManager: family,
      dashboardService: MockDashboardService()
    )
  }

  override func tearDown() {
    sut = nil
    family = nil
    auth = nil
    api = nil
  }

  private func step(_ id: String) -> WhatMattersItem {
    WhatMattersItem(taskId: id, title: "Step \(id)", whyItMatters: "why", category: "c", priority: 1, isRequired: true)
  }

  /// Starts a summary load held at the phase request and returns once it is waiting there.
  private func loadHeldAtPhase(_ gate: AsyncGate) async -> Task<Void, Never> {
    api.fetchPhaseGate = { await gate.wait() }
    let load = Task { await sut.loadSummary() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered, "the load never reached the phase request")
    return load
  }

  func testCard_hiddenWhileTheFirstLoadIsStillPending() async {
    api.stubbedWhatMatters = [step("1")]
    let gate = AsyncGate()
    let load = await loadHeldAtPhase(gate)

    XCTAssertTrue(sut.isLoading)
    XCTAssertFalse(sut.shouldShowNextStepsCard)
    XCTAssertTrue(sut.nextSteps.isEmpty)

    gate.open()
    await load.value
    XCTAssertTrue(sut.shouldShowNextStepsCard)
  }

  func testCard_staysVisibleWithItsStepsWhileARefreshIsInFlight() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    XCTAssertTrue(sut.shouldShowNextStepsCard)

    let gate = AsyncGate()
    let reload = await loadHeldAtPhase(gate)

    XCTAssertTrue(sut.isLoading)
    XCTAssertTrue(sut.shouldShowNextStepsCard)
    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["1"])

    gate.open()
    await reload.value
  }

  func testCard_staysVisibleWhileARetryAfterAFailedFirstLoadIsInFlight() async {
    api.shouldThrowError = true
    await sut.loadSummary()
    XCTAssertTrue(sut.shouldShowNextStepsCard, "precondition: the failure card is showing")
    api.shouldThrowError = false
    api.stubbedWhatMatters = [step("1")]

    let gate = AsyncGate()
    let retry = await loadHeldAtPhase(gate)

    XCTAssertTrue(sut.isLoading)
    XCTAssertTrue(sut.shouldShowNextStepsCard)

    gate.open()
    await retry.value
    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["1"])
  }

  func testSwitchingAthlete_hidesThePreviousAthletesCardBeforeAnyNewLoadStarts() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    XCTAssertEqual(sut.nextSteps.count, 1)

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)

    XCTAssertFalse(sut.shouldShowNextStepsCard)
    XCTAssertTrue(sut.nextSteps.isEmpty)
    XCTAssertTrue(sut.summaryCard.nextSteps.isEmpty)
    XCTAssertNil(sut.summaryCard.phase)
  }

  func testSwitchingAthlete_keepsTheCardHiddenUntilTheNewAthleteResolves() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    api.stubbedWhatMatters = [step("2")]

    let gate = AsyncGate()
    let load = await loadHeldAtPhase(gate)

    XCTAssertFalse(sut.shouldShowNextStepsCard)
    XCTAssertTrue(sut.nextSteps.isEmpty)

    gate.open()
    await load.value
    XCTAssertTrue(sut.shouldShowNextStepsCard)
    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["2"])
  }

  func testSwitchingBackAndForth_neverShowsTheOtherAthletesSteps() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    api.stubbedWhatMatters = [step("2")]
    await sut.loadSummary()

    family.selectedAthleteId = family.familyMembers.first { $0.userId == ParentViewingAthleteFixture.athleteUserId }?.id

    XCTAssertTrue(sut.nextSteps.isEmpty)
    XCTAssertFalse(sut.shouldShowNextStepsCard)
  }
}
