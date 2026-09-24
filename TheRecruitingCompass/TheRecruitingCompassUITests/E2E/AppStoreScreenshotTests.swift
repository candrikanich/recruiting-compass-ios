import XCTest

/// Captures App Store screenshots against the LOCAL Supabase stack seeded by
/// `scripts/seed-demo-screenshots.ts`. Not part of the regular E2E run: it is
/// skipped unless `CAPTURE_SCREENSHOTS=1` is set in the test environment.
final class AppStoreScreenshotTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOTS"] == "1",
      "Set CAPTURE_SCREENSHOTS=1 to capture App Store screenshots"
    )
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    // Timeline and Action Items are served by the web API; run it locally (`nuxi dev` on :3003).
    app.launchEnvironment["API_BASE_URL"] =
      ProcessInfo.processInfo.environment["SCREENSHOT_API_BASE_URL"] ?? "http://localhost:3003"
    app.launch()
  }

  @MainActor
  func testCaptureIPadScreens() throws {
    continueAfterFailure = true
    signIn()
    dismissNoise()
    capture("01-dashboard")

    openSection("Schools")
    capture("02-schools")
    openRow(containing: "Stanford")
    capture("03-school-detail")

    openSection("Coaches")
    capture("04-coaches")
    openRow(containing: "Hale")
    capture("05-coach-detail")

    openSection("Interactions")
    capture("06-interactions")
    openSection("Timeline")
    capture("07-timeline")
    let guidance = app.buttons["Guidance"]
    if guidance.waitForExistence(timeout: 3) {
      guidance.tap()
      sleep(1)
      for section in ["Common Worries", "What NOT to Stress About"] {
        let header = app.staticTexts[section]
        if header.exists { header.tap() }
      }
      capture("07b-timeline-guidance")
    }
    openSection("Performance")
    capture("08-performance")
    openSection("Offers")
    capture("09-offers")
    openSection("Events")
    capture("10-events")
    openSection("Analytics")
    capture("11-analytics")
  }

  // MARK: - Helpers

  private func signIn() {
    let signInLanding = app.buttons["Sign in to your account"]
    XCTAssertTrue(signInLanding.waitForExistence(timeout: 15))
    signInLanding.tap()

    let email = app.textFields.firstMatch
    XCTAssertTrue(email.waitForExistence(timeout: 10))
    email.tap()
    email.typeText("jordan@example.com")

    let password = app.secureTextFields.firstMatch
    password.tap()
    password.typeText("DemoPassword1")

    app.buttons["Sign in to account"].tap()
    XCTAssertTrue(
      app.buttons["Show Sidebar"].waitForExistence(timeout: 30),
      "Never reached the dashboard — sign-in failed"
    )
    sleep(5)
  }

  /// Clears the system password prompt plus dismissible dashboard chrome that would clutter store shots.
  private func dismissNoise() {
    let notNow = app.buttons["Not Now"]
    if notNow.waitForExistence(timeout: 5) { notNow.tap() }
    let dismiss = app.buttons["Dismiss"]
    if dismiss.waitForExistence(timeout: 5) { dismiss.tap() }
    sleep(1)
  }

  /// Opens a sidebar destination, revealing the sidebar first when it is collapsed. The dashboard has
  /// same-named stat tiles, so the sidebar entry is the match sitting in the leading column.
  private func openSection(_ title: String) {
    func sidebarItem() -> XCUIElement? {
      app.staticTexts.matching(NSPredicate(format: "label == %@", title))
        .allElementsBoundByIndex.first { $0.frame.midX < 330 && $0.frame.midY > 100 }
    }
    if sidebarItem() == nil { app.buttons["Show Sidebar"].tap(); sleep(1) }
    guard let item = sidebarItem() else {
      XCTFail("Sidebar item \(title) not found")
      return
    }
    item.tap()
    sleep(3)
  }

  private func openRow(containing text: String) {
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    let row = app.descendants(matching: .any).matching(predicate).firstMatch
    guard row.waitForExistence(timeout: 8) else {
      XCTFail("Row containing \(text) not found")
      return
    }
    row.tap()
    sleep(3)
  }

  private func capture(_ name: String) {
    sleep(2)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func dumpHierarchy(named name: String) {
    let attachment = XCTAttachment(string: app.debugDescription)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
