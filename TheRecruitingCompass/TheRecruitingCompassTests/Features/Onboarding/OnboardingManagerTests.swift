import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OnboardingManagerTests: XCTestCase {
  nonisolated deinit {}
  var sut: OnboardingManager!
  var mockOnboardingService: MockOnboardingService!
  var mockAuthManager: MockAuthManager!
  var mockPreferenceService: MockPreferenceService!

  override func setUp() {
    super.setUp()
    mockOnboardingService = MockOnboardingService()
    mockAuthManager = MockAuthManager()
    mockPreferenceService = MockPreferenceService()
    sut = OnboardingManager(
      onboardingService: mockOnboardingService,
      authManager: mockAuthManager,
      preferenceService: mockPreferenceService
    )
  }

  override func tearDown() {
    sut = nil
    mockOnboardingService = nil
    mockAuthManager = nil
    mockPreferenceService = nil
    super.tearDown()
  }

  // MARK: - Unauthenticated

  func testNoUserDefaultsToNotNeedingOnboarding() async {
    mockAuthManager.user = nil

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - Player Tests

  func testPlayerWithCompletedOnboardingSkipsDashboard() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerWithIncompleteOnboardingNeedsOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testPlayerWithDBErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerChecksTheOnboardingFlag() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(mockOnboardingService.isOnboardingCompleteCallCount, 1)
  }

  // MARK: - Sport Gate (needsSportOnly)

  func testPlayerWithNullSportNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: nil)

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertTrue(sut.needsSportOnly, "A complete player with a null sport must be gated")
  }

  func testPlayerWithBlankSportNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: "   ")

    await sut.loadStatus(isInFamily: false)

    XCTAssertTrue(sut.needsSportOnly, "Blank/whitespace sport counts as unset")
  }

  func testPlayerWithSportDoesNotNeedSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: "Baseball")

    await sut.loadStatus(isInFamily: false)

    XCTAssertFalse(sut.needsSportOnly, "A player with a real sport is not gated")
  }

  func testPlayerWithNoPrefsRowNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = nil

    await sut.loadStatus(isInFamily: false)

    XCTAssertTrue(sut.needsSportOnly, "No prefs row means no sport, so gate")
  }

  func testPlayerWithPrefsErrorFailsOpen() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.errorToThrow = NSError(domain: "test", code: 1)

    await sut.loadStatus(isInFamily: false)

    XCTAssertFalse(sut.needsSportOnly, "A read error must fail open, never lock the user out")
  }

  func testParentIsNeverSportGated() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: nil)

    await sut.loadStatus(isInFamily: false)

    XCTAssertFalse(sut.needsSportOnly, "Parents use a different flow and are never sport-gated")
  }

  // MARK: - Parent Tests (onboarding flag, independent of family membership)

  func testParentWithCompletedOnboardingSkipsIt() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testParentInAFamilyWithoutTheFlagPasses() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testParentWithNeitherFamilyNorFlagIsGated() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testParentWhoJoinsAFamilyAfterTheGateLeavesOnboardingOnReevaluation() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: false)
    XCTAssertEqual(sut.needsOnboarding, true)

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerRuleIgnoresFamilyMembership() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testGateTruthTable() {
    XCTAssertFalse(OnboardingGate.needsOnboarding(role: .parent, flagComplete: true, isInFamily: false))
    XCTAssertFalse(OnboardingGate.needsOnboarding(role: .parent, flagComplete: false, isInFamily: true))
    XCTAssertTrue(OnboardingGate.needsOnboarding(role: .parent, flagComplete: false, isInFamily: false))
    XCTAssertFalse(OnboardingGate.needsOnboarding(role: .player, flagComplete: true, isInFamily: false))
    XCTAssertTrue(OnboardingGate.needsOnboarding(role: .player, flagComplete: false, isInFamily: true))
  }

  func testParentWithFlagErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus(isInFamily: false)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - Helpers

  private func makeUser(role: UserRole) -> User {
    let id = role == .parent ? "test-parent-id" : "test-player-id"
    return User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: "Test User",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role,
      dateOfBirth: nil,
      profilePhotoUrl: nil
    )
  }

  private func makePlayerDetails(sport: String?) -> PlayerDetails {
    var details = PlayerDetails.default
    details.primarySport = sport
    return details
  }

  // MARK: - Reset (account switch)

  func testResetReturnsToLoadingSoTheNextUserNeverSeesThePreviousRoute() {
    sut.needsOnboarding = false
    sut.needsSportOnly = true

    sut.reset()

    XCTAssertNil(sut.needsOnboarding)
    XCTAssertFalse(sut.needsSportOnly)
  }

  func testStatusCheckStartedBeforeResetIsDiscarded() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = false
    let gate = AsyncGate()
    mockOnboardingService.isOnboardingCompleteGate = { await gate.wait() }

    let staleCheck = Task { await sut.loadStatus(isInFamily: false) }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered, "the gated call never started")
    sut.reset()
    gate.open()
    await staleCheck.value

    XCTAssertNil(sut.needsOnboarding)
  }

  // MARK: - Parent signup in this session goes through the parent wizard (ios#488)

  func testParentWhoSignedUpThisSession_isRoutedToTheWizardEvenInAFamily() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, true)
    XCTAssertEqual(sut.parentFirstRun, .wizard)
  }

  func testParentColdLaunchInAFamily_goesToTheDashboard() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = nil
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertNil(sut.parentFirstRun)
  }

  func testPlayerIsUnaffectedByTheParentSignupSignal() async {
    mockAuthManager.user = makeUser(role: .player)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertNil(sut.parentFirstRun)
  }

  func testFinishedParentIsNeverSentBackByTheSignal() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testReevaluationMidWizardDoesNotEjectTheParent() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    // The wizard writes the completion flag, then something (membership change, sport gate) re-checks.
    mockOnboardingService.isOnboardingCompleteResult = true
    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, true, "the school step after the wizard must not be cut short")
  }

  func testMarkCompleteClearsTheLatchAndLeavesTheWizard() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    sut.markComplete()
    mockOnboardingService.isOnboardingCompleteResult = true
    await sut.loadStatus(isInFamily: true)

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testResetClearsTheLatch() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    sut.reset()

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertNil(sut.needsOnboarding)
  }

  // MARK: - Invited parent goes to the school step only (ios#488, matches web join.vue)

  private func athleteMember() -> FamilyMember {
    FamilyMember(
      id: "m-a", userId: "athlete-7", familyUnitId: "family-1", role: "player",
      addedAt: nil, user: nil, canRemove: nil, removeBlockedReason: nil
    )
  }

  func testInvitedParentWithIncompleteOnboarding_getsTheSchoolStepOnly() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.parentFirstRun, .schoolStepOnly)
    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testInvitedParentWhoseAcceptCompletedOnboarding_goesStraightToTheDashboard() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus(isInFamily: true)

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testInvitedParentDestination_athleteInFamily_isTheSchoolStepForThatAthlete() {
    XCTAssertEqual(
      OnboardingGate.invitedParentDestination(for: .schoolStepOnly, members: [athleteMember()]),
      .schoolStep(athleteUserId: "athlete-7")
    )
  }

  func testInvitedParentDestination_noAthlete_isTheDashboard() {
    XCTAssertEqual(OnboardingGate.invitedParentDestination(for: .schoolStepOnly, members: []), .dashboard)
  }

  func testInvitedParentDestination_wizardRouteDecidesItsOwnExit() {
    XCTAssertNil(OnboardingGate.invitedParentDestination(for: .wizard, members: [athleteMember()]))
  }

  func testInvitedParentDestination_parentOnlyFamily_isTheDashboardNeverASchoolWrite() {
    let parentOnly = FamilyMember(
      id: "m-p", userId: "other-parent", familyUnitId: "family-1", role: "parent",
      addedAt: nil, user: nil, canRemove: nil, removeBlockedReason: nil
    )
    XCTAssertEqual(OnboardingGate.invitedParentDestination(for: .schoolStepOnly, members: [parentOnly]), .dashboard)
  }

  // MARK: - First-run ends once, and is not cut short by errors

  func testFirstRunDoesNotComeBackAfterItEnds_evenWhileTheServerFlagIsStillFalse() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    sut.markComplete()
    await sut.loadStatus(isInFamily: true)

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testResetAllowsTheNextSignupToStartFirstRunAgain() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)
    sut.markComplete()

    sut.reset()
    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.parentFirstRun, .wizard)
  }

  func testFinishingTheInvitedRoute_writesOnboardingComplete() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    await sut.finishParentFirstRun()

    XCTAssertEqual(mockOnboardingService.completeOnboardingCallCount, 1)
    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertNil(sut.parentFirstRun)
  }

  func testFinishingTheInvitedRoute_stillLeavesWhenTheWriteFails() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    mockOnboardingService.shouldThrowError = true
    await sut.finishParentFirstRun()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testFinishingTheWizardRoute_doesNotWriteTwice() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    await sut.finishParentFirstRun()

    XCTAssertEqual(mockOnboardingService.completeOnboardingCallCount, 0, "the wizard already wrote it")
  }

  func testAFailedStatusReadMidFirstRunKeepsTheParentInIt() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)

    mockOnboardingService.shouldThrowError = true
    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testAFailedStatusReadOutsideFirstRunStillFailsOpen() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testFinishingFirstRun_afterSignOutMidWrite_doesNotEndTheNextUsersOnboarding() async throws {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.isOnboardingCompleteResult = false
    await sut.loadStatus(isInFamily: true)
    let (entered, enteredSignal) = AsyncStream<Void>.makeStream()
    let (release, releaseSignal) = AsyncStream<Void>.makeStream()
    mockOnboardingService.completeOnboardingGate = {
      enteredSignal.yield()
      for await _ in release { break }
    }

    let finishing = Task { await self.sut.finishParentFirstRun() }
    for await _ in entered { break }
    sut.reset()
    mockAuthManager.user = makeUser(role: .player)
    mockAuthManager.parentSignupThisSession = nil
    await sut.loadStatus(isInFamily: true)
    releaseSignal.yield()
    let completed = await finishing.value

    XCTAssertFalse(completed, "the stopped finish reports it, so the view does not leave")
    XCTAssertEqual(sut.needsOnboarding, true, "the stale finish must not mark the new player complete")
  }

  func testNewParentWhoseFirstStatusReadFails_stillLandsInFirstRun() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus(isInFamily: true)

    XCTAssertEqual(sut.needsOnboarding, true)
    XCTAssertEqual(sut.parentFirstRun, .wizard)
  }

  func testInvitedParentWhoseStatusReadFails_failsOpenAndIsNeverRewritten() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .invited
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus(isInFamily: true)
    await sut.finishParentFirstRun()

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertEqual(mockOnboardingService.completeOnboardingCallCount, 0, "a finished account is not rewritten")
  }

  func testFinishedFirstRun_isNotRestartedByAnotherFailingStatusRead() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockAuthManager.parentSignupThisSession = .ordinary
    mockOnboardingService.shouldThrowError = true
    await sut.loadStatus(isInFamily: true)
    XCTAssertEqual(sut.parentFirstRun, .wizard)
    await sut.finishParentFirstRun()

    await sut.loadStatus(isInFamily: true)

    XCTAssertNil(sut.parentFirstRun)
    XCTAssertEqual(sut.needsOnboarding, false)
  }
}
