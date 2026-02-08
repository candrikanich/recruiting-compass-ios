import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PasswordResetIntegrationTests: XCTestCase {
  var authManager: MockAuthManager!
  var forgotPasswordViewModel: ForgotPasswordViewModel!
  var resetPasswordViewModel: ResetPasswordViewModel!

  override func setUp() {
    super.setUp()
    authManager = MockAuthManager()
    forgotPasswordViewModel = ForgotPasswordViewModel(authManager: authManager)
    resetPasswordViewModel = ResetPasswordViewModel(authManager: authManager)
  }

  override func tearDown() {
    forgotPasswordViewModel = nil
    resetPasswordViewModel = nil
    authManager = nil
    super.tearDown()
  }

  // MARK: - Full Flow: Request → Reset

  func testCompletePasswordResetFlow() async {
    let testEmail = "user@example.com"
    let newPassword = "NewStrongPass1"

    // Step 1: User requests password reset
    forgotPasswordViewModel.email = testEmail
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)
    XCTAssertEqual(forgotPasswordViewModel.submittedEmail, testEmail)
    XCTAssertEqual(authManager.resetEmailCallCount, 1)

    // Step 2: User clicks reset link (simulated by having valid session)
    // In real app, this would be handled by deep link

    // Step 3: User enters new password
    resetPasswordViewModel.newPassword = newPassword
    resetPasswordViewModel.confirmPassword = newPassword

    XCTAssertTrue(resetPasswordViewModel.isFormValid)

    // Step 4: User submits new password
    await resetPasswordViewModel.resetPassword()

    XCTAssertEqual(resetPasswordViewModel.state, .success)
    XCTAssertEqual(authManager.updatePasswordCallCount, 1)
  }

  func testPasswordResetFlowWithInvalidEmail() async {
    forgotPasswordViewModel.email = "invalid-email"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertFalse(forgotPasswordViewModel.emailSent)
    XCTAssertEqual(authManager.resetEmailCallCount, 0)
  }

  func testPasswordResetFlowWithNetworkError() async {
    authManager.shouldThrowResetEmailError = true
    authManager.mockErrorToThrow = .networkError("Network unavailable")

    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertFalse(forgotPasswordViewModel.emailSent)
    XCTAssertNotNil(forgotPasswordViewModel.errorMessage)
    XCTAssertTrue(forgotPasswordViewModel.errorMessage!.contains("Network") || forgotPasswordViewModel.errorMessage!.contains("error"))
  }

  func testPasswordResetFlowWithWeakPassword() async {
    // Step 1: Successfully request reset
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)

    // Step 2: Try to reset with weak password
    resetPasswordViewModel.newPassword = "weak"
    resetPasswordViewModel.confirmPassword = "weak"

    XCTAssertFalse(resetPasswordViewModel.isFormValid)

    await resetPasswordViewModel.resetPassword()

    // Should not call API with invalid form
    XCTAssertEqual(authManager.updatePasswordCallCount, 0)
    XCTAssertEqual(resetPasswordViewModel.state, .form)
  }

  func testPasswordResetFlowWithMismatchedPasswords() async {
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)

    resetPasswordViewModel.newPassword = "StrongPass1"
    resetPasswordViewModel.confirmPassword = "DifferentPass1"

    XCTAssertFalse(resetPasswordViewModel.passwordsMatch)
    XCTAssertFalse(resetPasswordViewModel.isFormValid)

    await resetPasswordViewModel.resetPassword()

    XCTAssertEqual(authManager.updatePasswordCallCount, 0)
    XCTAssertEqual(resetPasswordViewModel.state, .form)
  }

  // MARK: - Resend Flow

  func testResendResetEmailAfterInitialRequest() async {
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)
    XCTAssertEqual(authManager.resetEmailCallCount, 1)

    await forgotPasswordViewModel.resendResetLink()

    XCTAssertEqual(authManager.resetEmailCallCount, 2)
    XCTAssertFalse(forgotPasswordViewModel.canResendEmail)
    XCTAssertEqual(forgotPasswordViewModel.resendCooldownSeconds, 60)
  }

  func testResendResetEmailMultipleTimesRespectsCooldown() async {
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertEqual(authManager.resetEmailCallCount, 1)

    // First resend should work
    await forgotPasswordViewModel.resendResetLink()
    XCTAssertEqual(authManager.resetEmailCallCount, 2)
    XCTAssertFalse(forgotPasswordViewModel.canResendEmail)

    // Second immediate resend should be blocked
    await forgotPasswordViewModel.resendResetLink()
    XCTAssertEqual(authManager.resetEmailCallCount, 2)
  }

  // MARK: - Error Recovery

  func testRecoveryFromResetEmailError() async {
    authManager.shouldThrowResetEmailError = true
    authManager.mockErrorToThrow = .networkError("Network error")

    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertFalse(forgotPasswordViewModel.emailSent)
    XCTAssertNotNil(forgotPasswordViewModel.errorMessage)

    // User dismisses error
    forgotPasswordViewModel.dismissError()
    XCTAssertNil(forgotPasswordViewModel.errorMessage)

    // Network recovers
    authManager.shouldThrowResetEmailError = false

    // User retries
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)
    XCTAssertNil(forgotPasswordViewModel.errorMessage)
  }

  func testRecoveryFromPasswordUpdateError() async {
    authManager.shouldThrowUpdatePasswordError = true
    authManager.mockErrorToThrow = .invalidResetToken

    resetPasswordViewModel.newPassword = "StrongPass1"
    resetPasswordViewModel.confirmPassword = "StrongPass1"

    await resetPasswordViewModel.resetPassword()

    if case .error(let message) = resetPasswordViewModel.state {
      XCTAssertFalse(message.isEmpty)
    } else {
      XCTFail("Expected error state")
    }

    // User returns to form
    resetPasswordViewModel.returnToForm()
    XCTAssertEqual(resetPasswordViewModel.state, .form)

    // Token is refreshed/valid now
    authManager.shouldThrowUpdatePasswordError = false

    // User retries
    await resetPasswordViewModel.resetPassword()

    XCTAssertEqual(resetPasswordViewModel.state, .success)
  }

  // MARK: - Form State Management

  func testResetFormClearsAllState() async {
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    XCTAssertTrue(forgotPasswordViewModel.emailSent)
    XCTAssertEqual(forgotPasswordViewModel.submittedEmail, "user@example.com")

    forgotPasswordViewModel.resetForm()

    XCTAssertFalse(forgotPasswordViewModel.emailSent)
    XCTAssertEqual(forgotPasswordViewModel.submittedEmail, "")
    XCTAssertNil(forgotPasswordViewModel.errorMessage)
    XCTAssertTrue(forgotPasswordViewModel.fieldErrors.isEmpty)
  }

  func testReturnToFormClearsAllErrorState() async {
    authManager.shouldThrowUpdatePasswordError = true
    authManager.mockErrorToThrow = .networkError("Error")

    resetPasswordViewModel.newPassword = "StrongPass1"
    resetPasswordViewModel.confirmPassword = "StrongPass1"

    await resetPasswordViewModel.resetPassword()

    if case .error = resetPasswordViewModel.state {
      // Expected
    } else {
      XCTFail("Expected error state")
    }

    resetPasswordViewModel.returnToForm()

    XCTAssertEqual(resetPasswordViewModel.state, .form)
    XCTAssertTrue(resetPasswordViewModel.fieldErrors.isEmpty)
  }

  // MARK: - Concurrent Operations

  func testConcurrentPasswordResetAttempts() async {
    resetPasswordViewModel.newPassword = "StrongPass1"
    resetPasswordViewModel.confirmPassword = "StrongPass1"

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<3 {
        group.addTask {
          await self.resetPasswordViewModel.resetPassword()
        }
      }
    }

    XCTAssertEqual(resetPasswordViewModel.state, .success)
    XCTAssertGreaterThan(authManager.updatePasswordCallCount, 0)
  }

  func testConcurrentResendAttempts() async {
    forgotPasswordViewModel.email = "user@example.com"
    await forgotPasswordViewModel.sendResetLink()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<3 {
        group.addTask {
          await self.forgotPasswordViewModel.resendResetLink()
        }
      }
    }

    // Only one should succeed due to cooldown
    XCTAssertGreaterThanOrEqual(authManager.resetEmailCallCount, 2)
  }
}
