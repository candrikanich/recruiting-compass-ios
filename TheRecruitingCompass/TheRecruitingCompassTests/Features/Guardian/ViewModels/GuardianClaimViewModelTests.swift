import XCTest
@testable import TheRecruitingCompass

@MainActor
final class GuardianClaimViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: GuardianClaimViewModel!
  var mockGuardianService: MockGuardianService!
  var mockAuthManager: MockAuthManager!
  var mockTurnstile: MockTurnstileTokenProvider!

  override func setUp() {
    super.setUp()
    mockGuardianService = MockGuardianService()
    mockAuthManager = MockAuthManager()
    mockTurnstile = MockTurnstileTokenProvider()
    sut = GuardianClaimViewModel(
      token: "test-token", guardianService: mockGuardianService,
      authManager: mockAuthManager, turnstileTokenProvider: mockTurnstile)
  }

  override func tearDown() {
    sut = nil
    mockGuardianService = nil
    mockAuthManager = nil
    mockTurnstile = nil
    super.tearDown()
  }

  func testLoadResolvesClaimAndPrefillsLoginEmail() async {
    mockGuardianService.mockClaimDetails = GuardianClaimDetails(
      guardianEmail: "guardian@example.com", playerName: "Alex Player",
      playerDateOfBirth: "2011-01-01", playerGraduationYear: 2029, expiresAt: "2026-12-31T00:00:00Z")

    await sut.load()

    XCTAssertEqual(mockGuardianService.resolveClaimCallCount, 1)
    XCTAssertEqual(mockGuardianService.capturedResolveClaimToken, "test-token")
    XCTAssertEqual(sut.claimDetails?.playerName, "Alex Player")
    XCTAssertEqual(sut.loginEmail, "guardian@example.com")
  }

  func testLoadSurfacesServerErrorAsState() async {
    mockGuardianService.shouldThrowResolveClaimError = true
    mockGuardianService.mockErrorToThrow = GuardianServiceError.server(410, message: "This link has expired")

    await sut.load()

    XCTAssertEqual(sut.state, .error("This link has expired"))
  }

  func testConfirmWhenAlreadyAuthenticatedSkipsLogin() async {
    mockAuthManager.isAuthenticated = true
    mockAuthManager.setMockSession(Session(
      accessToken: "existing-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh",
      user: User(id: "g1", email: "guardian@example.com", emailConfirmedAt: nil, phone: nil,
                 fullName: "Guardian", createdAt: "2026-01-01T00:00:00Z",
                 updatedAt: "2026-01-01T00:00:00Z", role: .parent, dateOfBirth: nil)))

    await sut.confirm()

    XCTAssertEqual(mockAuthManager.loginCallCount, 0)
    XCTAssertEqual(mockGuardianService.acceptClaimCallCount, 1)
    XCTAssertEqual(mockGuardianService.capturedAcceptClaimToken, "test-token")
    XCTAssertEqual(sut.state, .confirmed)
  }

  func testConfirmWhenNotAuthenticatedLogsInFirst() async {
    mockAuthManager.isAuthenticated = false
    sut.loginEmail = "guardian@example.com"
    sut.loginPassword = "Password123"

    await sut.confirm()

    XCTAssertEqual(mockAuthManager.loginCallCount, 1)
    XCTAssertEqual(mockGuardianService.acceptClaimCallCount, 1)
    XCTAssertEqual(sut.state, .confirmed)
  }

  func testConfirmSurfacesAcceptError() async {
    mockAuthManager.isAuthenticated = true
    mockAuthManager.setMockSession(Session(
      accessToken: "existing-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh",
      user: User(id: "g1", email: "guardian@example.com", emailConfirmedAt: nil, phone: nil,
                 fullName: "Guardian", createdAt: "2026-01-01T00:00:00Z",
                 updatedAt: "2026-01-01T00:00:00Z", role: .parent, dateOfBirth: nil)))
    mockGuardianService.shouldThrowAcceptClaimError = true
    mockGuardianService.mockErrorToThrow = GuardianServiceError.server(403, message: "This link was sent to a different email.")

    await sut.confirm()

    XCTAssertEqual(sut.errorMessage, "This link was sent to a different email.")
    XCTAssertNotEqual(sut.state, .confirmed)
  }
}
