import XCTest

/// Throwaway diagnostic: logs in, opens the More tab, and probes candidate
/// selectors for the Offers row. A failing XCTAssertFalse names a selector that
/// resolves. Delete once navigateToOffers is fixed.
final class MoreNavProbeTest: XCTestCase {
  func testProbeMoreNav() throws {
    let app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    XCTAssertTrue(app.waitForLogin(timeout: 15), "login→dashboard failed")

    func probe(_ exists: Bool, _ desc: String) {
      XCTAssertFalse(exists, "PROBE_EXISTS: \(desc)")
    }

    probe(app.tabBars.buttons["More"].exists, "tabBars.buttons[More]")
    probe(app.tabBars.buttons.count > 0, "tabBars count=\(app.tabBars.buttons.count)")

    let moreTab = app.tabBars.buttons["More"]
    if moreTab.waitForExistence(timeout: 5) { moreTab.tap() }
    _ = app.navigationBars["More"].waitForExistence(timeout: 5)

    let p = NSPredicate(format: "label BEGINSWITH 'Offers'")
    probe(app.buttons.matching(p).firstMatch.exists, "buttons BEGINSWITH Offers")
    probe(app.cells.matching(p).firstMatch.exists, "cells BEGINSWITH Offers")
    probe(app.otherElements.matching(p).firstMatch.exists, "otherElements BEGINSWITH Offers")
    probe(app.staticTexts["Offers"].exists, "staticTexts[Offers]")
    probe(app.cells.count > 0, "cells count=\(app.cells.count)")
    probe(app.navigationBars["More"].exists, "navBar[More]")
  }
}
