import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ResetPasswordViewModelTests: XCTestCase {
  var sut: ResetPasswordViewModel!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    sut = ResetPasswordViewModel(authManager: mockAuthManager)
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertEqual(sut.state, .form)
    XCTAssertEqual(sut.newPassword, "")
    XCTAssertEqual(sut.confirmPassword, "")
    XCTAssertFalse(sut.isPasswordVisible)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
    XCTAssertEqual(sut.successCountdown, 3)
    XCTAssertFalse(sut.shouldNavigateToLogin)
  }

  // MARK: - Password Strength

  func testPasswordStrengthWeak() {
    sut.newPassword = "weak"
    XCTAssertFalse(sut.passwordStrength.isValid)
    XCTAssertFalse(sut.passwordStrength.errors.isEmpty)
  }

  func testPasswordStrengthStrong() {
    sut.newPassword = "StrongPass1"
    XCTAssertTrue(sut.passwordStrength.isValid)
    XCTAssertTrue(sut.passwordStrength.errors.isEmpty)
  }

  // MARK: - Passwords Match

  func testPasswordsMatchWhenEqual() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    XCTAssertTrue(sut.passwordsMatch)
  }

  func testPasswordsDoNotMatch() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "Different1"
    XCTAssertFalse(sut.passwordsMatch)
  }

  func testPasswordsMatchEmptyNewPassword() {
    sut.newPassword = ""
    sut.confirmPassword = ""
    XCTAssertFalse(sut.passwordsMatch)
  }

  // MARK: - Form Valid

  func testIsFormValidWhenStrongAndMatching() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    XCTAssertTrue(sut.isFormValid)
  }

  func testIsFormInvalidWhenWeak() {
    sut.newPassword = "weak"
    sut.confirmPassword = "weak"
    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWhenNotMatching() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "DifferentPass1"
    XCTAssertFalse(sut.isFormValid)
  }

  func testIsFormInvalidWithFieldErrors() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    sut.fieldErrors["newPassword"] = "Error"
    XCTAssertFalse(sut.isFormValid)
  }

  // MARK: - Button Disabled

  func testButtonDisabledWhenResetting() {
    sut.state = .resetting
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testButtonDisabledWhenFormInvalid() {
    sut.newPassword = ""
    XCTAssertTrue(sut.isButtonDisabled)
  }

  func testButtonEnabledWhenFormValid() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    XCTAssertFalse(sut.isButtonDisabled)
  }

  // MARK: - Validate New Password

  func testValidateNewPasswordWeak() {
    sut.newPassword = "weak"
    sut.validateNewPassword()
    XCTAssertNotNil(sut.fieldErrors["newPassword"])
  }

  func testValidateNewPasswordStrong() {
    sut.newPassword = "StrongPass1"
    sut.validateNewPassword()
    XCTAssertNil(sut.fieldErrors["newPassword"])
  }

  func testValidateNewPasswordAlsoValidatesConfirmWhenNotEmpty() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "OtherPass1"
    sut.validateNewPassword()
    XCTAssertNotNil(sut.fieldErrors["confirmPassword"])
  }

  // MARK: - Validate Confirm Password

  func testValidateConfirmPasswordMatch() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"
    sut.validateConfirmPassword()
    XCTAssertNil(sut.fieldErrors["confirmPassword"])
  }

  func testValidateConfirmPasswordNoMatch() {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "Different1"
    sut.validateConfirmPassword()
    XCTAssertNotNil(sut.fieldErrors["confirmPassword"])
  }

  // MARK: - Reset Password

  func testResetPasswordSuccess() async {
    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"

    await sut.resetPassword()

    XCTAssertEqual(mockAuthManager.updatePasswordCallCount, 1)
    XCTAssertEqual(sut.state, .success)
  }

  func testResetPasswordFailure() async {
    mockAuthManager.shouldThrowUpdatePasswordError = true
    mockAuthManager.mockErrorToThrow = .invalidResetToken

    sut.newPassword = "StrongPass1"
    sut.confirmPassword = "StrongPass1"

    await sut.resetPassword()

    XCTAssertEqual(mockAuthManager.updatePasswordCallCount, 1)
    if case .error(let message) = sut.state {
      XCTAssertFalse(message.isEmpty)
    } else {
      XCTFail("Expected error state")
    }
  }

  func testResetPasswordWithInvalidForm() async {
    sut.newPassword = "weak"
    sut.confirmPassword = "weak"

    await sut.resetPassword()

    XCTAssertEqual(mockAuthManager.updatePasswordCallCount, 0)
    XCTAssertEqual(sut.state, .form)
  }

  // MARK: - Success Countdown

  func testStartSuccessCountdown() {
    sut.startSuccessCountdown()
    XCTAssertEqual(sut.successCountdown, 3)
  }

  // MARK: - Return To Form

  func testReturnToForm() {
    sut.state = .error(message: "Error")
    sut.fieldErrors["newPassword"] = "Error"

    sut.returnToForm()

    XCTAssertEqual(sut.state, .form)
    XCTAssertTrue(sut.fieldErrors.isEmpty)
  }

  // MARK: - Is Loading

  func testIsLoadingWhenResetting() {
    sut.state = .resetting
    XCTAssertTrue(sut.isLoading)
  }

  func testIsNotLoadingWhenForm() {
    sut.state = .form
    XCTAssertFalse(sut.isLoading)
  }

  func testIsNotLoadingWhenSuccess() {
    sut.state = .success
    XCTAssertFalse(sut.isLoading)
  }
}
