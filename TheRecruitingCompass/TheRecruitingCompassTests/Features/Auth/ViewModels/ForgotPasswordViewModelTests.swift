import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ForgotPasswordViewModelTests: XCTestCase {
  var sut: ForgotPasswordViewModel!
  var mockAuthManager: MockAuthManager!

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
    XCTAssertNil(sut.fieldErrors["email"])
  }

  func testValidateEmailWithEmptyEmail() {
    sut.email = ""
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors["email"])
  }

  func testValidateEmailWithInvalidEmail() {
    sut.email = "not-an-email"
    sut.validateEmail()
    XCTAssertNotNil(sut.fieldErrors["email"])
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
    sut.fieldErrors["email"] = "Invalid"
    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - Button Disabled

  func testButtonDisabledWhenLoading() {
    sut.email = "user@example.com"
    sut.isLoading = true
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
    sut.submittedEmail = "user@example.com"
    sut.emailSent = true

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertFalse(sut.canResendEmail)
    XCTAssertEqual(sut.resendCooldownSeconds, 60)
  }

  func testResendResetLinkWhenCooldownActive() async {
    sut.canResendEmail = false
    sut.submittedEmail = "user@example.com"

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 0)
  }

  func testResendResetLinkFailure() async {
    mockAuthManager.shouldThrowResetEmailError = true
    mockAuthManager.mockErrorToThrow = .networkError("Network error")

    sut.submittedEmail = "user@example.com"
    sut.emailSent = true

    await sut.resendResetLink()

    XCTAssertEqual(mockAuthManager.resetEmailCallCount, 1)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Reset Form

  func testResetFormClearsState() {
    sut.emailSent = true
    sut.submittedEmail = "user@example.com"
    sut.errorMessage = "Some error"
    sut.fieldErrors["email"] = "Invalid"

    sut.resetForm()

    XCTAssertFalse(sut.emailSent)
    XCTAssertEqual(sut.submittedEmail, "")
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Dismiss Error

  func testDismissError() {
    sut.errorMessage = "Some error"
    sut.dismissError()
    XCTAssertNil(sut.errorMessage)
  }
}
