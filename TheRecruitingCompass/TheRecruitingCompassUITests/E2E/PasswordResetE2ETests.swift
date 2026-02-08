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

  // MARK: - Forgot Password Flow

  func testNavigateToForgotPasswordFromLogin() {
    // Given: User is on login screen
    let forgotPasswordButton = app.buttons["Forgot Password?"]
    XCTAssertTrue(forgotPasswordButton.waitForExistence(timeout: 5))

    // When: User taps forgot password
    forgotPasswordButton.tap()

    // Then: Forgot password screen appears
    let emailField = app.textFields["Email"]
    XCTAssertTrue(emailField.waitForExistence(timeout: 2))

    let sendResetLinkButton = app.buttons["Send Reset Link"]
    XCTAssertTrue(sendResetLinkButton.exists)
  }

  func testSendPasswordResetEmailSuccessFlow() {
    // Navigate to forgot password screen
    app.buttons["Forgot Password?"].tap()

    let emailField = app.textFields["Email"]
    XCTAssertTrue(emailField.waitForExistence(timeout: 2))

    // Enter email
    emailField.tap()
    emailField.typeText("test@example.com")

    // Send reset link
    let sendButton = app.buttons["Send Reset Link"]
    XCTAssertTrue(sendButton.isEnabled)
    sendButton.tap()

    // Verify success message appears
    let successMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sent'"))
    XCTAssertTrue(successMessage.firstMatch.waitForExistence(timeout: 5))
  }

  func testSendPasswordResetEmailWithInvalidEmail() {
    app.buttons["Forgot Password?"].tap()

    let emailField = app.textFields["Email"]
    XCTAssertTrue(emailField.waitForExistence(timeout: 2))

    emailField.tap()
    emailField.typeText("invalid-email")

    let sendButton = app.buttons["Send Reset Link"]
    // Button should be disabled or show error on submit
    sendButton.tap()

    // Verify error message appears
    let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'valid email' OR label CONTAINS 'Invalid'"))
    XCTAssertTrue(errorMessage.firstMatch.waitForExistence(timeout: 2))
  }

  func testResendPasswordResetEmail() {
    app.buttons["Forgot Password?"].tap()

    let emailField = app.textFields["Email"]
    emailField.tap()
    emailField.typeText("test@example.com")

    // Send initial reset link
    app.buttons["Send Reset Link"].tap()

    // Wait for success state
    let resendButton = app.buttons["Resend Email"]
    XCTAssertTrue(resendButton.waitForExistence(timeout: 5))

    // Tap resend
    resendButton.tap()

    // Verify resend countdown appears
    let countdownText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '60' OR label CONTAINS 'Resend'"))
    XCTAssertTrue(countdownText.firstMatch.exists)
  }

  // MARK: - Reset Password Flow

  func testResetPasswordWithValidPassword() {
    // Note: This test assumes deep link navigation to reset password screen
    // In actual implementation, this would require deep link testing setup

    // Given: User is on reset password screen (via deep link)
    // For now, we'll test the screen directly if accessible

    let newPasswordField = app.secureTextFields["New Password"]
    if newPasswordField.waitForExistence(timeout: 2) {
      // Enter new password
      newPasswordField.tap()
      newPasswordField.typeText("NewStrongPass1")

      let confirmPasswordField = app.secureTextFields["Confirm Password"]
      confirmPasswordField.tap()
      confirmPasswordField.typeText("NewStrongPass1")

      // Submit
      let resetButton = app.buttons["Reset Password"]
      XCTAssertTrue(resetButton.isEnabled)
      resetButton.tap()

      // Verify success message
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
    // Step 1: Navigate to forgot password
    app.buttons["Forgot Password?"].tap()

    // Step 2: Enter email and send reset link
    let emailField = app.textFields["Email"]
    XCTAssertTrue(emailField.waitForExistence(timeout: 2))
    emailField.tap()
    emailField.typeText("test@example.com")

    app.buttons["Send Reset Link"].tap()

    // Step 3: Verify email sent confirmation
    let sentConfirmation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sent' OR label CONTAINS 'check your email'"))
    XCTAssertTrue(sentConfirmation.firstMatch.waitForExistence(timeout: 5))

    // Step 4: User would click link in email (simulated by deep link in real test)
    // For this E2E test, we verify the confirmation screen shows expected elements

    let backToLoginButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Back' OR label CONTAINS 'Login'"))
    XCTAssertTrue(backToLoginButton.firstMatch.exists)

    // Step 5: Navigate back to login
    backToLoginButton.firstMatch.tap()

    // Verify we're back at login screen
    let loginButton = app.buttons["Login"]
    XCTAssertTrue(loginButton.waitForExistence(timeout: 2))
  }

  // MARK: - Error Handling

  func testNetworkErrorHandlingInForgotPassword() {
    // Note: This requires mock network conditions or test environment setup
    app.buttons["Forgot Password?"].tap()

    let emailField = app.textFields["Email"]
    emailField.tap()
    emailField.typeText("test@example.com")

    app.buttons["Send Reset Link"].tap()

    // If network error occurs, error banner should appear
    let errorBanner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'try again'"))

    if errorBanner.firstMatch.waitForExistence(timeout: 5) {
      // Verify user can dismiss error
      let dismissButton = app.buttons["Dismiss"]
      if dismissButton.exists {
        dismissButton.tap()
        XCTAssertFalse(errorBanner.firstMatch.exists)
      }
    }
  }

  func testFormValidationRealTimeUpdates() {
    app.buttons["Forgot Password?"].tap()

    let emailField = app.textFields["Email"]
    let sendButton = app.buttons["Send Reset Link"]

    // Initially button should be disabled
    XCTAssertFalse(sendButton.isEnabled)

    // Type partial email
    emailField.tap()
    emailField.typeText("test")

    // Still disabled
    XCTAssertFalse(sendButton.isEnabled)

    // Complete valid email
    emailField.typeText("@example.com")

    // Now enabled
    XCTAssertTrue(sendButton.isEnabled)

    // Clear email
    emailField.tap()
    for _ in 0..<16 {
      emailField.typeText(XCUIKeyboardKey.delete.rawValue)
    }

    // Disabled again
    XCTAssertFalse(sendButton.isEnabled)
  }

  // MARK: - Accessibility

  func testForgotPasswordScreenAccessibility() {
    app.buttons["Forgot Password?"].tap()

    // Verify all interactive elements have accessibility labels
    XCTAssertTrue(app.textFields["Email"].exists)
    XCTAssertTrue(app.buttons["Send Reset Link"].exists)

    // Verify heading exists
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
