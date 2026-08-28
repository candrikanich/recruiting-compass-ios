import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AsyncButtonAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeButton(
    title: String = "Sign In",
    loadingTitle: String? = "Signing in...",
    isLoading: Bool = false,
    isDisabled: Bool = false,
    accessibilityLabelOverride: String? = "Sign in to account",
    loadingAccessibilityLabel: String? = "Signing in",
    accessibilityHint: String? = "Sign in with your email and password",
    loadingAccessibilityHint: String? = "Please wait while we verify your credentials"
  ) -> AsyncButton {
    AsyncButton(
      title: title,
      loadingTitle: loadingTitle,
      isLoading: isLoading,
      isDisabled: isDisabled,
      accessibilityLabelOverride: accessibilityLabelOverride,
      loadingAccessibilityLabel: loadingAccessibilityLabel,
      accessibilityHint: accessibilityHint,
      loadingAccessibilityHint: loadingAccessibilityHint,
      action: {}
    )
  }

  func testIdle_UsesOverrideLabelNotTitle() {
    let button = makeButton()
    XCTAssertEqual(button.accessibilityLabel, "Sign in to account")
    XCTAssertEqual(button.displayTitle, "Sign In")
  }

  func testLoading_UsesLoadingLabelAndTitle() {
    let button = makeButton(isLoading: true)
    XCTAssertEqual(button.accessibilityLabel, "Signing in")
    XCTAssertEqual(button.displayTitle, "Signing in...")
  }

  func testLoadingWithoutLoadingTitle_KeepsIdleTitle() {
    let button = makeButton(loadingTitle: nil, isLoading: true)
    XCTAssertEqual(button.displayTitle, "Sign In")
  }

  func testIdleWithoutOverride_FallsBackToTitle() {
    let button = makeButton(accessibilityLabelOverride: nil)
    XCTAssertEqual(button.accessibilityLabel, "Sign In")
  }

  func testLoadingHint_AnnouncesWait() {
    let button = makeButton(isLoading: true)
    XCTAssertEqual(
      button.accessibilityHintText,
      "Please wait while we verify your credentials"
    )
  }

  func testIdleHint_DescribesAction() {
    let button = makeButton()
    XCTAssertEqual(button.accessibilityHintText, "Sign in with your email and password")
  }

  func testLoading_DisablesInteraction() {
    let button = makeButton(isLoading: true)
    XCTAssertTrue(button.isInteractionDisabled)
  }

  func testValidationDisabled_DisablesInteraction() {
    let button = makeButton(isDisabled: true)
    XCTAssertTrue(button.isInteractionDisabled)
  }

  func testIdleEnabled_AllowsInteraction() {
    let button = makeButton()
    XCTAssertFalse(button.isInteractionDisabled)
  }

  func testLoadingDefaultHint_WhenOverrideMissing() {
    let button = makeButton(isLoading: true, loadingAccessibilityHint: nil)
    XCTAssertEqual(button.accessibilityHintText, "Please wait")
  }
}
