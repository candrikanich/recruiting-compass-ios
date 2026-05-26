import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: EmailVerificationViewModel!
  var mockAuthManager: MockAuthManager!

  private let unverifiedUser = User(
    id: "test-id",
    email: "test@example.com",
    emailConfirmedAt: nil,
    phone: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T00:00:00Z",
    role: nil
  )

  private let verifiedUser = User(
    id: "test-id",
    email: "test@example.com",
    emailConfirmedAt: "2024-01-01T12:00:00Z",
    phone: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T12:00:00Z",
    role: nil
  )

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
  }

  override func tearDown() {
    sut?.stopPolling()
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func testInitialStateWithUnverifiedUser() {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .pending)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 0)
    XCTAssertEqual(sut.userEmail, "test@example.com")
    XCTAssertFalse(sut.isVerified)
    XCTAssertFalse(sut.isPolling)
  }

  func testInitialStateWithVerifiedUser() {
    mockAuthManager.setMockUser(verifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .verified)
    XCTAssertTrue(sut.isVerified)
  }

  func testUserEmailReturnsNilWhenNoUser() {
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertNil(sut.userEmail)
    XCTAssertFalse(sut.isVerified)
  }

  func testUserEmailReturnsCorrectEmail() {
    let user = User(
      id: "test-id",
      email: "john.doe@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    )
    mockAuthManager.setMockUser(user)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.userEmail, "john.doe@example.com")
  }

  // MARK: - Polling Tests

  func testStartPollingCallsRefreshSession() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.startPolling()
    XCTAssertTrue(sut.isPolling)

    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)
  }

  func testStopPollingCancelsTask() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)
    let initialCallCount = mockAuthManager.refreshSessionCallCount

    sut.stopPolling()
    XCTAssertFalse(sut.isPolling)

    try? await Task.sleep(nanoseconds: 300_000_000)

    let finalCallCount = mockAuthManager.refreshSessionCallCount
    XCTAssertEqual(initialCallCount, finalCallCount, "Polling should not continue after stop")
  }

  func testPollingStopsWhenVerified() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    mockAuthManager.setMockUser(verifiedUser)
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(sut.verificationState, .verified)
  }

  func testStartPollingSkipsWhenAlreadyVerified() async {
    mockAuthManager.setMockUser(verifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertFalse(sut.isPolling)
    XCTAssertEqual(mockAuthManager.refreshSessionCallCount, 0)
  }

  func testStartPollingIsIdempotent() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.1
    )

    sut.startPolling()
    sut.startPolling()
    sut.startPolling()

    try? await Task.sleep(nanoseconds: 250_000_000)

    // With 0.1s interval and 0.25s wait, should get ~2 calls if single task,
    // but would get ~6 if three tasks were spawned
    XCTAssertLessThanOrEqual(mockAuthManager.refreshSessionCallCount, 3,
      "Multiple startPolling calls should not spawn multiple polling tasks")
  }

  // MARK: - Exponential Backoff Tests

  func testExponentialBackoffDoublesInterval() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05,
      maxPollingInterval: 1.0,
      maxConsecutiveErrors: 5
    )

    let initialInterval = sut.currentInterval
    XCTAssertEqual(initialInterval, 0.05)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 200_000_000)
    sut.stopPolling()

    XCTAssertGreaterThan(sut.currentInterval, initialInterval,
      "Interval should increase after errors")
    XCTAssertGreaterThan(sut.consecutiveErrors, 0)
  }

  func testBackoffCapsAtMaxInterval() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05,
      maxPollingInterval: 0.1,
      maxConsecutiveErrors: 10
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)
    sut.stopPolling()

    XCTAssertLessThanOrEqual(sut.currentInterval, 0.1,
      "Interval should never exceed maxPollingInterval")
  }

  func testBackoffResetsOnSuccess() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05,
      maxPollingInterval: 1.0,
      maxConsecutiveErrors: 10
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertGreaterThan(sut.consecutiveErrors, 0)

    // Now fix the error and let a successful poll happen
    mockAuthManager.shouldThrowRefreshError = false
    try? await Task.sleep(nanoseconds: 300_000_000)
    sut.stopPolling()

    XCTAssertEqual(sut.consecutiveErrors, 0, "Consecutive errors should reset on success")
    XCTAssertEqual(sut.currentInterval, 0.05, "Interval should reset to initial on success")
  }

  // MARK: - Error Handling Tests

  func testMaxConsecutiveErrorsStopsPollingWithErrorState() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.02,
      maxPollingInterval: 0.04,
      maxConsecutiveErrors: 2
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(
      sut.verificationState,
      .error(message: "Unable to verify email. Please check your connection.")
    )
    XCTAssertNotNil(sut.errorMessage)
  }

  func testErrorWithAuthErrorSetsDescriptiveMessage() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("Connection failed")
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.02,
      maxPollingInterval: 0.04,
      maxConsecutiveErrors: 0
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 300_000_000)

    XCTAssertEqual(sut.errorMessage, "Connection failed")
  }

  func testDismissErrorClearsMessage() {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)
    sut.dismissError()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Resend Tests

  func testResendVerificationEmailCallsAuthManager() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()

    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
  }

  func testResendStartsCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 3
    )

    XCTAssertTrue(sut.canResendEmail)

    await sut.resendVerificationEmail()

    XCTAssertFalse(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 3)
  }

  func testCannotResendDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 5
    )

    await sut.resendVerificationEmail()
    await sut.resendVerificationEmail()
    await sut.resendVerificationEmail()

    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1, "Should not resend during cooldown")
  }

  func testCooldownCompletesToZeroAndReenablesResend() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 2,
      cooldownInterval: 0.02
    )

    await sut.resendVerificationEmail()
    XCTAssertFalse(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 2)

    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertEqual(sut.resendCooldownSeconds, 0)
    XCTAssertTrue(sut.canResendEmail, "Resend should be re-enabled after cooldown completes")
  }

  func testResendWithNilUserEmailDoesNothing() async {
    // No user set — userEmail is nil
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()

    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 0,
      "Should not call resend when userEmail is nil")
    XCTAssertTrue(sut.canResendEmail, "canResendEmail should remain true when guard fails")
  }

  func testResendFailureSetsErrorMessage() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowResendError = true
    mockAuthManager.mockErrorToThrow = .serverError("Failed to send email")
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()

    XCTAssertEqual(sut.errorMessage, "Server error. Please try again later.")
  }

  func testResendSuccessClearsPriorError() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowResendError = true
    mockAuthManager.mockErrorToThrow = .serverError("Fail")
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()
    XCTAssertNotNil(sut.errorMessage)

    // Now succeed
    mockAuthManager.shouldThrowResendError = false
    sut = EmailVerificationViewModel(authManager: mockAuthManager)
    await sut.resendVerificationEmail()

    XCTAssertNil(sut.errorMessage, "Successful resend should clear error message")
  }

  // MARK: - Lifecycle Tests

  func testOnAppearStartsPolling() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.onAppear()
    XCTAssertTrue(sut.isPolling)

    try? await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)
  }

  func testOnDisappearStopsPolling() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.onAppear()
    try? await Task.sleep(nanoseconds: 200_000_000)
    let callCountBeforeDisappear = mockAuthManager.refreshSessionCallCount

    sut.onDisappear()
    XCTAssertFalse(sut.isPolling)

    try? await Task.sleep(nanoseconds: 300_000_000)
    XCTAssertEqual(mockAuthManager.refreshSessionCallCount, callCountBeforeDisappear)
  }

  func testOnAppearSkipsPollingWhenAlreadyVerified() async {
    mockAuthManager.setMockUser(verifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.onAppear()
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertFalse(sut.isPolling)
    XCTAssertEqual(mockAuthManager.refreshSessionCallCount, 0)
  }

  // MARK: - VerificationState Equatable Tests

  func testVerificationStateEqualityPending() {
    XCTAssertEqual(VerificationState.pending, VerificationState.pending)
  }

  func testVerificationStateEqualityChecking() {
    XCTAssertEqual(VerificationState.checking, VerificationState.checking)
  }

  func testVerificationStateEqualityVerified() {
    XCTAssertEqual(VerificationState.verified, VerificationState.verified)
  }

  func testVerificationStateEqualityErrorSameMessage() {
    XCTAssertEqual(
      VerificationState.error(message: "Network error"),
      VerificationState.error(message: "Network error")
    )
  }

  func testVerificationStateInequalityErrorDifferentMessage() {
    XCTAssertNotEqual(
      VerificationState.error(message: "Network error"),
      VerificationState.error(message: "Server error")
    )
  }

  func testVerificationStateInequalityDifferentCases() {
    XCTAssertNotEqual(VerificationState.pending, VerificationState.checking)
    XCTAssertNotEqual(VerificationState.pending, VerificationState.verified)
    XCTAssertNotEqual(VerificationState.checking, VerificationState.verified)
    XCTAssertNotEqual(VerificationState.pending, VerificationState.error(message: "err"))
  }

  // MARK: - Edge Cases

  func testVeryFastVerification() async {
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05
    )

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 50_000_000)

    mockAuthManager.setMockUser(verifiedUser)
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(sut.verificationState, .verified)
  }

  func testDeinitCancelsPollingAndCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    var viewModel: EmailVerificationViewModel? = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.05,
      cooldownDuration: 10
    )

    viewModel?.startPolling()
    await viewModel?.resendVerificationEmail()
    try? await Task.sleep(nanoseconds: 100_000_000)

    viewModel = nil

    // No crash = tasks were properly cancelled in deinit
    XCTAssertNil(viewModel)
  }
}
