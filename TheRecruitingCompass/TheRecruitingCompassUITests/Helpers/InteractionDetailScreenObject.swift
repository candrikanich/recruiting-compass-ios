import XCTest

/// Page Object Model for the Interaction Detail screen
/// Provides helper methods for UI test interactions
final class InteractionDetailScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Interaction"]
  }

  var actionsMenuButton: XCUIElement {
    app.buttons["Interaction actions menu"]
  }

  // MARK: - Content Elements

  var interactionSubject: XCUIElement {
    app.staticTexts["interaction-subject"]
  }

  var occurredAtLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Occurred at'")).firstMatch
  }

  var typeBadge: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'interaction'")).firstMatch
  }

  var directionBadge: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'direction'")).firstMatch
  }

  var sentimentBadge: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sentiment:'")).firstMatch
  }

  var contentSection: XCUIElement {
    app.staticTexts["Interaction content"]
  }

  // MARK: - Details Grid

  var schoolDetailItem: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'School:'")).firstMatch
  }

  var coachDetailItem: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Coach:'")).firstMatch
  }

  var eventDetailItem: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Event:'")).firstMatch
  }

  var loggedByDetailItem: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Logged By:'")).firstMatch
  }

  // MARK: - Metadata

  var createdAtLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Created:'")).firstMatch
  }

  var attachmentsLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Attachments:'")).firstMatch
  }

  // MARK: - Menu Actions

  var exportButton: XCUIElement {
    app.buttons["Export"]
  }

  var deleteButton: XCUIElement {
    app.buttons["Delete"]
  }

  // MARK: - Delete Confirmation

  var deleteConfirmationDialog: XCUIElement {
    app.sheets["Delete Interaction"]
  }

  var confirmDeleteButton: XCUIElement {
    deleteConfirmationDialog.buttons["Delete"]
  }

  var cancelDeleteButton: XCUIElement {
    deleteConfirmationDialog.buttons["Cancel"]
  }

  // MARK: - Loading/Error States

  var loadingView: XCUIElement {
    app.staticTexts["Loading interaction..."]
  }

  var errorView: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'not found'")).firstMatch
  }

  // MARK: - Helper Methods

  func navigateToInteractionDetail(fromRow row: Int) {
    // Tap on interaction card in list
    let interactionCard = app.scrollViews.buttons.element(boundBy: row)
    if interactionCard.waitForExistence(timeout: 5) {
      interactionCard.tap()
    }
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    // Wait for either content or error to appear
    let contentExists = interactionSubject.waitForExistence(timeout: 10)
    let errorExists = errorView.waitForExistence(timeout: 1)
    return contentExists || errorExists
  }

  func tapActionsMenu() {
    actionsMenuButton.tap()
  }

  func tapExport() {
    tapActionsMenu()
    if exportButton.waitForExistence(timeout: 2) {
      exportButton.tap()
    }
  }

  func tapDelete() {
    tapActionsMenu()
    if deleteButton.waitForExistence(timeout: 2) {
      deleteButton.tap()
    }
  }

  func confirmDelete() {
    if confirmDeleteButton.waitForExistence(timeout: 5) {
      confirmDeleteButton.tap()
    }
  }

  func cancelDelete() {
    if cancelDeleteButton.waitForExistence(timeout: 5) {
      cancelDeleteButton.tap()
    }
  }

  func tapSchoolLink() {
    schoolDetailItem.tap()
  }

  func tapCoachLink() {
    coachDetailItem.tap()
  }

  func waitForDeletion(timeout: TimeInterval = 15) -> Bool {
    // Wait for navigation away from detail screen
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: navigationTitle)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  func verifyReadOnlyView() -> Bool {
    // Parent user should NOT see actions menu
    !actionsMenuButton.exists
  }

  func verifyEditableView() -> Bool {
    // Student/player user should see actions menu
    actionsMenuButton.exists
  }

  func verifySchoolLinkExists() -> Bool {
    schoolDetailItem.exists && schoolDetailItem.isEnabled
  }

  func verifyCoachLinkExists() -> Bool {
    coachDetailItem.exists && coachDetailItem.isEnabled
  }

  func verifyHasContent() -> Bool {
    contentSection.exists
  }

  func verifyHasAttachments() -> Bool {
    attachmentsLabel.exists
  }
}
