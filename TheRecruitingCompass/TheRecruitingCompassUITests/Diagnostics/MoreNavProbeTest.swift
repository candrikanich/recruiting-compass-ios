import XCTest

/// Throwaway diagnostic: logs in, opens the More tab, and attaches the element
/// tree so we can read the exact Offers-row selector. Delete once navigateToOffers
/// is fixed.
final class MoreNavProbeTest: XCTestCase {
  func testProbeMoreNav() throws {
    let app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    XCTAssertTrue(app.waitForLogin(timeout: 15), "login→dashboard failed")

    let dashTree = XCTAttachment(string: app.debugDescription)
    dashTree.name = "dashboard-tree"
    dashTree.lifetime = .keepAlways
    add(dashTree)

    let moreTab = app.tabBars.buttons["More"]
    XCTAssertTrue(moreTab.waitForExistence(timeout: 5), "More tab missing")
    moreTab.tap()
    sleep(2)

    let moreTree = XCTAttachment(string: app.debugDescription)
    moreTree.name = "more-tree"
    moreTree.lifetime = .keepAlways
    add(moreTree)
  }
}
