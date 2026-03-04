import XCTest

final class TermsOfServiceE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SignupScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = SignupScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Terms of Service Sheet

  @MainActor
  func testOpenTermsOfServiceFromSignupAndDismiss() throws {
    screen.navigateToSignup()
    screen.selectRole(.parent)
    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 5), "Signup form should be visible")

    // Scroll down to reveal the terms link (it may be below the fold in the signup form)
    app.scrollViews.firstMatch.swipeUp()
    screen.termsOfServiceLink.waitAndTap()

    let termsContent = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Last Updated'")
    ).firstMatch
    XCTAssertTrue(termsContent.waitForExistence(timeout: 5), "Terms and Conditions screen should show content (Last Updated)")

    let backButton = app.buttons["Back"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 2), "Back button should be visible")
    backButton.tap()

    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 3), "Should return to signup form after dismissing Terms")
  }
}
