import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OnboardingManagerTests: XCTestCase {
  nonisolated deinit {}
  var sut: OnboardingManager!
  var mockOnboardingService: MockOnboardingService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!
  var mockPreferenceService: MockPreferenceService!

  private static let parentKey = "parent_onboarding_complete_test-parent-id"

  override func setUp() {
    super.setUp()
    mockOnboardingService = MockOnboardingService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    mockPreferenceService = MockPreferenceService()
    sut = OnboardingManager(
      onboardingService: mockOnboardingService,
      authManager: mockAuthManager,
      familyService: mockFamilyService,
      preferenceService: mockPreferenceService
    )
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
    sut = nil
    mockOnboardingService = nil
    mockAuthManager = nil
    mockFamilyService = nil
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

  func testPlayerChecksOnboardingServiceNotFamilyService() async {
    mockAuthManager.user = makeUser(role: .player)
    mockOnboardingService.isOnboardingCompleteResult = true

    await sut.loadStatus()

    XCTAssertEqual(mockOnboardingService.isOnboardingCompleteCallCount, 1)
    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 0,
      "Players should not trigger a family DB lookup")
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
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockPreferenceService.stubbedPlayerDetails = makePlayerDetails(sport: nil)

    await sut.loadStatus()

    XCTAssertFalse(sut.needsSportOnly, "Parents use a different flow and are never sport-gated")
  }

  // MARK: - Parent Tests (DB check)

  func testParentWithExistingFamilyInDBSkipsOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  func testParentWithExistingFamilyInDBCachesUserDefaultsFlag() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()

    await sut.loadStatus()

    let cached = UserDefaults.standard.bool(forKey: Self.parentKey)
    XCTAssertTrue(cached, "Should cache the result so future launches skip the DB call")
  }

  func testParentWithNoFamilyInDBNeedsOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.stubbedFamilyUnit = nil

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, true)
  }

  func testParentWithLocalCacheSkipsDBLookup() async {
    mockAuthManager.user = makeUser(role: .parent)
    UserDefaults.standard.set(true, forKey: Self.parentKey)

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 0,
      "Should use UserDefaults fast-path and skip DB call")
  }

  func testParentWithFamilyDBErrorDefaultsToSkippingOnboarding() async {
    mockAuthManager.user = makeUser(role: .parent)
    mockFamilyService.shouldSucceed = false

    await sut.loadStatus()

    XCTAssertEqual(sut.needsOnboarding, false)
  }

  // MARK: - markParentOnboardingComplete

  func testMarkParentOnboardingCompleteSetsFlagAndNeedsOnboardingFalse() {
    mockAuthManager.user = makeUser(role: .parent)

    sut.markParentOnboardingComplete()

    XCTAssertEqual(sut.needsOnboarding, false)
    let cached = UserDefaults.standard.bool(forKey: Self.parentKey)
    XCTAssertTrue(cached)
  }

  // MARK: - Helpers

  private func makeUser(role: UserRole) -> User {
    let id = role == .parent ? "test-parent-id" : "test-player-id"
    return User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
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

  private func makeFamilyUnit() -> FamilyUnit {
    FamilyUnit(
      id: "family-unit-1",
      createdByUserId: "test-parent-id",
      familyName: "Test Family",
      familyCode: "FAM-ABC123",
      codeGeneratedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil,
      pendingPlayerDetails: nil
    )
  }
}
