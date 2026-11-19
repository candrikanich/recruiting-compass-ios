import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TimelineViewModelFirstRunTests: XCTestCase {
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

  // MARK: - Next steps

  func testNextSteps_showsAtMostThree() async {
    api.stubbedWhatMatters = ["1", "2", "3", "4", "5"].map(step)

    await sut.loadSummary()

    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["1", "2", "3"])
  }

  func testNextSteps_emptyUntilPhaseResolved() {
    XCTAssertFalse(sut.isPhaseResolved)
    XCTAssertTrue(sut.nextSteps.isEmpty)
  }

  func testFailedPhaseFetch_doesNotShowSteps_andShowsUnavailableCard() async {
    api.stubbedWhatMatters = [step("1")]
    api.stubbedPhase = .freshman
    api.shouldThrowError = true

    await sut.loadSummary()

    XCTAssertFalse(sut.isPhaseResolved)
    XCTAssertTrue(sut.nextSteps.isEmpty)
    XCTAssertTrue(sut.shouldShowNextStepsCard)
  }

  func testFailedRefresh_afterSuccess_dropsThePreviousSteps() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    XCTAssertEqual(sut.nextSteps.count, 1)

    api.shouldThrowError = true
    await sut.loadSummary()

    XCTAssertTrue(sut.nextSteps.isEmpty)
    XCTAssertFalse(sut.isPhaseResolved)
  }

  func testSwitchingAthlete_dropsTheOtherAthletesStepsBeforeTheNewOnesLoad() async {
    api.stubbedWhatMatters = [step("1")]
    api.stubbedStatusScore = 80
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 2, conversationCount: 2, favoriteSchoolName: "A")
    await sut.loadSummary()
    XCTAssertEqual(sut.nextSteps.count, 1)

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    api.shouldThrowError = true
    dashboard.shouldThrowFetchFirstRunSignals = true
    await sut.loadSummary()

    XCTAssertTrue(sut.nextSteps.isEmpty)
    XCTAssertNil(sut.statusScore)
    XCTAssertNil(sut.favoriteSchoolName)
  }

  func testCard_hiddenWhileLoading_andBeforeAnyLoad() {
    XCTAssertFalse(sut.shouldShowNextStepsCard)
  }

  // MARK: - Favorite school

  func testFavoriteSchool_comesFromFamilyScopedSignals() async {
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: "State")

    await sut.loadSummary()

    XCTAssertEqual(sut.favoriteSchoolName, "State")
    XCTAssertEqual(dashboard.requestedFirstRunSignalFamilyUnitIds, [ParentViewingAthleteFixture.familyUnitId])
  }

  func testNoFavorite_leavesStepsAlone() async {
    api.stubbedWhatMatters = [step("1")]
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: nil)

    await sut.loadSummary()

    XCTAssertNil(sut.favoriteSchoolName)
    XCTAssertEqual(sut.nextSteps.count, 1)
  }

  // MARK: - Status score visibility

  func testScore_hiddenForNewAccount_evenWhenServerSaysAtRisk() async {
    api.stubbedStatusScore = 8
    api.stubbedStatusLabel = .atRisk
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: nil)

    await sut.loadSummary()

    XCTAssertNotNil(sut.statusScore)
    XCTAssertNil(sut.visibleStatus)
    XCTAssertFalse(sut.isStatusScoreVisible)
  }

  func testScore_hiddenWithCoachButNoConversation() async {
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 1, conversationCount: 0, favoriteSchoolName: nil)
    await sut.loadSummary()
    XCTAssertNil(sut.visibleStatus)
  }

  func testScore_hiddenWithConversationButNoCoach() async {
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 1, favoriteSchoolName: nil)
    await sut.loadSummary()
    XCTAssertNil(sut.visibleStatus)
  }

  func testScore_shownWithCoachAndConversation() async {
    api.stubbedStatusScore = 42
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 1, conversationCount: 1, favoriteSchoolName: nil)

    await sut.loadSummary()

    XCTAssertEqual(sut.visibleStatus?.score, 42)
  }

  func testScore_failsClosedWhenSignalsCannotBeRead() async {
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 5, conversationCount: 5, favoriteSchoolName: nil)
    dashboard.shouldThrowFetchFirstRunSignals = true

    await sut.loadSummary()

    XCTAssertTrue(sut.isPhaseResolved)
    XCTAssertNil(sut.visibleStatus)
  }

  func testScore_withoutFamily_staysHidden() async {
    let solo = MockAuthManager()
    solo.setMockUser(User(
      id: "solo", email: "a@example.com", emailConfirmedAt: nil, createdAt: "", updatedAt: "", role: .player))
    let soloSut = TimelineViewModel(
      tasksService: MockTasksService(),
      apiService: api,
      preferenceService: MockPreferenceManager(),
      authManager: solo,
      familyManager: FamilyManager(familyService: MockFamilyService(), authManager: solo),
      dashboardService: dashboard
    )
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 5, conversationCount: 5, favoriteSchoolName: nil)

    await soloSut.loadSummary()

    XCTAssertNil(soloSut.visibleStatus)
    XCTAssertTrue(dashboard.requestedFirstRunSignalFamilyUnitIds.isEmpty)
  }
}
