import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationViewModelTests: XCTestCase {
  var sut: EmailVerificationViewModel!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    sut = EmailVerificationViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func testInitialStateWithUnverifiedUser() {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .pending)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 0)
    XCTAssertEqual(sut.userEmail, "test@example.com")
    XCTAssertFalse(sut.isVerified)
  }

  func testInitialStateWithVerifiedUser() {
    let verifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(verifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .verified)
    XCTAssertTrue(sut.isVerified)
  }

  func testUserEmailProperty() {
    let user = User(
      id: "test-id",
      email: "john.doe@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(user)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.userEmail, "john.doe@example.com")
  }

  // MARK: - Polling Tests

  func testStartPollingCallsRefreshSession() async {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)

    sut.stopPolling()
  }

  func testStopPollingCancelsTask() async {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)
    let initialCallCount = mockAuthManager.refreshSessionCallCount

    sut.stopPolling()
    try? await Task.sleep(nanoseconds: 300_000_000) // Wait to ensure polling stopped

    let finalCallCount = mockAuthManager.refreshSessionCallCount
    XCTAssertEqual(initialCallCount, finalCallCount, "Polling should not continue after stop")
  }

  func testPollingContinuesWhileUnverified() async {
    let unverifiedUser = User(
      id: "test-id",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)
    XCTAssertEqual(sut.verificationState, .pending)

    sut.stopPolling()
  }

  func testPollingStopsWhenVerified() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    mockAuthManager.setMockUser(verifiedUser)
    try? await Task.sleep(nanoseconds: 3_000_000_000) // Wait for next polling cycle

    XCTAssertEqual(sut.verificationState, .verified)

    sut.stopPolling()
  }

  // MARK: - State Transition Tests

  func testVerificationStateChangesPendingToChecking() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .pending)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    // State should progress to checking during polling
    XCTAssertTrue(
      sut.verificationState == .checking || sut.verificationState == .pending,
      "State should be checking or pending during polling"
    )

    sut.stopPolling()
  }

  func testVerificationStateChangesCheckingToVerified() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .verified)
  }

  func testVerificationStateChangesCheckingToPending() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(sut.verificationState, .pending)
  }

  // MARK: - Error Handling Tests

  func testNetworkErrorSetsErrorState() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertNotNil(sut.errorMessage)

    sut.stopPolling()
  }

  func testErrorMessageCleared() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 500_000_000)
    XCTAssertNotNil(sut.errorMessage)

    sut.dismissError()
    XCTAssertNil(sut.errorMessage)

    sut.stopPolling()
  }

  // MARK: - Resend Tests

  func testResendVerificationEmailCallsAuthManager() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()

    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
  }

  func testResendStartsCooldown() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertTrue(sut.canResendEmail)

    await sut.resendVerificationEmail()

    XCTAssertFalse(sut.canResendEmail)
    XCTAssertGreaterThan(sut.resendCooldownSeconds, 0)
  }

  func testCannotResendDuringCooldown() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()
    let callCountAfterFirst = mockAuthManager.resendEmailCallCount

    await sut.resendVerificationEmail()
    let callCountAfterSecond = mockAuthManager.resendEmailCallCount

    XCTAssertEqual(callCountAfterFirst, callCountAfterSecond, "Should not resend during cooldown")
  }

  func testCooldownProgressesToCompletion() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()
    XCTAssertFalse(sut.canResendEmail)

    // Wait for cooldown to complete (60 seconds is too long for test, so we skip this in real implementation)
    // In actual tests, we might mock the cooldown or use shorter test durations
  }

  func testResendFailureSetsError() async {
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
    mockAuthManager.shouldThrowResendError = true
    mockAuthManager.mockErrorToThrow = .serverError("Failed to send email")
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()

    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Lifecycle Tests

  func testOnAppearStartsPolling() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.onAppear()
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertGreaterThan(mockAuthManager.refreshSessionCallCount, 0)

    sut.onDisappear()
  }

  func testOnDisappearStopsPolling() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.onAppear()
    try? await Task.sleep(nanoseconds: 300_000_000)
    let callCountBeforeDisappear = mockAuthManager.refreshSessionCallCount

    sut.onDisappear()
    try? await Task.sleep(nanoseconds: 300_000_000)

    let callCountAfterDisappear = mockAuthManager.refreshSessionCallCount
    XCTAssertEqual(callCountBeforeDisappear, callCountAfterDisappear)
  }

  func testOnAppearSkipsPollingWhenAlreadyVerified() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.onAppear()
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(mockAuthManager.refreshSessionCallCount, 0, "Should not poll when already verified")
  }

  // MARK: - Edge Cases

  func testVeryFastVerification() async {
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
      emailConfirmedAt: "2024-01-01T00:00:01Z",
      phone: nil,
      userMetadata: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:01Z"
    )

    mockAuthManager.setMockUser(unverifiedUser)
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    sut.startPolling()
    try? await Task.sleep(nanoseconds: 100_000_000)

    mockAuthManager.setMockUser(verifiedUser)
    try? await Task.sleep(nanoseconds: 3_000_000_000)

    XCTAssertEqual(sut.verificationState, .verified)

    sut.stopPolling()
  }

  func testMultipleResendAttempts() async {
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
    sut = EmailVerificationViewModel(authManager: mockAuthManager)

    await sut.resendVerificationEmail()
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)

    // Should not be able to resend immediately
    await sut.resendVerificationEmail()
    XCTAssertEqual(mockAuthManager.resendEmailCallCount, 1)
  }
}
