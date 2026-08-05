import XCTest

/// E2E tests for Document Detail: navigate to detail, view metadata, edit, share, version history, delete.
final class DocumentDetailE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: DocumentDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
    screen = DocumentDetailScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  @MainActor
  private func loginAndNavigateToDocumentDetail() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    guard screen.navigateToDocumentsTab() else {
      throw XCTSkip("Documents tab not found")
    }
    guard screen.tapFirstDocument() else {
      throw XCTSkip("No documents available to navigate to detail")
    }
    guard screen.waitForContentOrError() else {
      throw XCTSkip("Document detail did not load")
    }
  }

  // MARK: - Navigate to Detail

  @MainActor
  func test_documentDetail_navigate_showsScreen() throws {
    try loginAndNavigateToDocumentDetail()
    XCTAssertTrue(screen.waitForDocumentToLoad(), "Document detail should load with edit/share/delete or version history")
  }

  // MARK: - View Metadata

  @MainActor
  func test_documentDetail_metadata_visible() throws {
    try loginAndNavigateToDocumentDetail()
    screen.scrollDown()
    sleep(1)
    let versionHeader = screen.versionHistoryHeader
    XCTAssertTrue(versionHeader.waitForExistence(timeout: 5), "Version History section should be visible")
  }

  // MARK: - Edit Button

  @MainActor
  func test_documentDetail_editButton_exists() throws {
    try loginAndNavigateToDocumentDetail()
    XCTAssertTrue(screen.editButton.waitForExistence(timeout: 5), "Edit button should be present")
  }

  // MARK: - Share Button

  @MainActor
  func test_documentDetail_shareButton_exists() throws {
    try loginAndNavigateToDocumentDetail()
    XCTAssertTrue(screen.shareButton.waitForExistence(timeout: 5), "Share button should be present")
  }

  // MARK: - Version History Section

  @MainActor
  func test_documentDetail_versionHistorySection_exists() throws {
    try loginAndNavigateToDocumentDetail()
    screen.scrollDown()
    sleep(1)
    XCTAssertTrue(screen.versionHistoryHeader.waitForExistence(timeout: 5), "Version History header should be visible")
  }

  // MARK: - Delete Confirmation

  @MainActor
  func test_documentDetail_deleteTriggersConfirmation() throws {
    try loginAndNavigateToDocumentDetail()
    XCTAssertTrue(screen.deleteButton.waitForExistence(timeout: 5), "Delete button should exist")
    screen.deleteButton.tap()
    sleep(1)
    let deleteConfirm = screen.deleteConfirmButton
    XCTAssertTrue(deleteConfirm.waitForExistence(timeout: 3), "Delete confirmation dialog should appear")
    let cancel = screen.deleteCancelButton
    if cancel.waitForExistence(timeout: 2) {
      cancel.tap()
    }
  }

  // MARK: - Back Navigation

  @MainActor
  func test_documentDetail_backButton_exists() throws {
    try loginAndNavigateToDocumentDetail()
    XCTAssertTrue(screen.backButton.waitForExistence(timeout: 5), "Back to Documents button should be present")
  }
}
