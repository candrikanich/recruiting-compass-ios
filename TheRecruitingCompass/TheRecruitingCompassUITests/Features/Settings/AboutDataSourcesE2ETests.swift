import XCTest

/// The About screen must carry the data-source credits that Wikipedia's CC BY-SA 4.0
/// license requires (credit, license link, notice of changes). Mirrors web
/// `tests/unit/pages/about-attribution.spec.ts`.
final class AboutDataSourcesE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var navigator: MainTabNavigator!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
    navigator = MainTabNavigator(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    navigator = nil
  }

  @MainActor
  private func openAbout() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    guard navigator.goToSettings() else {
      throw XCTSkip("Settings screen not reachable - navigation may not be wired")
    }
    let aboutRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "About & Feedback")).firstMatch
    var attempts = 0
    while !aboutRow.isHittable && attempts < 6 {
      app.swipeUp()
      attempts += 1
    }
    aboutRow.tap()
    XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 10), "About screen should open")
  }

  @MainActor
  func testAbout_dataSources_creditsWikipediaLicenseAndProviders() throws {
    try openAbout()

    let version = app.descendants(matching: .any)["aboutAppVersion"]
    var attempts = 0
    while !version.isHittable && attempts < 6 {
      app.swipeUp()
      attempts += 1
    }

    let rows = app.descendants(matching: .any).matching(identifier: "aboutDataSources")
    XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "Data Sources section should exist")
    add(app.takeScreenshot(name: "about-data-sources"))

    let credits = rows.allElementsBoundByIndex.map(\.label).joined(separator: " ")
    for required in ["Wikipedia", "CC BY-SA 4.0", "adapted", "ncaa-team-colors", "College Scorecard", "Logo.dev"] {
      XCTAssertTrue(credits.contains(required), "Data Sources credits should mention '\(required)': \(credits)")
    }

    let lastCredit = rows.element(boundBy: rows.count - 1)
    XCTAssertLessThan(lastCredit.frame.maxY, version.frame.minY, "Version should stay below the credits")
  }
}
