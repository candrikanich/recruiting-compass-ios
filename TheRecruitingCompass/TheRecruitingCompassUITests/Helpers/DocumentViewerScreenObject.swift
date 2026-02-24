import XCTest

/// Page Object Model for the Document Viewer (fullScreenCover)
/// Maps accessibility identifiers from DocumentViewerView
final class DocumentViewerScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Viewer Container

  var viewerView: XCUIElement {
    app.otherElements["document-viewer-view"]
  }

  var closeButton: XCUIElement {
    app.buttons["document-viewer-close"]
  }

  var shareButton: XCUIElement {
    app.buttons["document-viewer-share"]
  }

  var downloadButton: XCUIElement {
    app.buttons["document-viewer-download"]
  }

  // Fallback: accessibility labels (when identifier not available)
  var closeButtonByLabel: XCUIElement {
    app.buttons["Close document viewer"]
  }

  var shareButtonByLabel: XCUIElement {
    app.buttons["Share document"]
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

  /// Tap first document card (opens DocumentViewerView via fullScreenCover)
  func tapFirstDocumentCard() -> Bool {
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

  func waitForViewerToAppear(timeout: TimeInterval = 10) -> Bool {
    closeButton.waitForExistence(timeout: timeout)
      || closeButtonByLabel.waitForExistence(timeout: timeout)
  }

  func waitForViewerToDismiss(timeout: TimeInterval = 5) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let close = closeButton
    let exp = XCTNSPredicateExpectation(predicate: predicate, object: close)
    return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
  }
}
