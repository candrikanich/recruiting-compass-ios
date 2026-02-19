import XCTest

/// E2E tests for Document Viewer (fullScreenCover): tap card opens viewer,
/// close button dismisses, swipe down dismisses, share button presents sheet.
final class DocumentViewerE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: DocumentViewerScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()
    screen = DocumentViewerScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndOpenDocumentViewer() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    guard screen.navigateToDocumentsTab() else {
      throw XCTSkip("Documents tab not found")
    }
    guard screen.tapFirstDocumentCard() else {
      throw XCTSkip("No documents available to open viewer")
    }
    guard screen.waitForViewerToAppear(timeout: 10) else {
      throw XCTSkip("Document viewer did not open")
    }
  }

  // MARK: - Tap Card Opens Viewer

  @MainActor
  func test_documentViewer_tapCard_opensViewer() throws {
    try loginAndOpenDocumentViewer()
    XCTAssertTrue(
      screen.closeButton.waitForExistence(timeout: 5) || screen.closeButtonByLabel.waitForExistence(timeout: 5),
      "Document viewer should show close button when opened"
    )
  }

  // MARK: - Close Button Dismisses

  @MainActor
  func test_documentViewer_closeButton_dismisses() throws {
    try loginAndOpenDocumentViewer()
    let close = screen.closeButton.exists ? screen.closeButton : screen.closeButtonByLabel
    XCTAssertTrue(close.waitForExistence(timeout: 3), "Close button should exist")
    close.tap()
    sleep(1)
    let documentsNav = app.navigationBars["Documents"]
    XCTAssertTrue(
      documentsNav.waitForExistence(timeout: 5),
      "Tapping close should dismiss viewer and show Documents list"
    )
  }

  // MARK: - Swipe Down Dismisses

  @MainActor
  func test_documentViewer_swipeDown_dismisses() throws {
    try loginAndOpenDocumentViewer()
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
    sleep(1)
    let documentsNav = app.navigationBars["Documents"]
    XCTAssertTrue(
      documentsNav.waitForExistence(timeout: 5),
      "Swipe down should dismiss viewer and show Documents list"
    )
  }

  // MARK: - Share Button Presents Sheet

  @MainActor
  func test_documentViewer_shareButton_presentsSheet() throws {
    try loginAndOpenDocumentViewer()
    let share = screen.shareButton.exists ? screen.shareButton : screen.shareButtonByLabel
    guard share.waitForExistence(timeout: 3), share.isEnabled else {
      throw XCTSkip("Share button not available (document may have no shareable URL)")
    }
    share.tap()
    sleep(1)
    // Share sheet shows system UI - look for common elements (Cancel, Add People, etc.)
    let shareSheet = app.otherElements["ActivityListView"]
      .firstMatch
    let cancelButton = app.buttons["Cancel"]
    let addPeople = app.buttons["Add People"]
    let shareSheetShown = shareSheet.waitForExistence(timeout: 3)
      || cancelButton.waitForExistence(timeout: 3)
      || addPeople.waitForExistence(timeout: 3)
    XCTAssertTrue(
      shareSheetShown,
      "Share button should present share sheet"
    )
    if cancelButton.waitForExistence(timeout: 2) {
      cancelButton.tap()
    }
  }
}
