import XCTest
@testable import TheRecruitingCompass

/// `settledProfileCompleteness` must stay nil until every completeness input loaded successfully,
/// so the NUX "profile complete" timestamp is never cleared by a half-loaded or cancelled fetch.
@MainActor
final class DashboardViewModelProfileCompletenessTests: XCTestCase {
  nonisolated deinit {}
  private var sut: DashboardViewModel!
  private var mockAuthManager: MockAuthManager!
  private var mockPreferenceService: MockPreferenceService!
  private var mockVideoLinksService: MockVideoLinksService!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    mockPreferenceService = MockPreferenceService()
    mockVideoLinksService = MockVideoLinksService()
    mockAuthManager.setMockUser(User(
      id: "athlete-1",
      email: "athlete@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil,
      dateOfBirth: nil
    ))
    sut = DashboardViewModel(
      authManager: mockAuthManager,
      dashboardService: MockDashboardService(),
      taskStorage: MockQuickTaskStorage(),
      familyManager: FamilyManager(familyService: MockFamilyService(), authManager: mockAuthManager),
      preferenceService: mockPreferenceService,
      videoLinksService: mockVideoLinksService
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    mockPreferenceService = nil
    mockVideoLinksService = nil
    super.tearDown()
  }

  func testNilBeforeProfileLoads() {
    XCTAssertNil(sut.settledProfileCompleteness)
  }

  func testMatchesProfileCompletenessOnceEveryInputLoads() async {
    mockPreferenceService.stubbedPlayerDetails = PlayerDetails(graduationYear: 2028)

    await sut.fetchPlayerProfile()

    XCTAssertEqual(sut.settledProfileCompleteness, sut.profileCompleteness)
  }

  func testNilWhenPlayerDetailsFetchFails() async {
    mockPreferenceService.errorToThrow = CancellationError()

    await sut.fetchPlayerProfile()

    XCTAssertNil(sut.settledProfileCompleteness)
  }

  func testNilWhenVideoLinksFetchFails() async {
    mockPreferenceService.stubbedPlayerDetails = PlayerDetails(graduationYear: 2028)
    mockVideoLinksService.fetchError = CancellationError()

    await sut.fetchPlayerProfile()

    XCTAssertNil(sut.settledProfileCompleteness)
  }

  func testFailedRefetchUnsettlesPreviouslySettledValue() async {
    mockPreferenceService.stubbedPlayerDetails = PlayerDetails(graduationYear: 2028)
    await sut.fetchPlayerProfile()
    XCTAssertNotNil(sut.settledProfileCompleteness)

    mockVideoLinksService.fetchError = CancellationError()
    await sut.fetchPlayerProfile()

    XCTAssertNil(sut.settledProfileCompleteness)
  }
}
