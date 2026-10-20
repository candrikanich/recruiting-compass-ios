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

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - Player Tests

  func testPlayerWithCompletedOnboardingSkipsDashboard() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerWithIncompleteOnboardingNeedsOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testPlayerWithDBErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testPlayerChecksTheOnboardingFlag() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(mockOnboardingService.isOnboardingCompleteCallCount, 1)
  }

  // MARK: - Sport Gate (needsSportOnly)

  func testPlayerWithNullSportNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: nil)

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertTrue(sut.needsSportOnly, "A complete player with a null sport must be gated")
  }

  func testPlayerWithBlankSportNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: "   ")

    await sut.loadStatus()

    XCTAssertTrue(sut.needsSportOnly, "Blank/whitespace sport counts as unset")
  }

  func testPlayerWithSportDoesNotNeedSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: "Baseball")

    await sut.loadStatus()

    XCTAssertFalse(sut.needsSportOnly, "A player with a real sport is not gated")
  }

  func testPlayerWithNoPrefsRowNeedsSportOnly() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.stubbedPlayerDetails = nil

    await sut.loadStatus()

    XCTAssertTrue(sut.needsSportOnly, "No prefs row means no sport, so gate")
  }

  func testPlayerWithPrefsErrorFailsOpen() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true
    mockPreferenceService.errorToThrow = NSError(domain: "test", code: 1)

    await sut.loadStatus()

    XCTAssertFalse(sut.needsSportOnly, "A read error must fail open, never lock the user out")
  }

  func testParentIsNeverSportGated() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: nil)

    await sut.loadStatus()

    XCTAssertFalse(sut.needsSportOnly, "Parents use a different flow and are never sport-gated")
  }

  // MARK: - Parent Tests (onboarding flag, independent of family membership)

  func testParentWithCompletedOnboardingSkipsIt() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testParentWithIncompleteOnboardingNeedsIt_evenThoughTheServerGaveThemAFamily() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testParentOnboardingIgnoresAnyDeviceCachedFlag() async {
    mockAuthManager.user = makeUser(role: .parent)
    UserDefaults.standard.set(true, forKey: "parent_onboarding_complete_test-parent-id")
    defer { UserDefaults.standard.removeObject(forKey: "parent_onboarding_complete_test-parent-id") }
    mockOnboardingService.isOnboardingCompleteResult = false

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testParentWithFlagErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockOnboardingService.shouldThrowError = true

    await sut.loadStatus()

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

    let staleCheck = Task { await sut.loadStatus() }
    await gate.untilEntered()
    sut.reset()
    gate.open()
    await staleCheck.value

    XCTAssertNil(sut.needsOnboarding)
  }
}
