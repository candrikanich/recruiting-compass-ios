import XCTest

/// Drives slow, camera-friendly flows for marketing screen recordings against the LOCAL Supabase
/// stack seeded by `scripts/seed-demo-screenshots.ts` + `scripts/seed-demo-marketing.ts`.
/// Skipped unless `RECORD_MARKETING_CLIPS=1` (pass `TEST_RUNNER_RECORD_MARKETING_CLIPS=1` to xcodebuild).
///
/// The simulator cannot record itself, so each clip is bracketed by `<name>.start` / `<name>.stop`
/// marker files in `MARKETING_CLIP_MARKER_DIR`; `scripts/record-marketing-clips.sh` watches that
/// directory on the host and runs `simctl io recordVideo` between the markers.
final class MarketingClipRecorderTests: XCTestCase {
  private var app: XCUIApplication!
  private var markerDir: URL!

  override func setUpWithError() throws {
    continueAfterFailure = false
    let env = ProcessInfo.processInfo.environment
    try XCTSkipUnless(env["RECORD_MARKETING_CLIPS"] == "1", "Set RECORD_MARKETING_CLIPS=1 to record marketing clips")
    let dir = try XCTUnwrap(env["MARKETING_CLIP_MARKER_DIR"], "MARKETING_CLIP_MARKER_DIR is required")
    markerDir = URL(fileURLWithPath: dir)

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchArguments.append("--local-captcha-bypass")
    app.launchEnvironment["API_BASE_URL"] = env["MARKETING_API_BASE_URL"] ?? "http://localhost:3003"
    app.launch()
  }

  @MainActor
  func testRecordClips() throws {
    signIn()
    dismissNoise()
    prewarm()

    let only = ProcessInfo.processInfo.environment["MARKETING_CLIPS"]
      .flatMap { $0.isEmpty ? nil : Set($0.split(separator: ",").map(String.init)) }
    // (name, off-camera setup, recorded flow)
    let clips: [(String, () -> Void, () -> Void)] = [
      ("clip-v1-tour", {}, recordTour),
      ("clip-coaches", {}, recordCoaches),
      ("clip-v3-calendar", scrollDashboardNearCalendar, recordCalendar),
      // Last: confirming a draft consumes it, so reseed before re-recording this one.
      ("clip-v2-forwarded-email", {}, recordForwardedEmail),
    ]
    for (name, setup, flow) in clips where only?.contains(name) ?? true {
      resetToDashboard()
      setup()
      record(name, flow)
    }
  }

  // MARK: - Clips

  /// V1: Dashboard → Schools (scroll) → Vanderbilt detail → its coaches.
  private func recordTour() {
    pause(1.5)
    tapTab("Schools")
    pause(1)
    openRow(containing: "Vanderbilt") // scrolls the list on the way down
    pause(2)
    scrollUntilVisible(app.staticTexts["Coaches"], maxSwipes: 8)
    pause(2.5)
  }

  /// Coaches list → Coach Hale → interaction log.
  private func recordCoaches() {
    tapTab("Coaches")
    pause(1.5)
    openRow(containing: "Hale")
    pause(2)
    swipe(.up, times: 2)
    pause(2.5)
  }

  /// The calendar widget sits ~3 screens down the dashboard; get close off camera so the clip is short.
  private func scrollDashboardNearCalendar() {
    let title = app.staticTexts["Recruiting Calendar"]
    for _ in 0..<15 where !(title.exists && title.frame.minY < app.frame.height * 1.4) {
      swipe(.up, times: 1)
    }
    pause(1)
  }

  /// V3: Dashboard recruiting calendar widget → Deadlines page.
  private func recordCalendar() {
    pause(1)
    scrollUntilVisible(app.staticTexts["Recruiting Calendar"], maxSwipes: 4)
    pause(1)
    swipe(.up, times: 1)
    pause(3)
    openMoreRow("Deadlines")
    pause(3)
    swipe(.up, times: 1)
    pause(2.5)
  }

  /// V2: Coach Emails → review a forwarded email → save as interaction → coach detail shows it.
  private func recordForwardedEmail() {
    openMoreRow("Coach Emails")
    pause(3)
    let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Confirm")).firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10), "No pending forwarded-email draft (reseed?)")
    confirm.tap()
    XCTAssertTrue(app.navigationBars["Review Coach Email"].waitForExistence(timeout: 10), "Review sheet did not open")
    pause(2.5)
    // The draft pre-fills the Log Interaction form; its submit button sits at the bottom.
    let save = app.buttons["Log Interaction"]
    for _ in 0..<8 where !(save.exists && save.isHittable) {
      swipe(.up, times: 1)
    }
    if !save.exists { dumpScreen("save") }
    XCTAssertTrue(save.exists, "Log Interaction button not found")
    pause(1)
    save.tap()
    XCTAssertTrue(app.navigationBars["Review Coach Email"].waitForNonExistence(timeout: 15), "Draft was not saved")
    pause(2.5)
    tapTab("Coaches")
    pause(1)
    let search = app.descendants(matching: .any)
      .matching(NSPredicate(format: "placeholderValue BEGINSWITH %@ OR label BEGINSWITH %@",
                            "Search coaches", "Search coaches"))
      .firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5), "Coach search field not found")
    search.tap()
    search.typeText("Whitaker")
    pause(1)
    openRow(containing: "Whitaker") // the first seeded draft is Coach Whitaker's
    pause(2)
    swipe(.up, times: 1)
    pause(2.5)
  }

  // MARK: - Recording markers

  private func record(_ name: String, _ flow: () -> Void) {
    touchMarker("\(name).start")
    pause(2) // recordVideo needs a moment before the first frame lands.
    flow()
    touchMarker("\(name).stop")
    pause(2)
  }

  private func touchMarker(_ fileName: String) {
    let url = markerDir.appendingPathComponent(fileName)
    XCTAssertNoThrow(try Data().write(to: url), "Cannot write marker \(url.path)")
  }

  /// Writes the screen + hierarchy next to the markers so a failed lookup is diagnosable without an xcresult.
  private func dumpScreen(_ name: String) {
    try? app.screenshot().pngRepresentation.write(to: markerDir.appendingPathComponent("debug-\(name).png"))
    try? Data(app.debugDescription.utf8).write(to: markerDir.appendingPathComponent("debug-\(name).txt"))
  }

  // MARK: - Navigation helpers

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
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30),
                  "Never reached the dashboard — sign-in failed")
    sleep(5)
  }

  /// Clears the system password prompt plus dismissible dashboard chrome.
  private func dismissNoise() {
    let notNow = app.buttons["Not Now"]
    if notNow.waitForExistence(timeout: 5) { notNow.tap() }
    let dismiss = app.buttons["Dismiss"]
    if dismiss.waitForExistence(timeout: 5) { dismiss.tap() }
    sleep(1)
  }

  /// Loads the school-detail map tiles off camera so the tour clip never shows a blank grid.
  private func prewarm() {
    tapTab("Schools")
    openRow(containing: "Vanderbilt")
    sleep(15)
    popToRoot()
  }

  private func resetToDashboard() {
    popToRoot()
    tapTab("Dashboard")
    app.tabBars.buttons["Dashboard"].tap() // re-tapping the selected tab scrolls it to the top
    sleep(2)
  }

  private func popToRoot() {
    // Some pushed screens hide the tab bar, others keep it collapsed; both have the system back button.
    for _ in 0..<4 {
      let back = app.navigationBars.buttons["BackButton"]
      if back.exists {
        back.tap()
      } else if !app.tabBars.firstMatch.exists {
        app.navigationBars.buttons.firstMatch.tap()
      } else {
        break
      }
      sleep(1)
    }
  }

  /// Scrolling collapses the tab bar to just the selected tab; scrolling back up restores the others.
  private func restoreTabBar() {
    // Collapsed, the bar shows only the selected tab's button.
    var isExpanded: Bool { app.tabBars.buttons.count > 1 }
    guard !isExpanded else { return }
    // Tapping the collapsed tab expands the bar (and scrolls its root back to the top).
    app.tabBars.buttons.firstMatch.tap()
    pause(1.2)
    for _ in 0..<8 where !isExpanded {
      swipe(.down, times: 1)
    }
    if !isExpanded { dumpScreen("tabbar-collapsed") }
  }

  private func tapTab(_ title: String) {
    popToRoot()
    restoreTabBar()
    let tab = MainTabNavigator.Tab(rawValue: title)!
    let reached = MainTabNavigator(app: app).goTo(tab)
    if !reached { dumpScreen("tab-\(title)") }
    XCTAssertTrue(reached, "Tab \(title) not reached")
    sleep(1)
  }

  private func openMoreRow(_ rowTitle: String) {
    popToRoot()
    restoreTabBar()
    let onMore = MainTabNavigator(app: app).goToMore()
    if !onMore { dumpScreen("more-\(rowTitle)") }
    XCTAssertTrue(onMore, "More tab not reached")
    pause(1)
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", rowTitle)).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "More row \(rowTitle) not found")
    if !row.isHittable { swipe(.up, times: 1) }
    row.tap()
    XCTAssertTrue(app.navigationBars["More"].waitForNonExistence(timeout: 10),
                  "Still on More after tapping \(rowTitle)")
  }

  private func openRow(containing text: String) {
    // Lists are lazy: rows below the fold don't exist until scrolled to, and the tab bar overlaps the bottom.
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    _ = row.waitForExistence(timeout: 5)
    for _ in 0..<10 where !(row.exists && row.isHittable && row.frame.maxY < app.frame.height * 0.85) {
      swipe(.up, times: 1)
    }
    if !row.exists { dumpScreen("missing-\(text)") }
    XCTAssertTrue(row.exists, "Row containing \(text) not found")
    pause(0.8)
    row.tap()
    sleep(2)
  }

  private enum Direction { case up, down }

  /// Slow drags from the lower third, clear of maps and horizontal carousels.
  private func swipe(_ direction: Direction, times: Int) {
    let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
    let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38))
    for _ in 0..<times {
      let (from, to) = direction == .up ? (low, high) : (high, low)
      from.press(forDuration: 0.05, thenDragTo: to, withVelocity: 600, thenHoldForDuration: 0.3)
      pause(0.8)
    }
  }

  private func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int) {
    let settled = { element.exists && element.isHittable && element.frame.midY < self.app.frame.height * 0.6 }
    for _ in 0..<maxSwipes where !settled() {
      swipe(.up, times: 1)
    }
  }

  private func pause(_ seconds: Double) {
    Thread.sleep(forTimeInterval: seconds)
  }
}
