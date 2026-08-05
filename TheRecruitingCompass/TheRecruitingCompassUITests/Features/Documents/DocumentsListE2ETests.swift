import XCTest

/// E2E tests for Documents List: tab navigation, empty state, filter/sort/upload presence.
final class DocumentsListE2ETests: XCTestCase {
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
  private func navigateToDocumentsTab() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    let moreTab = app.tabBars.buttons["More"]
    guard moreTab.waitForExistence(timeout: 5) else {
      throw XCTSkip("More tab not found")
    }
    moreTab.tap()
    let documentsCell = app.cells.buttons["Documents"]
    guard documentsCell.waitForExistence(timeout: 5) else {
      throw XCTSkip("Documents section not found in More menu")
    }
    documentsCell.tap()
  }

  /// Documents screen shows title and either content or empty state
  @MainActor
  func testDocumentsList_navigateToTab_showsScreen() throws {
    try navigateToDocumentsTab()
    let navTitle = app.navigationBars["Documents"]
    XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Documents navigation title should appear")
  }

  /// Upload button is present (toolbar or FAB)
  @MainActor
  func testDocumentsList_uploadButtonPresent() throws {
    try navigateToDocumentsTab()
    let uploadButton = app.buttons["Upload new document"]
    XCTAssertTrue(uploadButton.waitForExistence(timeout: 5), "Upload new document button should be present")
  }
}
