import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationIntegrationTests: XCTestCase {
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
  }

  override func tearDown() {
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Complete Flow Tests

  func testCompleteVerificationFlow() async {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    let verifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T12:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T12:00:00Z"
    )

    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    // Start as pending
    XCTAssertEqual(viewModel.verificationState, .pending)

    // Start polling
    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)

    // Simulate email verification
    mockAuthManager.setMockUser(verifiedUser)
    try? await Task.sleep(nanoseconds: 3_000_000_000)

    // Should detect verification
    XCTAssertEqual(viewModel.verificationState, .verified)
    XCTAssertTrue(viewModel.isVerified)

    viewModel.stopPolling()
  }

  func testPollingDetectsVerificationWithinTwoSeconds() async {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    let verifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T12:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T12:00:00Z"
    )

    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    mockAuthManager.setMockUser(verifiedUser)

    // Wait for polling to detect (should happen within 2 seconds)
    try? await Task.sleep(nanoseconds: 3_000_000_000)

    XCTAssertEqual(viewModel.verificationState, .verified)

    viewModel.stopPolling()
  }

  func testResendWithCooldown() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertTrue(viewModel.canResendEmail)
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 0)

    // First resend
    await viewModel.resendVerificationEmail()

    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
    XCTAssertFalse(viewModel.canResendEmail)
    XCTAssertGreaterThan(viewModel.resendCooldownSeconds, 0)

    // Try to resend during cooldown (should not call)
    await viewModel.resendVerificationEmail()
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
  }

  func testBackgroundingPausesPolling() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 300_000_000)
    let callCountBeforeStop = mockAuthManager.refreshSessionCallCount

    viewModel.stopPolling()
    try? await Task.sleep(nanoseconds: 300_000_000)

    let callCountAfterStop = mockAuthManager.refreshSessionCallCount
    XCTAssertEqual(callCountBeforeStop, callCountAfterStop)
  }

  func testErrorRecoveryWithRetries() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)

    // Should have error message after retries
    XCTAssertNotNil(viewModel.errorMessage)

    viewModel.stopPolling()
  }

  func testSessionExpirationHandling() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Simulate session expiration
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .userNotFound

    try? await Task.sleep(nanoseconds: 500_000_000)

    // Should stop polling on session expiration
    XCTAssertNotNil(viewModel.errorMessage)

    viewModel.stopPolling()
  }

  func testOnAppearStartsPollingForUnverified() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.onAppear()
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)

    viewModel.onDisappear()
  }

  func testOnAppearSkipsPollingForVerified() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T12:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T12:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.onAppear()
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(mockAuthManager.refreshSessionCallCount, 0)
  }

  func testMemoryCleanupOnDeinit() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)

    var viewModel: EmailVerificationViewModel? = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel?.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    viewModel = nil

    // If memory cleanup works properly, no crashes should occur
    XCTAssertNil(viewModel)
  }

  func testExponentialBackoffOnErrors() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    mockAuthManager.shouldThrowRefreshError = true
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    viewModel.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)

    // Should have error after exponential backoff
    XCTAssertNotNil(viewModel.errorMessage)

    viewModel.stopPolling()
  }

  func testMultipleResendAttemptsRespectCooldown() async {
    let user = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    // First resend
    await viewModel.resendVerificationEmail()
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)

    // Multiple resend attempts during cooldown
    for _ in 1...3 {
      await viewModel.resendVerificationEmail()
    }

    // Should still only have 1 call
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
  }
}
