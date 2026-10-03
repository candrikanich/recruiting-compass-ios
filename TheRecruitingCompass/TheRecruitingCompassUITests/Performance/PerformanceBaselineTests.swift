import XCTest

/// Performance baseline against the LOCAL stack seeded by `scripts/seed-demo-screenshots.ts` and
/// `scripts/seed-perf-large.ts`. Not part of the regular E2E run: skipped unless `PERF_BASELINE=1`.
/// Simulator numbers compare commit to commit; device budgets live in `docs/performance/baseline.md`.
final class PerformanceBaselineTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["PERF_BASELINE"] == "1",
      "Set PERF_BASELINE=1 to record the performance baseline"
    )
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchArguments.append("--local-captcha-bypass")
    // Timeline and Action Items are served by the web API; run it locally (`nuxi dev` on :3003).
    app.launchEnvironment["API_BASE_URL"] =
      ProcessInfo.processInfo.environment["PERF_API_BASE_URL"] ?? "http://localhost:3003"
  }

  /// `--uitesting` clears the session, so this is process start to the first frame of the landing screen.
  @MainActor
  func testColdLaunch() {
    measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
  }

  @MainActor
  func testDashboardScroll() {
    launchSignedIn()
    measureScroll()
  }

  @MainActor
  func testSchoolsListScroll() {
    launchSignedIn()
    open(.schools)
    measureScroll()
  }

  @MainActor
  func testTimelineScroll() {
    launchSignedIn()
    open(.timeline)
    measureScroll()
  }

  @MainActor
  func testNotificationsScroll() {
    launchSignedIn()
    open(.notifications)
    measureScroll()
  }

  /// Walks the hot screens once, printing a `PERF_MARK <screen> <epoch seconds>` line as each one opens, so
  /// the API gateway's access log can be split into per-screen request counts.
  @MainActor
  func testNetworkWalk() {
    mark("launch")
    launchSignedIn()
    settle()
    for screen in [Screen.schools, .timeline, .notifications] {
      mark(screen.rawValue)
      open(screen)
      settle()
    }
    mark("end")
  }

  // MARK: - Helpers

  private enum Screen: String {
    case schools
    case timeline
    case notifications
  }

  private func launchSignedIn() {
    app.launch()
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
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "Never reached the dashboard")
    let notNow = app.buttons["Not Now"]
    if notNow.waitForExistence(timeout: 5) { notNow.tap() }
  }

  private func open(_ screen: Screen) {
    let navigator = MainTabNavigator(app: app)
    switch screen {
    case .schools:
      XCTAssertTrue(navigator.goTo(.schools), "Schools tab not reached")
    case .timeline:
      openMoreRow("Recruiting Timeline", navigator: navigator)
    case .notifications:
      openMoreRow("Notifications", navigator: navigator)
    }
  }

  /// Destination nav-bar titles differ from row titles, so success means leaving the More screen.
  private func openMoreRow(_ rowTitle: String, navigator: MainTabNavigator) {
    XCTAssertTrue(navigator.goToMore(), "More tab not reached")
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", rowTitle)).firstMatch
    // The More list is lazy: rows below the fold (Notifications) are not in the hierarchy until scrolled to.
    for _ in 0..<4 where !(row.waitForExistence(timeout: 3) && row.isHittable) {
      app.swipeUp()
    }
    XCTAssertTrue(row.exists, "More row \(rowTitle) not found")
    row.tap()
    XCTAssertTrue(app.navigationBars["More"].waitForNonExistence(timeout: 10), "Still on More after \(rowTitle)")
  }

  /// Measures the swipe up only; the swipe down resets the position for the next iteration.
  private func measureScroll() {
    settle()
    let options = XCTMeasureOptions()
    options.invocationOptions = [.manuallyStop]
    let metrics: [XCTMetric] = [
      XCTOSSignpostMetric.scrollingAndDecelerationMetric,
      XCTMemoryMetric(application: app)
    ]
    measure(metrics: metrics, options: options) {
      app.swipeUp(velocity: .fast)
      stopMeasuring()
      app.swipeDown(velocity: .fast)
    }
  }

  /// Lets a screen finish its fetches so a measurement or the next mark is not polluted by loading.
  private func settle() {
    sleep(6)
  }

  private func mark(_ name: String) {
    print("PERF_MARK \(name) \(Date().timeIntervalSince1970)")
  }
}
