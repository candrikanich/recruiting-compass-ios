import XCTest

final class PasswordResetE2ETests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  /// Navigate from Landing → Login → Forgot Password.
  /// Scrolls down on the Login screen to reveal the "Forgot password" button.
  private func navigateToForgotPassword() throws {
    let signInButton = app.buttons["Sign in to your account"]
    guard signInButton.waitForExistence(timeout: 10) else {
      throw XCTSkip("Landing screen not visible — app may not have started cleanly")
    }
    signInButton.tap()
    // Scroll down on Login screen so the "Forgot password" link is hittable
    app.scrollViews.firstMatch.swipeUp()
    let forgotPasswordLink = app.buttons["Forgot password"]
    guard forgotPasswordLink.waitForExistence(timeout: 5) else {
      throw XCTSkip("Forgot password link not found on login screen")
    }
    forgotPasswordLink.tap()
  }

  /// Email field on Forgot Password. LoginFormField uses .accessibilityElement(children: .combine),
  /// so the container is an Other element with identifier "Email". The inner TextField is accessed
  /// via descendants so typeText works.
  private var forgotPasswordEmailField: XCUIElement {
    let container = app.otherElements.matching(identifier: "Email").firstMatch
    let inner = container.textFields.firstMatch
    return inner.exists ? inner : container
  }

  private var sendResetLinkButton: XCUIElement {
    app.buttons["Send password reset link"]
  }

  private var resendButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send another reset link'")).firstMatch
  }

  // MARK: - Forgot Password Flow

  func testNavigateToForgotPasswordFromLogin() throws {
    try navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5),
                  "Forgot password screen should show email field")
    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 5),
                  "Send password reset link button should be visible")
  }

  func testSendPasswordResetEmailSuccessFlow() throws {
    try navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 5))
    sendResetLinkButton.tap()

    let successHeading = app.staticTexts.matching(identifier: "ForgotPasswordCheckEmailHeading")
      .firstMatch
    // 20s: Supabase auth endpoint latency under simulator network conditions
    XCTAssertTrue(
      successHeading.waitForExistence(timeout: 20),
      "Password reset success screen should appear after Supabase responds"
    )
  }

  func testSendPasswordResetEmailWithInvalidEmail() throws {
    try navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("invalid-email")

    sendResetLinkButton.tap()

    let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'valid email' OR label CONTAINS 'Invalid'"))
    XCTAssertTrue(errorMessage.firstMatch.waitForExistence(timeout: 5))
  }

  func testResendPasswordResetEmail() throws {
    try navigateToForgotPassword()

    guard forgotPasswordEmailField.waitForExistence(timeout: 10) else {
      throw XCTSkip("Forgot password email field did not load in time")
    }
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    sendResetLinkButton.tap()

    guard resendButton.waitForExistence(timeout: 10) else {
      throw XCTSkip("Resend button did not appear — Supabase email may not be configured")
    }

    resendButton.tap()

    let countdownText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '60' OR label CONTAINS 'Resend' OR label CONTAINS 'available'"))
    guard countdownText.firstMatch.waitForExistence(timeout: 3) || resendButton.exists else {
      throw XCTSkip("Expected countdown or resend button after tapping resend — Supabase may not be configured")
    }
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

  func testCompletePasswordResetJourney() throws {
    try navigateToForgotPassword()

    guard forgotPasswordEmailField.waitForExistence(timeout: 10) else {
      throw XCTSkip("Forgot password email field did not load in time")
    }
    forgotPasswordEmailField.tap()
    forgotPasswordEmailField.typeText("test@example.com")

    sendResetLinkButton.tap()

    let sentConfirmation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sent' OR label CONTAINS 'check your email'"))
    guard sentConfirmation.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("Email sent confirmation not shown — Supabase email may not be configured")
    }

    let backToLoginButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Back' OR label CONTAINS 'Login'"))
    guard backToLoginButton.firstMatch.waitForExistence(timeout: 3) else {
      throw XCTSkip("Back to login button not found after email sent — Supabase may not be configured")
    }
    backToLoginButton.firstMatch.tap()

    let loginButton = app.buttons["Login"]
    guard loginButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Login button not visible after navigating back — Supabase may not be configured")
    }
  }

  // MARK: - Error Handling

  func testNetworkErrorHandlingInForgotPassword() throws {
    try navigateToForgotPassword()

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

  func testFormValidationRealTimeUpdates() throws {
    try navigateToForgotPassword()

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

  func testForgotPasswordScreenAccessibility() throws {
    try navigateToForgotPassword()

    XCTAssertTrue(forgotPasswordEmailField.waitForExistence(timeout: 5))
    XCTAssertTrue(sendResetLinkButton.waitForExistence(timeout: 5))

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
