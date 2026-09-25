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
    app.launchArguments.append("--local-captcha-bypass")
    // Timeline and Action Items are served by the web API; run it locally (`nuxi dev` on :3003).
    app.launchEnvironment["API_BASE_URL"] =
      ProcessInfo.processInfo.environment["SCREENSHOT_API_BASE_URL"] ?? "http://localhost:3003"
    app.launch()
  }

  @MainActor
  func testCaptureScreens() throws {
    // continueAfterFailure stays false: a failed sign-in or navigation must stop the run rather than
    // save the previous screen under the next destination's name.
    signIn()
    dismissNoise()
    capture("01-dashboard")

    openSection("Schools")
    capture("02-schools")
    openRow(containing: "Vanderbilt")
    sleep(10) // Apple Maps tiles load over the network; an unloaded map is a blank grid.
    capture("03-school-detail")
    scrollPageUp()
    capture("03b-school-data")

    openSection("Coaches")
    capture("04-coaches")
    openRow(containing: "Hale")
    capture("05-coach-detail")

    openSection("Interactions")
    capture("06-interactions")
    openSection("Timeline")
    capture("07-timeline")
    openSection("Performance")
    capture("08-performance")
    openSection("Events")
    capture("09-events")
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
    let landmark = isPad ? app.buttons["Show Sidebar"] : app.tabBars.firstMatch
    XCTAssertTrue(landmark.waitForExistence(timeout: 30), "Never reached the dashboard — sign-in failed")
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

  private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

  /// iPad: sidebar destination. iPhone: tab-bar tab, or a row in the More menu for the overflow features.
  private func openSection(_ title: String) {
    guard isPad else { openPhoneSection(title); return }
    openSidebarSection(title)
  }

  private func openPhoneSection(_ title: String) {
    // Pushed detail screens hide the tab bar; pop back to a root screen first.
    for _ in 0..<3 where !app.tabBars.firstMatch.exists {
      app.navigationBars.buttons.firstMatch.tap()
      sleep(1)
    }
    let navigator = MainTabNavigator(app: app)
    let tabs = ["Dashboard", "Schools", "Coaches", "Interactions"]
    if tabs.contains(title) {
      let tab = MainTabNavigator.Tab(rawValue: title)!
      XCTAssertTrue(navigator.goTo(tab), "Tab \(title) not reached")
    } else {
      openMoreRow(title == "Timeline" ? "Recruiting Timeline" : title, navigator: navigator)
    }
    sleep(3)
  }

  /// Opens a More-menu row. Destination nav-bar titles differ from row titles ("Performance Metrics"),
  /// so success means leaving the More screen, not matching a title.
  private func openMoreRow(_ rowTitle: String, navigator: MainTabNavigator) {
    XCTAssertTrue(navigator.goToMore(), "More tab not reached")
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", rowTitle)).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "More row \(rowTitle) not found")
    row.tap()
    XCTAssertTrue(app.navigationBars["More"].waitForNonExistence(timeout: 10), "Still on More after tapping \(rowTitle)")
  }

  /// Reveals the sidebar first when it is collapsed. The dashboard has same-named stat tiles, so the
  /// sidebar entry is the match sitting in the leading column.
  private func openSidebarSection(_ title: String) {
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

  /// Drags from the bottom third, where no map sits, so the page scrolls instead of the map panning.
  private func scrollPageUp() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
    start.press(forDuration: 0.1, thenDragTo: end)
    sleep(1)
    start.press(forDuration: 0.1, thenDragTo: end)
    sleep(1)
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
