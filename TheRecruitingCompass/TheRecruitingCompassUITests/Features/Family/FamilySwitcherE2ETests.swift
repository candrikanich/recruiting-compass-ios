import XCTest

/// Multi-family parent: `parent-multi@test.com` belongs to two player families (seed: web
/// `tests/e2e/seed/multi-family-parent.ts`, web#1256). Runs against the local Supabase stack only
/// (`E2ETestEnvironment` never reads the ambient prod URL, #354).
final class FamilySwitcherE2ETests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  @MainActor
  func testSwitchingFamilyChangesTheSelection() throws {
    let switcher = try openDashboardAsMultiFamilyParent()
    let initialValue = try XCTUnwrap(switcher.value as? String)

    switcher.tap()
    let option = app.menus.buttons.matching(NSPredicate(format: "label != %@", initialValue)).firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5), "The second family should be listed in the switcher")
    option.tap()

    let switchedSwitcher = app.buttons["family_switcher"]
    XCTAssertTrue(switchedSwitcher.waitForExistence(timeout: 10))
    XCTAssertNotEqual(switchedSwitcher.value as? String, initialValue, "The selected family should change")
  }

  private func openDashboardAsMultiFamilyParent() throws -> XCUIElement {
    app.loginAsParent(email: "parent-multi@test.com", password: "TestPass123!")
    guard app.waitForLogin(timeout: 15) else {
      throw XCTSkip("Login failed - local Supabase stack with the multi-family seed is not running")
    }
    let switcher = app.buttons["family_switcher"]
    guard switcher.waitForExistence(timeout: 15) else {
      throw XCTSkip("parent-multi@test.com is not in two families - seed missing")
    }
    return switcher
  }
}
