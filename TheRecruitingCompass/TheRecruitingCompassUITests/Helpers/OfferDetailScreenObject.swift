import XCTest

final class OfferDetailScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Offer Details"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.firstMatch
  }

  // MARK: - Header Elements

  var schoolNameLabel: XCUIElement {
    app.staticTexts["offer-detail-school-name"]
  }

  var statusBadge: XCUIElement {
    app.staticTexts["offer-status-badge"]
  }

  // MARK: - Financial Summary Elements

  var amountCard: XCUIElement {
    app.otherElements["offer-amount-card"]
  }

  var percentageCard: XCUIElement {
    app.otherElements["offer-percentage-card"]
  }

  var deadlineCard: XCUIElement {
    app.otherElements["offer-deadline-card"]
  }

  // MARK: - Action Buttons

  var editButton: XCUIElement {
    app.buttons["offer-edit-button"]
  }

  var deleteButton: XCUIElement {
    app.buttons["offer-delete-button"]
  }

  // MARK: - Edit Form Elements

  var saveButton: XCUIElement {
    app.buttons["offer-save-button"]
  }

  var cancelButton: XCUIElement {
    app.buttons["offer-cancel-button"]
  }

  var editFormTitle: XCUIElement {
    app.staticTexts["Edit Offer"]
  }

  var offerTypePicker: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Offer type'")).firstMatch
  }

  var statusPicker: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Offer status'")).firstMatch
  }

  // MARK: - Calculator Elements

  var calculatorSection: XCUIElement {
    app.otherElements["offer-scholarship-calculator"]
  }

  var calculateButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Calculate' OR label == 'Hide'"
    )).firstMatch
  }

  var saveToOfferButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Save to Offer'"
    )).firstMatch
  }

  var resetButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Reset'"
    )).firstMatch
  }

  // MARK: - Alert Elements

  var deleteConfirmationAlert: XCUIElement {
    app.alerts["Delete Offer?"]
  }

  var alertDeleteButton: XCUIElement {
    app.alerts.buttons["Delete"]
  }

  var alertCancelButton: XCUIElement {
    app.alerts.buttons["Cancel"]
  }

  var alertOKButton: XCUIElement {
    app.alerts.buttons["OK"]
  }

  // MARK: - Loading & Error States

  var loadingIndicator: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'Loading offer'"
    )).firstMatch
  }

  var notFoundMessage: XCUIElement {
    app.staticTexts["Offer not found"]
  }

  var returnToOffersButton: XCUIElement {
    app.buttons["Return to Offers"]
  }

  // MARK: - Details Grid

  var offerDetailsSection: XCUIElement {
    app.staticTexts["Offer Details"]
  }

  // MARK: - Helper Methods

  func waitForOfferToLoad(timeout: TimeInterval = 10) -> Bool {
    navigationTitle.waitForExistence(timeout: timeout) &&
      !loadingIndicator.exists
  }

  func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 10) {
    var swipeCount = 0
    while !element.isHittable && swipeCount < maxSwipes {
      app.swipeUp()
      swipeCount += 1
    }
  }

  func scrollToBottom(swipes: Int = 5) {
    for _ in 0..<swipes {
      app.swipeUp()
    }
  }

  func pullToRefresh() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
  }

  // MARK: - Action Helpers

  func tapEdit() {
    scrollToElement(editButton)
    editButton.tap()
  }

  func tapDelete() {
    scrollToElement(deleteButton)
    deleteButton.tap()
  }

  func tapSave() {
    saveButton.tap()
  }

  func tapCancel() {
    cancelButton.tap()
  }

  func confirmDelete() {
    alertDeleteButton.tap()
  }

  func cancelDelete() {
    alertCancelButton.tap()
  }

  func dismissError() {
    alertOKButton.tap()
  }

  func tapBackButton() {
    backButton.tap()
  }

  func expandCalculator() {
    scrollToElement(calculatorSection)
    let calcBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Calculate'"
    )).firstMatch
    if calcBtn.waitForExistence(timeout: 3) {
      calcBtn.tap()
    }
  }

  func collapseCalculator() {
    let hideBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Hide'"
    )).firstMatch
    if hideBtn.waitForExistence(timeout: 3) {
      hideBtn.tap()
    }
  }

  // MARK: - Navigation Helpers

  func navigateToOfferDetailFromList() -> Bool {
    // From offers list, tap first available offer card
    let firstCard = app.otherElements.matching(NSPredicate(
      format: "identifier BEGINSWITH 'offer_card_'"
    )).firstMatch

    guard firstCard.waitForExistence(timeout: 5) else { return false }

    // Tap the card content area (the VStack with accessibilityHint)
    firstCard.tap()
    return waitForOfferToLoad()
  }

  func navigateToOffersFromDashboard() -> Bool {
    // Offers lives under the More tab (it is not a main tab and no longer has a
    // dashboard stat card — that slot now belongs to Events).
    return MainTabNavigator(app: app).goToMoreSection("Offers")
  }
}
