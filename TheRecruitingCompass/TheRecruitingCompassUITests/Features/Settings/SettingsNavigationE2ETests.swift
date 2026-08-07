import XCTest

/// Regression coverage for the Settings navigation bug: `MoreMenuView` used a
/// homogeneous typed `NavigationStack(path: [MorePath])`, so every value-based
/// `NavigationLink` inside `SettingsView` (which pushes `SettingsDestination`,
/// not `MorePath`) was silently a no-op — every Settings row was a dead tap and
/// the player profile could not be completed from the app. The fix switched the
/// stack to a type-erased `NavigationPath`. These tests assert the rows push
/// their destinations.
final class SettingsNavigationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var navigator: MainTabNavigator!

  /// Settings rows that are value-based NavigationLinks (the ones the bug broke).
  /// Excludes the two Legal rows, which are sheet-presenting Buttons.
  private let navigationRowTitles = [
    "Family Management",
    "My Profile",
    "Home Location",
    "Player Details",
    "School Preferences",
    "Dashboard Customization",
    "Notifications",
    "Communication Templates",
    "About & Feedback"
  ]

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
  private func loginAndOpenSettings() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    guard navigator.goToMoreSection("Settings") else {
      throw XCTSkip("Settings screen not reachable - navigation may not be wired")
    }
  }

  /// Row labels carry a `"Title: description"` (and sometimes a badge) suffix, so
  /// match on prefix. Scrolls the list until the row is hittable.
  @MainActor
  private func settingsRow(_ title: String) -> XCUIElement {
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    var attempts = 0
    while !row.isHittable && attempts < 6 {
      app.swipeUp()
      attempts += 1
    }
    return row
  }

  @MainActor
  private func popToSettings() {
    let back = app.navigationBars.buttons["Settings"]
    if back.exists {
      back.tap()
    }
    XCTAssertTrue(
      app.navigationBars["Settings"].waitForExistence(timeout: 5),
      "Should return to the Settings list"
    )
  }

  /// Core of the bug report: My Profile → the profile screen must open.
  @MainActor
  func testSettings_myProfile_opensProfileScreen() throws {
    try loginAndOpenSettings()
    add(app.takeScreenshot(name: "01-settings-list"))

    settingsRow("My Profile").tap()

    XCTAssertTrue(
      app.navigationBars["My Profile"].waitForExistence(timeout: 10),
      "Tapping My Profile should push the profile screen"
    )
    add(app.takeScreenshot(name: "02-my-profile-open"))
  }

  /// Player profile completion — the flow the user could not reach.
  /// The row is titled "Player Details"; the pushed screen's nav bar is "Player Profile".
  @MainActor
  func testSettings_playerDetails_opensPlayerProfileScreen() throws {
    try loginAndOpenSettings()

    settingsRow("Player Details").tap()

    XCTAssertTrue(
      app.navigationBars["Player Profile"].waitForExistence(timeout: 10),
      "Tapping Player Details should push the player profile editor"
    )
    add(app.takeScreenshot(name: "player-profile-open"))
  }

  /// Regression guard for the typed-stack bug: every NavigationLink row must
  /// push *something* (a back button to Settings appears), not dead-tap.
  @MainActor
  func testSettings_allNavigationRows_pushDestination() throws {
    try loginAndOpenSettings()

    for title in navigationRowTitles {
      let row = settingsRow(title)
      XCTAssertTrue(row.exists, "Settings row '\(title)' should exist")
      row.tap()

      XCTAssertTrue(
        app.navigationBars.buttons["Settings"].waitForExistence(timeout: 10),
        "Tapping '\(title)' should push a destination (dead tap regression)"
      )
      popToSettings()
    }
  }
}
