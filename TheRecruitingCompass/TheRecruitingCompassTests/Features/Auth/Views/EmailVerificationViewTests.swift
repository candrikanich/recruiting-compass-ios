import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class EmailVerificationViewTests: XCTestCase {
  nonisolated deinit {}
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

  // MARK: - Headline Text

  func testHeadlineTextForPendingState() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.headlineText, "Verify Your Email")
  }

  func testHeadlineTextForVerifiedState() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.headlineText, "Verified!")
  }

  func testHeadlineTextForErrorState() async {
    mockAuthManager.setMockUser(unverifiedUser)
    mockAuthManager.shouldThrowRefreshError = true
    mockAuthManager.mockErrorToThrow = .networkError("fail")
    let vm = EmailVerificationViewModel(
      authManager: mockAuthManager,
      initialPollingInterval: 0.02,
      maxPollingInterval: 0.04,
      maxConsecutiveErrors: 0
    )

    vm.startPolling()
    try? await Task.sleep(nanoseconds: 300_000_000)
    vm.stopPolling()

    XCTAssertEqual(vm.headlineText, "Verification Issue")
  }

  // MARK: - Subtitle Text

  func testSubtitleTextForPendingState() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.subtitleText, "We've sent a verification link to your email. Click it to verify your account.")
  }

  func testSubtitleTextForVerifiedState() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.subtitleText, "Your email has been verified successfully! You can now access the app.")
  }

  // MARK: - Action Button Text

  func testActionButtonTextWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.actionButtonText, "Continue to Dashboard")
  }

  func testActionButtonTextWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.actionButtonText, "Resend Verification Email")
  }

  func testActionButtonTextDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager, cooldownDuration: 5)

    await vm.resendVerificationEmail()

    XCTAssertEqual(vm.actionButtonText, "Resend Email (Cooldown)")
  }

  // MARK: - Button Disabled State

  func testButtonNotDisabledWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(vm.isButtonDisabled)
  }

  func testButtonNotDisabledWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(vm.isButtonDisabled)
  }

  func testButtonDisabledDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager, cooldownDuration: 5)

    await vm.resendVerificationEmail()

    XCTAssertTrue(vm.isButtonDisabled)
  }

  // MARK: - Accessibility Labels

  func testAccessibilityLabelWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.accessibilityLabelForButton, "Continue to dashboard")
  }

  func testAccessibilityLabelWhenPending() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.accessibilityLabelForButton, "Resend verification email")
  }

  func testAccessibilityHintWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.accessibilityHintForButton, "Navigate to dashboard")
  }

  func testAccessibilityHintDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager, cooldownDuration: 30)

    await vm.resendVerificationEmail()

    XCTAssertTrue(vm.accessibilityHintForButton.contains("seconds before resending"))
  }

  func testAccessibilityHintWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertEqual(vm.accessibilityHintForButton, "Send another verification email")
  }

  // MARK: - Cooldown Text Visibility

  func testShouldShowCooldownTextDuringCooldown() async {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager, cooldownDuration: 5)

    await vm.resendVerificationEmail()

    XCTAssertTrue(vm.shouldShowCooldownText)
  }

  func testShouldNotShowCooldownTextWhenVerified() {
    mockAuthManager.setMockUser(verifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(vm.shouldShowCooldownText)
  }

  func testShouldNotShowCooldownTextWhenCanResend() {
    mockAuthManager.setMockUser(unverifiedUser)
    let vm = EmailVerificationViewModel(authManager: mockAuthManager)

    XCTAssertFalse(vm.shouldShowCooldownText)
  }
}
