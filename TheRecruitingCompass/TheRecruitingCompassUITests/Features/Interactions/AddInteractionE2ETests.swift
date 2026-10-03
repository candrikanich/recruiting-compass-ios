import XCTest

/// Smoke-gate journeys for logging an interaction (scripts/ci/e2e-smoke-suite.txt): a parent
/// can open the form from the Interactions tab, log one against a seeded school, and back out
/// without saving. School and coach names come from scripts/seed-e2e.ts.
/// Coach sheets, interest calibration and edge cases live in the Interaction*E2ETests classes.
final class AddInteractionE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddInteractionScreenObject!

  private let seededSchool = "Duke University"

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = AddInteractionScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  @MainActor
  private func loginAndOpenLogInteraction() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    screen.navigateToAddInteractionFromDashboard()
    add(app.takeScreenshot(name: "log-interaction-form"))
  }

  /// Submit stays disabled until school and type are chosen; logging returns to the list.
  @MainActor
  func testAddInteraction_requiredFields_logsAndReturnsToList() throws {
    try loginAndOpenLogInteraction()

    screen.scrollToElement(screen.submitButton)
    XCTAssertTrue(screen.submitButton.exists, "Log Interaction submit button should be on the form")
    XCTAssertFalse(screen.submitButton.isEnabled, "Submit should be disabled on an empty form")

    screen.scrollToElement(screen.schoolPicker, up: true)
    screen.selectSchool(seededSchool)
    screen.selectInteractionType("Email")
    add(app.takeScreenshot(name: "log-interaction-required-filled"))

    screen.scrollToElement(screen.submitButton)
    XCTAssertTrue(screen.submitButton.isEnabled, "Submit should be enabled once school and type are set")
    screen.submitForm()

    // The form dismisses itself only after the interaction was saved.
    XCTAssertTrue(
      screen.waitForSubmissionToComplete(timeout: 20),
      "Log Interaction form should close after a successful save"
    )
    XCTAssertFalse(screen.errorAlert.exists, "No error alert should be shown after logging")
    XCTAssertTrue(
      screen.interactionsListNavigationBar.waitForExistence(timeout: 10),
      "Logging should return to the Interactions list"
    )
    add(app.takeScreenshot(name: "log-interaction-saved"))
  }

  /// Cancel discards the form and returns to the list.
  @MainActor
  func testAddInteraction_cancel_returnsToList() throws {
    try loginAndOpenLogInteraction()

    screen.selectSchool(seededSchool)

    XCTAssertTrue(screen.cancelButton.waitForExistence(timeout: 5), "Cancel should be in the toolbar")
    screen.tapCancel()

    XCTAssertTrue(
      screen.interactionsListNavigationBar.waitForExistence(timeout: 10),
      "Cancel should return to the Interactions list"
    )
    XCTAssertFalse(screen.navigationTitle.exists, "Log Interaction form should be dismissed")
    add(app.takeScreenshot(name: "log-interaction-cancelled"))
  }
}
