import XCTest
@testable import TheRecruitingCompass

@MainActor
final class GuardianStatusViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: GuardianStatusViewModel!
  var mockService: MockGuardianClaimService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockService = MockGuardianClaimService()
    mockAuthManager = MockAuthManager()
    sut = GuardianStatusViewModel(service: mockService, authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    super.tearDown()
  }

  private func pendingStatus() -> GuardianStatus {
    GuardianStatus(
      pending: true,
      guardianEmailMasked: "p*****@example.com",
      expiresAt: "2026-12-01T00:00:00Z",
      status: "pending"
    )
  }

  func testLocksWhileClaimIsPending() async {
    mockService.statusToReturn = pendingStatus()

    await sut.load()

    XCTAssertTrue(sut.isPending)
    XCTAssertTrue(sut.isLocked)
    XCTAssertEqual(sut.guardianEmailMasked, "p*****@example.com")
  }

  func testUnlocksOnceGuardianConfirms() async {
    mockService.statusToReturn = GuardianStatus(
      pending: false,
      guardianEmailMasked: "p*****@example.com",
      expiresAt: nil,
      status: "claimed"
    )

    await sut.load()

    XCTAssertFalse(sut.isLocked)
  }

  func testUserWithNoClaimIsNotLocked() async {
    // Adults, parents, and minors who joined via the older family-invite path.
    await sut.load()

    XCTAssertFalse(sut.isLocked)
  }

  func testFailsOpenWhenStatusLookupErrors() async {
    // A failed lookup must not lock an adult out of their own account; the server
    // endpoints and the DB gate stay authoritative regardless.
    mockService.statusError = GuardianClaimError.server(status: 500, message: nil)

    await sut.load()

    XCTAssertFalse(sut.isLocked)
    XCTAssertTrue(sut.hasLoaded)
  }

  func testDoesNotCallServiceWhenApiBaseUrlMissing() async {
    mockService.isConfigured = false
    mockService.statusToReturn = pendingStatus()

    await sut.load()

    XCTAssertFalse(sut.isLocked, "An unreachable API must not be treated as a pending claim")
  }

  func testResendForwardsNewGuardianEmail() async {
    mockService.statusToReturn = pendingStatus()
    await sut.load()

    let sent = await sut.resend(guardianEmail: "newparent@example.com")

    XCTAssertTrue(sent)
    XCTAssertEqual(mockService.resendCallCount, 1)
    XCTAssertEqual(mockService.capturedResendEmail, "newparent@example.com")
  }

  func testResendSurfacesServerMessage() async {
    mockService.resendError = GuardianClaimError.server(
      status: 429,
      message: "Too many requests"
    )

    let sent = await sut.resend()

    XCTAssertFalse(sent)
    XCTAssertEqual(sut.errorMessage, "Too many requests")
  }

  func testLoadIsCachedUntilForced() async {
    mockService.statusToReturn = pendingStatus()
    await sut.load()
    mockService.statusToReturn = GuardianStatus(
      pending: false,
      guardianEmailMasked: nil,
      expiresAt: nil,
      status: "claimed"
    )

    await sut.load()
    XCTAssertTrue(sut.isLocked, "A cached load should not re-fetch")

    await sut.load(force: true)
    XCTAssertFalse(sut.isLocked, "A forced load picks up the new state")
  }
}
