import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ForgotPasswordViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: ForgotPasswordViewModel!
  var mockAuthManager: MockAuthManager!

  /// Same durations as `.default` but a tiny tick interval so cooldown timer
  /// tests advance in milliseconds instead of real seconds.
  static let fastTimerConfig = PasswordResetConfig(
    resendCooldownDuration: 60,
    successCountdownDuration: 3,
    timerInterval: 0.01
  )

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    sut = ForgotPasswordViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertEqual(sut.email, "")
    XCTAssertFalse(sut.isLoading)
    XCTAssertFalse(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "")
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
    XCTAssertTrue(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 0)
  }

  // MARK: - Validation

  func testValidateEmailWithValidEmail() {
    sut.email = "user@example.com"
    sut.validateEmail()
    XCTAssertNil(sut.fieldErrors[.email])
  }

  func testValidateEmailWithEmptyEmail() {
    sut.email = ""
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors[.email])
  }

  func testValidateEmailWithInvalidEmail() {
    sut.email = "not-an-email"
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors[.email])
  }

  // MARK: - Form Valid

  func testIsFormValidWithValidEmail() {
    sut.email = "user@example.com"
    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormValidWithEmptyEmail() {
    sut.email = ""
    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormValidWithFieldErrors() {
    sut.email = "user@example.com"
    sut.fieldErrors[.email] = "Invalid"
    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - Button Disabled

  func testButtonDisabledWhenLoading() {
    sut.email = "user@example.com"
    sut.state = .sending
    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testButtonDisabledWhenFormInvalid() {
    sut.email = ""
    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testButtonEnabledWhenFormValid() {
    sut.email = "user@example.com"
    XCTAssertFalse(sut.isButtonDisabled)
  }

  // MARK: - Send Reset Link

  func testSendResetLinkSuccess() async {
    sut.email = "user@example.com"
    await sut.sendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertTrue(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "user@example.com")
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testSendResetLinkFailure() async {
    mockAuthManager.shouldThrowResetEmailError = true
    mockAuthManager.mockErrorToThrow = .resetEmailNotFound

    sut.email = "unknown@example.com"
    await sut.sendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertFalse(sut.emailSent)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testSendResetLinkWithInvalidEmail() async {
    sut.email = "not-valid"
    await sut.sendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 0)
    XCTAssertFalse(sut.emailSent)
  }

  // MARK: - Resend

  func testResendResetLinkSuccess() async {
    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertFalse(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 60)
  }

  func testResendResetLinkWhenCooldownActive() async {
    sut.canResendEmail = false
    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 0)
  }

  func testResendResetLinkFailure() async {
    mockAuthManager.shouldThrowResetEmailError = true
    mockAuthManager.mockErrorToThrow = .networkError("Network error")

    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Reset Form

  func testResetFormClearsState() {
    sut.state = .emailSent(submittedEmail: "user@example.com")
    sut.fieldErrors[.email] = "Invalid"

    sut.resetForm()

    XCTAssertEqual(sut.state, .form)
    XCTAssertFalse(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "")
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Dismiss Error

  func testDismissError() {
    sut.state = .error(message: "Some error")
    sut.dismissError()
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.state, .form)
  }

  // MARK: - Timer Behavior

  func testResendCooldownTimerCountsDown() async {
    sut = ForgotPasswordViewModel(authManager: mockAuthManager, config: Self.fastTimerConfig)
    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    XCTAssertEqual(sut.resendCooldownSeconds, 60)
    XCTAssertFalse(sut.canResendEmail)

    // Several ticks at the fast test interval, well short of the full drain
    try? await Task.sleep(nanoseconds: 150_000_000)

    XCTAssertLessThan(sut.resendCooldownSeconds, 60, "Timer should have counted down")
    XCTAssertGreaterThan(sut.resendCooldownSeconds, 0, "Cooldown should not have fully drained yet")
  }

  func testResendCooldownTimerStartsAndCountsDown() async {
    sut = ForgotPasswordViewModel(authManager: mockAuthManager, config: Self.fastTimerConfig)
    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    // Timer should start at 60
    XCTAssertEqual(sut.resendCooldownSeconds, 60)
    XCTAssertFalse(sut.canResendEmail)

    // Several ticks at the fast test interval, well short of the full drain
    try? await Task.sleep(nanoseconds: 200_000_000)

    // Timer should have counted down without draining
    XCTAssertLessThan(sut.resendCooldownSeconds, 60, "Timer should have counted down")
    XCTAssertGreaterThan(sut.resendCooldownSeconds, 0, "Cooldown should not have fully drained yet")
    XCTAssertFalse(sut.canResendEmail)
  }

  func testResendCooldownTimerDoesNotStartOnError() async {
    mockAuthManager.shouldThrowResetEmailError = true
    mockAuthManager.mockErrorToThrow = .networkError("Error")

    sut.state = .emailSent(submittedEmail: "user@example.com")

    await sut.resendResetLink()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.resendCooldownSeconds, 0)
    XCTAssertTrue(sut.canResendEmail)
  }

  // MARK: - Edge Cases

  func testEmailWhitespaceTrimmingInValidation() {
    sut.email = "  user@example.com  "
    XCTAssertTrue(sut.isFormValid)
  }

  func testEmailChangedAfterEmailSent() async {
    sut.email = "user@example.com"
    await sut.sendResetLink()

    XCTAssertTrue(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "user@example.com")

    sut.email = "newuser@example.com"

    XCTAssertEqual(sut.email, "newuser@example.com")
    XCTAssertEqual(sut.submittedEmail, "user@example.com")
  }

  func testMultipleRapidSendAttempts() async {
    sut.email = "user@example.com"

    // Send multiple times in sequence
    await sut.sendResetLink()
    await sut.sendResetLink()
    await sut.sendResetLink()

    // All should succeed since no cooldown on initial send
    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 3)
    XCTAssertTrue(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "user@example.com")
  }

  // MARK: - Error Mapping

  func testErrorMappingForDifferentAuthErrors() async {
    let authErrors: [AuthError] = [
      .resetEmailNotFound,
      .networkError("Network issue"),
      .invalidCredentials,
      .userNotFound
    ]

    for authError in authErrors {
      mockAuthManager.shouldThrowResetEmailError = true
      mockAuthManager.mockErrorToThrow = authError
      sut.email = "user@example.com"

      await sut.sendResetLink()

      XCTAssertNotNil(sut.errorMessage)
      XCTAssertFalse(sut.errorMessage!.isEmpty)

      sut.state = .form
      mockAuthManager.resetEmailCallCount = 0
    }
  }
}
