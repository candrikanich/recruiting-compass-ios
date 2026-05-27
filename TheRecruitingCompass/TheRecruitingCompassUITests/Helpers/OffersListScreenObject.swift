import XCTest

/// Page Object Model for the Offers List screen
/// Matches actual implementation: accessibility identifiers and labels from OffersListView and its components
final class OffersListScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Offers"]
  }

  // MARK: - Top-Level Container

  var offersList: XCUIElement {
    app.otherElements["offers_list"]
  }

  // MARK: - Toolbar Buttons

  var addOfferButton: XCUIElement {
    app.buttons["add_offer_button"]
  }

  var compareButton: XCUIElement {
    app.buttons["compare_button"]
  }

  // MARK: - Summary Cards
  // SummaryCard uses .accessibilityElement(children: .combine)
  // with .accessibilityLabel("\(count) \(title) offer(s)")

  var acceptedCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Accepted offer'"
    )).firstMatch
  }

  var pendingCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Pending offer'"
    )).firstMatch
  }

  var declinedCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Declined offer'"
    )).firstMatch
  }

  var allSummaryCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Accepted offer' OR label CONTAINS 'Pending offer' OR label CONTAINS 'Declined offer'"
    ))
  }

  // MARK: - Filter Controls

  var statusFilter: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Filter by status'"
    )).firstMatch
  }

  var offerTypeFilter: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Filter by offer type'"
    )).firstMatch
  }

  var sortByField: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Sort by field'"
    )).firstMatch
  }

  var sortDirection: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Sort direction'"
    )).firstMatch
  }

  // MARK: - Empty State

  var emptyStateTitle: XCUIElement {
    app.staticTexts["No offers yet"]
  }

  var emptyStateSubtitle: XCUIElement {
    app.staticTexts["Start logging your scholarship offers to track your recruiting journey"]
  }

  var filteredEmptyTitle: XCUIElement {
    app.staticTexts["No offers match your filters"]
  }

  var clearFiltersButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Clear all filters'"
    )).firstMatch
  }

  // MARK: - Add Offer Form

  var saveOfferButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Save offer'"
    )).firstMatch
  }

  var cancelAddOfferButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Cancel adding offer'"
    )).firstMatch
  }

  // MARK: - Offer Cards

  var allOfferCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "identifier BEGINSWITH 'offer_card_'"
    ))
  }

  func offerCardCount() -> Int {
    allOfferCards.count
  }

  // MARK: - Search

  var searchField: XCUIElement {
    app.searchFields["Search by school..."]
  }

  // MARK: - Navigation Actions

  func navigateToOffers() -> Bool {
    // Offers is not a top-level tab. It lives under the "More" tab, in the
    // "Recruiting" section. The row uses .accessibilityElement(children: .combine)
    // so its label is "Offers: <description>" — match on a leading "Offers".
    let moreTab = app.tabBars.buttons["More"]
    guard moreTab.waitForExistence(timeout: 5) else {
      return waitForScreenToLoad()
    }
    moreTab.tap()

    let offersRowPredicate = NSPredicate(format: "label BEGINSWITH 'Offers'")
    let offersButton = app.buttons.matching(offersRowPredicate).firstMatch
    if offersButton.waitForExistence(timeout: 5) {
      offersButton.tap()
      return waitForScreenToLoad()
    }

    // Combined rows can surface as otherElements rather than buttons.
    let offersOther = app.otherElements.matching(offersRowPredicate).firstMatch
    if offersOther.waitForExistence(timeout: 3) {
      offersOther.tap()
    }
    return waitForScreenToLoad()
  }

  // MARK: - Wait Helpers

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    let hasCards = allSummaryCards.firstMatch.waitForExistence(timeout: 10)
    if hasCards { return true }

    let hasEmpty = emptyStateTitle.waitForExistence(timeout: 3)
    return hasEmpty
  }

  func hasSummaryCardsLoaded() -> Bool {
    allSummaryCards.count > 0
  }

  func hasOffersLoaded() -> Bool {
    allOfferCards.count > 0
  }

  func verifyEmptyState() -> Bool {
    emptyStateTitle.exists
  }

  // MARK: - Offer Card Actions

  func offerCheckbox(id: String) -> XCUIElement {
    app.buttons["offer_checkbox_\(id)"]
  }

  func offerDeleteButton(id: String) -> XCUIElement {
    app.buttons["offer_delete_button_\(id)"]
  }

  func offerCard(id: String) -> XCUIElement {
    app.otherElements["offer_card_\(id)"]
  }

  func tapAddOffer() {
    addOfferButton.tap()
  }

  func selectOfferCheckbox(id: String) {
    let checkbox = offerCheckbox(id: id)
    if checkbox.waitForExistence(timeout: 3) {
      checkbox.tap()
    }
  }

  func tapCompare() {
    compareButton.tap()
  }

  func deleteOffer(id: String, confirmDelete: Bool = true) {
    let deleteBtn = offerDeleteButton(id: id)
    if deleteBtn.waitForExistence(timeout: 3) {
      deleteBtn.tap()
    }

    if confirmDelete {
      let deleteConfirm = app.buttons["Delete"]
      if deleteConfirm.waitForExistence(timeout: 3) {
        deleteConfirm.tap()
      }
    } else {
      let cancelBtn = app.buttons["Cancel"]
      if cancelBtn.waitForExistence(timeout: 3) {
        cancelBtn.tap()
      }
    }
  }

  func applyStatusFilter(_ status: String) {
    if statusFilter.waitForExistence(timeout: 3) {
      statusFilter.tap()
    }

    let option = app.buttons[status]
    if option.waitForExistence(timeout: 3) {
      option.tap()
    }
  }

  // MARK: - Delete Confirmation

  var deleteConfirmationDialog: XCUIElement {
    app.sheets.firstMatch
  }

  var deleteConfirmButton: XCUIElement {
    app.buttons["Delete"]
  }

  // MARK: - Comparison Sheet

  var comparisonSheetTitle: XCUIElement {
    app.navigationBars["Compare Offers"]
  }

  func waitForComparisonSheet() -> Bool {
    comparisonSheetTitle.waitForExistence(timeout: 5)
  }

  // MARK: - Validation Errors

  var validationErrors: XCUIElementQuery {
    app.staticTexts.matching(NSPredicate(
      format: "identifier == 'validation_error' OR label CONTAINS 'required'"
    ))
  }

  // MARK: - Scroll Helpers

  func scrollDown() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
    }
  }

  func scrollUp() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeDown()
    }
  }

  func pullToRefresh() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
  }
}
