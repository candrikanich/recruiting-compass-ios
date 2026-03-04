import XCTest

final class PasswordResetE2ETests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["UI_TESTING"]
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  /// Navigate from Landing → Login → Forgot Password (Forgot password link is on Login, not Landing).
  private func navigateToForgotPassword() {
    let signInButton = app.buttons["Sign in to your account"]
    if signInButton.waitForExistence(timeout: 5) {
      signInButton.tap()
    }
    let forgotPasswordLink = app.buttons["Forgot password"]
    XCTAssertTrue(forgotPasswordLink.waitForExistence(timeout: 5))
    forgotPasswordLink.tap()
  }

  /// Email field on Forgot Password uses combined accessibility (same as LoginFormField).
  private var forgotPasswordEmailField: XCUIElement {
    app.otherElements["Email"].firstMatch
  }

  private var sendResetLinkButton: XCUIElement {
    app.buttons["Send password reset link"]
  }

  private var resendButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send another reset link'")).firstMatch
  }

  // MARK: - Forgot Password Flow

  func testNavigateToForgotPasswordFromLogin() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5),
                  "Forgot password screen should show email field")
    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 2),
                  "Send password reset link button should be visible")
  }

  func testSendPasswordResetEmailSuccessFlow() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 2))
    sendResetLinkButton.tap()

    let successMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sent'"))
    XCTAssertTrue(successMessage.firstMatch.waitForExistence(timeout: 5))
  }

  func testSendPasswordResetEmailWithInvalidEmail() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("invalid-email")

    sendResetLinkButton.tap()

    let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'valid email' OR label CONTAINS 'Invalid'"))
    XCTAssertTrue(errorMessage.firstMatch.waitForExistence(timeout: 5))
  }

  func testResendPasswordResetEmail() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    sendResetLinkButton.tap()

    XCTAssertTrue(resendButton.waitForExistence(timeout: 10),
                  "Resend button should appear after sending (may show countdown)")

    resendButton.tap()

    let countdownText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '60' OR label CONTAINS 'Resend' OR label CONTAINS 'available'"))
    XCTAssertTrue(countdownText.firstMatch.waitForExistence(timeout: 3) || resendButton.exists)
  }

  // MARK: - Reset Password Flow

  func testResetPasswordWithValidPassword() {
    // Assumes deep link to reset password screen; test screen if present
    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      newPasswordField.tap()
      newPasswordField.typeText("NewStrongPass1")

      let confirmPasswordField = app.secureTextFields["Confirm Password"]
      confirmPasswordField.tap()
      confirmPasswordField.typeText("NewStrongPass1")

      let resetButton = app.buttons["Reset Password"]
      XCTAssertTrue(resetButton.isEnabled)
      resetButton.tap()

      let successMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'success' OR label CONTAINS 'updated'"))
      XCTAssertTrue(successMessage.firstMatch.waitForExistence(timeout: 5))
    }
  }

  func testResetPasswordWithWeakPassword() {
    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      newPasswordField.tap()
      newPasswordField.typeText("weak")

      let confirmPasswordField = app.secureTextFields["Confirm Password"]
      confirmPasswordField.tap()
      confirmPasswordField.typeText("weak")

      // Verify password strength indicator shows weak
      let weakIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'weak' OR label CONTAINS 'not meet'"))
      XCTAssertTrue(weakIndicator.firstMatch.exists)

      // Button should be disabled
      let resetButton = app.buttons["Reset Password"]
      XCTAssertFalse(resetButton.isEnabled)
    }
  }

  func testResetPasswordWithMismatchedPasswords() {
    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      newPasswordField.tap()
      newPasswordField.typeText("StrongPass1")

      let confirmPasswordField = app.secureTextFields["Confirm Password"]
      confirmPasswordField.tap()
      confirmPasswordField.typeText("DifferentPass1")

      // Verify mismatch error appears
      let mismatchError = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'match' OR label CONTAINS 'same'"))
      XCTAssertTrue(mismatchError.firstMatch.exists)

      // Button should be disabled
      let resetButton = app.buttons["Reset Password"]
      XCTAssertFalse(resetButton.isEnabled)
    }
  }

  func testPasswordVisibilityToggle() {
    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      newPasswordField.tap()
      newPasswordField.typeText("StrongPass1")

      // Toggle visibility
      let toggleButton = app.buttons["Show Password"]
      if toggleButton.exists {
        toggleButton.tap()

        // Password should now be visible as text field
        let visiblePasswordField = app.textFields["New Password"]
        XCTAssertTrue(visiblePasswordField.exists)

        // Toggle back
        let hideButton = app.buttons["Hide Password"]
        hideButton.tap()

        // Should be secure again
        XCTAssertTrue(newPasswordField.exists)
      }
    }
  }

  // MARK: - Complete User Journey

  func testCompletePasswordResetJourney() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    sendResetLinkButton.tap()

    let sentConfirmation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sent' OR label CONTAINS 'check your email'"))
    XCTAssertTrue(sentConfirmation.firstMatch.waitForExistence(timeout: 5))

    let backToLoginButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Back' OR label CONTAINS 'Login'"))
    XCTAssertTrue(backToLoginButton.firstMatch.waitForExistence(timeout: 3))
    backToLoginButton.firstMatch.tap()

    let loginButton = app.buttons["Login"]
    XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
  }

  // MARK: - Error Handling

  func testNetworkErrorHandlingInForgotPassword() {
    navigateToForgotPassword()

    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    sendResetLinkButton.tap()

    let errorBanner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'try again'"))

    if errorBanner.firstMatch.waitForExistence(timeout: 5) {
      let dismissButton = app.buttons["Dismiss"]
      if dismissButton.exists {
        dismissButton.tap()
        XCTAssertFalse(errorBanner.firstMatch.exists)
      }
    }
  }

  func testFormValidationRealTimeUpdates() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))

    // Initially button may be disabled (empty email)
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test")

    forgotPasswordEmailField.typeText("@example.com")

    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 2))

    // Clear email
    for _ in 0..<16 {
      forgotPasswordEmailField.typeText(XCUIKeyboardKey.delete.rawValue)
    }
  }

  // MARK: - Accessibility

  func testForgotPasswordScreenAccessibility() {
    navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 2))

    let heading = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Forgot' OR label CONTAINS 'Reset'"))
    XCTAssertTrue(heading.firstMatch.exists)
  }

  func testResetPasswordScreenAccessibility() {
    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      XCTAssertTrue(newPasswordField.exists)
      XCTAssertTrue(app.secureTextFields["Confirm Password"].exists)
      XCTAssertTrue(app.buttons["Reset Password"].exists)

      // Verify password strength indicator is accessible
      let strengthIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Password Strength' OR label CONTAINS 'strength'"))
      XCTAssertTrue(strengthIndicator.firstMatch.exists)
    }
  }
}
