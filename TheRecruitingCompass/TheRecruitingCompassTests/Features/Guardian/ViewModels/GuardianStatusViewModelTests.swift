import XCTest
@testable import TheRecruitingCompass

@MainActor
final class GuardianStatusViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: GuardianStatusViewModel!
  var mockGuardianService: MockGuardianService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockGuardianService = MockGuardianService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockSession(Session(
      accessToken: "test-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh",
      user: User(id: "u1", email: "player@example.com", emailConfirmedAt: nil, phone: nil,
                 fullName: "Test Player", createdAt: "2026-01-01T00:00:00Z",
                 updatedAt: "2026-01-01T00:00:00Z", role: .player, dateOfBirth: nil)))
    sut = GuardianStatusViewModel(guardianService: mockGuardianService, authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockGuardianService = nil
    mockAuthManager = nil
    super.tearDown()
  }

  func testRefreshWithNoSessionDoesNotCallService() async {
    mockAuthManager.session = nil
    await sut.refresh()
    XCTAssertEqual(mockGuardianService.fetchStatusCallCount, 0)
  }

  func testRefreshPopulatesStatusAndIsPending() async {
    mockGuardianService.mockStatus = GuardianStatus(
      pending: true, guardianEmailMasked: "j***@example.com", expiresAt: "2026-12-31T00:00:00Z", status: "pending")

    await sut.refresh()

    XCTAssertEqual(mockGuardianService.fetchStatusCallCount, 1)
    XCTAssertTrue(sut.isPending)
    XCTAssertEqual(sut.status?.guardianEmailMasked, "j***@example.com")
  }

  func testRefreshNotPendingWhenClaimed() async {
    mockGuardianService.mockStatus = GuardianStatus(
      pending: false, guardianEmailMasked: nil, expiresAt: nil, status: "claimed")

    await sut.refresh()

    XCTAssertFalse(sut.isPending)
  }

  func testRefreshFailsOpenOnError() async {
    mockGuardianService.shouldThrowFetchStatusError = true

    await sut.refresh()

    XCTAssertNil(sut.status)
    XCTAssertFalse(sut.isPending, "A failed status check must never fabricate a lock")
  }

  func testResendCallsServiceAndSetsMessage() async {
    await sut.resend()
    XCTAssertEqual(mockGuardianService.resendCallCount, 1)
    XCTAssertEqual(sut.resendMessage, "Confirmation email resent.")
  }

  func testResendSurfacesServerError() async {
    mockGuardianService.shouldThrowResendError = true
    mockGuardianService.mockErrorToThrow = GuardianServiceError.server(410, message: "This confirmation request has expired. Please contact support.")

    await sut.resend()

    XCTAssertEqual(sut.resendMessage, "This confirmation request has expired. Please contact support.")
  }
}
