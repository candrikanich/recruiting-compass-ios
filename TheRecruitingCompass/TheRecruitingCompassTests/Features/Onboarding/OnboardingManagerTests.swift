import XCTest
@testable import TheRecruitingCompass

@MainActor
final class OnboardingManagerTests: XCTestCase {
  var sut: OnboardingManager!
  var mockOnboardingService: MockOnboardingService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyService: MockFamilyService!

  private static let parentKey = "parent_onboarding_complete_test-parent-id"

  override func setUp() {
    super.setUp()
    mockOnboardingService = MockOnboardingService()
    mockAuthManager = MockAuthManager()
    mockFamilyService = MockFamilyService()
    sut = OnboardingManager(
      onboardingService: mockOnboardingService,
      authManager: mockAuthManager,
      familyService: mockFamilyService
    )
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: Self.parentKey)
    sut = nil
    mockOnboardingService = nil
    mockAuthManager = nil
    mockFamilyService = nil
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
    User(
      id: "test-parent-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      fullName: "Test Parent",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role,
      dateOfBirth: nil,
      profilePhotoUrl: nil
    )
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
