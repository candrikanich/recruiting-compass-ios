import XCTest

/// Multi-family parent: `parent-multi@test.com` belongs to two player families (seed: web
/// `tests/e2e/seed/multi-family-parent.ts`, web#1256). Runs against the local Supabase stack only
/// (`E2ETestEnvironment` never reads the ambient prod URL, #354); set `E2E_SUPABASE_URL` when the stack's
/// gateway is not on 127.0.0.1:54321 (`TEST_RUNNER_E2E_SUPABASE_URL` through `xcodebuild`).
final class FamilySwitcherE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var tabs: MainTabNavigator!

  /// The seeded schools that tell the two families apart. The app remembers the selected family per user across
  /// launches (the simulator keeps its defaults between runs), so the test starts on whichever family is showing
  /// and switches to the other one.
  private let familyASchool = "Family A School"
  private let familyBSchool = "Family B School"

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
    tabs = MainTabNavigator(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    tabs = nil
  }

  @MainActor
  func testSwitchingFamilyShowsTheNewFamilyAndDropsTheOldFamilysViewState() throws {
    try signInAsMultiFamilyParent()
    let switcher = app.buttons["family_switcher"]
    attachDiagnostics(named: "dashboard-after-login")
    XCTAssertTrue(
      switcher.waitForExistence(timeout: 20),
      "A parent in two families must see the family switcher on the Dashboard"
    )
    let initialValue = selectedFamilyLabel()
    XCTAssertFalse(initialValue.isEmpty, "The switcher should show the selected family")

    XCTAssertTrue(tabs.goTo(.schools))
    let startsOnA = schoolRow(containing: familyASchool).waitForExistence(timeout: 20)
    let startsOnB = schoolRow(containing: familyBSchool).exists
    if startsOnA == startsOnB { attachDiagnostics(named: "schools-neither-or-both-families") }
    XCTAssertTrue(startsOnA != startsOnB, "Exactly one family's seeded schools should be listed")
    let oldFamilySchool = startsOnA ? familyASchool : familyBSchool
    let newFamilySchool = startsOnA ? familyBSchool : familyASchool

    // Leave a pushed screen open on the More tab: view state that must not survive a family switch.
    XCTAssertTrue(tabs.goToMoreSection("Events"), "Events should open from the More tab")

    XCTAssertTrue(tabs.goTo(.dashboard))
    XCTAssertTrue(switcher.waitForExistence(timeout: 10))
    switcher.tap()
    // The picker's menu items are plain buttons (not under `app.menus`). Without a local web API the labels are the
    // numbered fallbacks "Family 1" / "Family 2"; the switcher's own label is "Family, Family N", so it can't match.
    let option = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@ AND label != %@", "Family [0-9]+", initialValue)
    ).firstMatch
    attachDiagnostics(named: "switcher-menu")
    XCTAssertTrue(option.waitForExistence(timeout: 5), "The second family should be listed in the switcher")
    option.tap()

    XCTAssertTrue(app.buttons["family_switcher"].waitForExistence(timeout: 20))
    XCTAssertNotEqual(selectedFamilyLabel(), initialValue, "The selected family changes")

    XCTAssertTrue(tabs.goTo(.schools))
    XCTAssertTrue(
      schoolRow(containing: newFamilySchool).waitForExistence(timeout: 20),
      "The new family's school should be listed after the switch"
    )
    XCTAssertFalse(schoolRow(containing: oldFamilySchool).exists, "The old family's schools must be gone")

    XCTAssertTrue(tabs.goTo(.more))
    XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))
    XCTAssertFalse(
      app.navigationBars["Events"].exists,
      "The old family's pushed Events screen must be gone after the switch"
    )
  }

  /// The picker button's own `value` is empty; the selected family is its inner label.
  private func selectedFamilyLabel() -> String {
    app.buttons["family_switcher"].staticTexts.firstMatch.label
  }

  private func signInAsMultiFamilyParent() throws {
    app.loginAsParent(email: "parent-multi@test.com", password: "TestPass123!")
    guard app.waitForLogin(timeout: 20) else {
      attachDiagnostics(named: "login-failed")
      throw XCTSkip("Login failed - local Supabase stack with the multi-family seed is not running")
    }
  }

  private func schoolRow(containing name: String) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", name)
    ).firstMatch
  }

  private func attachDiagnostics(named name: String) {
    add(app.takeScreenshot(name: name))
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "\(name)-hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
  }
}
