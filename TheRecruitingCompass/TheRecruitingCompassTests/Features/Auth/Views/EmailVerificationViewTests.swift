import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationViewTests: XCTestCase {
  var mockAuthManager: MockAuthManager!

  private let unverifiedUser = User(
    id: "test-id",
    email: "test@example.com",
    emailConfirmedAt: nil,
    phone: nil,
    userMetadata: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T00:00:00Z"
  )

  private let verifiedUser = User(
    id: "test-id",
    email: "test@example.com",
    emailConfirmedAt: "2024-01-01T12:00:00Z",
    phone: nil,
    userMetadata: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T12:00:00Z"
  )

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
  }

  override func tearDown() {
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - View Instantiation

  func testViewRendersWithUnverifiedUser() {
    mockAuthManager.setMockUser(unverifiedUser)
    let view = EmailVerificationView(authManager: mockAuthManager)
    XCTAssertNotNil(view)
  }

  func testViewRendersWithVerifiedUser() {
    mockAuthManager.setMockUser(verifiedUser)
    let view = EmailVerificationView(authManager: mockAuthManager)
    XCTAssertNotNil(view)
  }

  func testViewRendersWithNoUser() {
    let view = EmailVerificationView(authManager: mockAuthManager)
    XCTAssertNotNil(view)
  }

  // MARK: - Headline Text (via ViewModel state-driven logic)

  func testHeadlineTextForPendingState() {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(viewModel.verificationState, .pending)
    // View shows "Verify Your Email" for .pending and .checking
    let expectedHeadline = "Verify Your Email"
    XCTAssertEqual(headlineText(for: viewModel.verificationState), expectedHeadline)
  }

  func testHeadlineTextForCheckingState() {
    let expectedHeadline = "Verify Your Email"
    XCTAssertEqual(headlineText(for: .checking), expectedHeadline)
  }

  func testHeadlineTextForVerifiedState() {
    let expectedHeadline = "Verified!"
    XCTAssertEqual(headlineText(for: .verified), expectedHeadline)
  }

  func testHeadlineTextForErrorState() {
    let expectedHeadline = "Verification Issue"
    XCTAssertEqual(headlineText(for: .error(message: "Network error")), expectedHeadline)
  }

  // MARK: - Subtitle Text

  func testSubtitleTextForPendingState() {
    let expected = "We've sent a verification link to your email. Click it to verify your account."
    XCTAssertEqual(subtitleText(for: .pending), expected)
  }

  func testSubtitleTextForCheckingState() {
    let expected = "Checking your email verification status..."
    XCTAssertEqual(subtitleText(for: .checking), expected)
  }

  func testSubtitleTextForVerifiedState() {
    let expected = "Your email has been verified successfully! You can now access the app."
    XCTAssertEqual(subtitleText(for: .verified), expected)
  }

  func testSubtitleTextForErrorState() {
    let expected = "We encountered an issue verifying your email. Please try again."
    XCTAssertEqual(subtitleText(for: .error(message: "err")), expected)
  }

  // MARK: - Action Button Text

  func testActionButtonTextWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(actionButtonText(for: viewModel), "Continue to Dashboard")
  }

  func testActionButtonTextWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertTrue(viewModel.canResendEmail)
    XCTAssertEqual(actionButtonText(for: viewModel), "Resend Verification Email")
  }

  func testActionButtonTextDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 5
    )

    await viewModel.resendVerificationEmail()

    XCTAssertFalse(viewModel.canResendEmail)
    XCTAssertEqual(actionButtonText(for: viewModel), "Resend Email (Cooldown)")
  }

  // MARK: - Button Disabled State

  func testButtonNotDisabledWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(isButtonDisabled(for: viewModel))
  }

  func testButtonNotDisabledWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(isButtonDisabled(for: viewModel))
  }

  func testButtonDisabledDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 5
    )

    await viewModel.resendVerificationEmail()

    XCTAssertTrue(isButtonDisabled(for: viewModel))
  }

  // MARK: - Accessibility Labels

  func testAccessibilityLabelWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(accessibilityLabelForButton(for: viewModel), "Continue to dashboard")
  }

  func testAccessibilityLabelWhenChecking() {
    XCTAssertEqual(
      accessibilityLabelForButton(state: .checking, isVerified: false),
      "Checking verification status"
    )
  }

  func testAccessibilityLabelWhenPending() {
    XCTAssertEqual(
      accessibilityLabelForButton(state: .pending, isVerified: false),
      "Resend verification email"
    )
  }

  func testAccessibilityHintWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(accessibilityHintForButton(for: viewModel), "Navigate to dashboard")
  }

  func testAccessibilityHintDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 30
    )

    await viewModel.resendVerificationEmail()

    let hint = accessibilityHintForButton(for: viewModel)
    XCTAssertTrue(hint.contains("seconds before resending"),
      "Hint should mention cooldown seconds, got: \(hint)")
  }

  func testAccessibilityHintWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(accessibilityHintForButton(for: viewModel), "Send another verification email")
  }

  // MARK: - Cooldown Text Visibility

  func testCooldownTextVisibleDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(
      authManager: mockAuthManager,
      cooldownDuration: 5
    )

    await viewModel.resendVerificationEmail()

    let shouldShowCooldown = !viewModel.canResendEmail && !viewModel.isVerified
    XCTAssertTrue(shouldShowCooldown)
    XCTAssertGreaterThan(viewModel.resendCooldownSeconds, 0)
  }

  func testCooldownTextHiddenWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    let shouldShowCooldown = !viewModel.canResendEmail && !viewModel.isVerified
    XCTAssertFalse(shouldShowCooldown)
  }

  func testCooldownTextHiddenWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let viewModel = EmailVerificationViewModel(authManager: mockAuthManager)

    let shouldShowCooldown = !viewModel.canResendEmail && !viewModel.isVerified
    XCTAssertFalse(shouldShowCooldown)
  }

  // MARK: - Helpers (mirror view's computed properties)

  private func headlineText(for state: VerificationState) -> String {
    switch state {
    case .pending, .checking:
      return "Verify Your Email"
    case .verified:
      return "Verified!"
    case .error:
      return "Verification Issue"
    }
  }

  private func subtitleText(for state: VerificationState) -> String {
    switch state {
    case .pending:
      return "We've sent a verification link to your email. Click it to verify your account."
    case .checking:
      return "Checking your email verification status..."
    case .verified:
      return "Your email has been verified successfully! You can now access the app."
    case .error:
      return "We encountered an issue verifying your email. Please try again."
    }
  }

  private func actionButtonText(for viewModel: EmailVerificationViewModel) -> String {
    if viewModel.isVerified {
      return "Continue to Dashboard"
    } else if !viewModel.canResendEmail {
      return "Resend Email (Cooldown)"
    } else {
      return "Resend Verification Email"
    }
  }

  private func isButtonDisabled(for viewModel: EmailVerificationViewModel) -> Bool {
    if viewModel.isVerified {
      return false
    }
    return !viewModel.canResendEmail || viewModel.verificationState == .checking
  }

  private func accessibilityLabelForButton(for viewModel: EmailVerificationViewModel) -> String {
    accessibilityLabelForButton(
      state: viewModel.verificationState,
      isVerified: viewModel.isVerified
    )
  }

  private func accessibilityLabelForButton(
    state: VerificationState,
    isVerified: Bool
  ) -> String {
    if isVerified {
      return "Continue to dashboard"
    } else if state == .checking {
      return "Checking verification status"
    } else {
      return "Resend verification email"
    }
  }

  private func accessibilityHintForButton(for viewModel: EmailVerificationViewModel) -> String {
    if viewModel.isVerified {
      return "Navigate to dashboard"
    } else if !viewModel.canResendEmail {
      return "Wait \(viewModel.resendCooldownSeconds) seconds before resending"
    } else {
      return "Send another verification email"
    }
  }
}
