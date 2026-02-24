import XCTest

/// Page Object Model for the Document Detail screen
/// Maps accessibility labels and identifiers from DocumentDetailView
final class DocumentDetailScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var backButton: XCUIElement {
    app.buttons["Back to Documents"]
  }

  // MARK: - Loading / Error States

  var loadingText: XCUIElement {
    app.staticTexts["Loading document..."]
  }

  var notFoundView: XCUIElement {
    app.staticTexts["Document not found"]
  }

  var returnToDocumentsButton: XCUIElement {
    app.buttons["Return to Documents"]
  }

  var retryButton: XCUIElement {
    app.buttons["Retry"]
  }

  // MARK: - Action Buttons (header card)

  var editButton: XCUIElement {
    app.buttons["Edit document metadata"]
  }

  var shareButton: XCUIElement {
    app.buttons["Share document with schools"]
  }

  var deleteButton: XCUIElement {
    app.buttons["Delete document"]
  }

  // MARK: - Sections

  var versionHistoryHeader: XCUIElement {
    app.staticTexts["Version History"]
  }

  var previewHeader: XCUIElement {
    app.staticTexts["Preview"]
  }

  var uploadNewVersionButton: XCUIElement {
    app.buttons["Upload New Version"]
  }

  // MARK: - Delete Confirmation Dialog

  var deleteConfirmationTitle: XCUIElement {
    app.staticTexts["Delete Document"]
  }

  var deleteConfirmButton: XCUIElement {
    app.buttons["Delete"]
  }

  var deleteCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  // MARK: - Restore Version Dialog

  var restoreConfirmationTitle: XCUIElement {
    app.staticTexts["Restore Version"]
  }

  var restoreConfirmButton: XCUIElement {
    app.buttons["Restore"]
  }

  // MARK: - Navigation Helpers

  func navigateToDocumentsTab() -> Bool {
    let moreTab = app.tabBars.buttons["More"]
    guard moreTab.waitForExistence(timeout: 5) else { return false }
    moreTab.tap()
    let documentsCell = app.cells.buttons["Documents"]
    guard documentsCell.waitForExistence(timeout: 5) else { return false }
    documentsCell.tap()
    return app.navigationBars["Documents"].waitForExistence(timeout: 5)
  }

  func tapFirstDocument() -> Bool {
    let types = ["Highlight Video", "Transcript", "Resume", "Recommendation Letter", "Questionnaire", "Stats Sheet"]
    for type in types {
      let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", type)).firstMatch
      if card.waitForExistence(timeout: 3) {
        card.tap()
        return true
      }
    }
    let anyCard = app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Uploaded'")).firstMatch
    if anyCard.waitForExistence(timeout: 3) {
      anyCard.tap()
      return true
    }
    return false
  }

  // MARK: - Wait Helpers

  func waitForDocumentToLoad() -> Bool {
    editButton.waitForExistence(timeout: 10) || versionHistoryHeader.waitForExistence(timeout: 10)
  }

  func waitForContentOrError() -> Bool {
    editButton.waitForExistence(timeout: 10)
      || versionHistoryHeader.waitForExistence(timeout: 10)
      || notFoundView.waitForExistence(timeout: 5)
      || retryButton.waitForExistence(timeout: 5)
  }

  // MARK: - Scroll Helpers

  func scrollDown() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
    }
  }
}
