import XCTest

/// Page Object Model for the Event Detail screen
/// Maps accessibility labels and identifiers from EventDetailView and its components
final class EventDetailScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars.firstMatch
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.firstMatch
  }

  // MARK: - Loading State

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading event..."]
  }

  var loadingAccessibilityLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label == 'Loading event details'"
    )).firstMatch
  }

  // MARK: - Error State

  var errorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'Failed to load' OR label CONTAINS 'not found'"
    )).firstMatch
  }

  var retryButton: XCUIElement {
    app.buttons["Retry"]
  }

  // MARK: - Toolbar Actions Menu

  var actionsMenuButton: XCUIElement {
    app.buttons["Event actions"]
  }

  var editMenuAction: XCUIElement {
    app.buttons["Edit Event"]
  }

  var logInteractionMenuAction: XCUIElement {
    app.buttons["Log Interaction"]
  }

  var addMetricMenuAction: XCUIElement {
    app.buttons["Add Metric"]
  }

  var markAttendedMenuAction: XCUIElement {
    app.buttons["Mark Attended"]
  }

  var deleteMenuAction: XCUIElement {
    app.buttons["Delete Event"]
  }

  // MARK: - Header Section (Event Info)

  var eventInfoHeader: XCUIElement {
    app.staticTexts["Event Info"]
  }

  /// Type badge + status badge combined accessibility element
  func typeBadge(_ typeName: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", typeName
    )).firstMatch
  }

  func statusBadge(_ status: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", status
    )).firstMatch
  }

  var dateLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Date:'"
    )).firstMatch
  }

  var timeLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Time:'"
    )).firstMatch
  }

  var checkinTimeLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Check-in time:'"
    )).firstMatch
  }

  var costLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Cost:' OR label == 'Free event'"
    )).firstMatch
  }

  var sourceLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Source:'"
    )).firstMatch
  }

  // MARK: - Location Section

  var locationHeader: XCUIElement {
    app.staticTexts["Location"]
  }

  var addressLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Address:'"
    )).firstMatch
  }

  var getDirectionsButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label BEGINSWITH 'Get directions to'"
    )).firstMatch
  }

  // MARK: - Details Section

  var detailsHeader: XCUIElement {
    app.staticTexts["Details"]
  }

  var descriptionLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Description:'"
    )).firstMatch
  }

  var eventLinkLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Event link:'"
    )).firstMatch
  }

  // MARK: - Coaches Section

  var coachesHeader: XCUIElement {
    app.staticTexts["Coaches Present"]
  }

  var allCoachCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS ','"
    ))
  }

  func coachCard(name: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", name
    )).firstMatch
  }

  func removeCoachButton(name: String) -> XCUIElement {
    app.buttons["Remove \(name)"]
  }

  var addCoachPicker: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Add coach to event'"
    )).firstMatch
  }

  // MARK: - Metrics Section

  var metricsHeader: XCUIElement {
    app.staticTexts["Performance Metrics"]
  }

  var allMetricCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'recorded'"
    ))
  }

  func metricCard(label: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", label
    )).firstMatch
  }

  var addMetricButton: XCUIElement {
    app.buttons["Add a new performance metric"]
  }

  // MARK: - Metric Form (inline)

  var metricTypeSelector: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Metric type'"
    )).firstMatch
  }

  var metricValueField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "label == 'Metric value'"
    )).firstMatch
  }

  var metricUnitField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "label == 'Unit of measurement'"
    )).firstMatch
  }

  var metricNotesField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "label == 'Metric notes'"
    )).firstMatch
  }

  var saveMetricButton: XCUIElement {
    app.buttons["Save metric"]
  }

  var cancelMetricButton: XCUIElement {
    app.buttons["Cancel adding metric"]
  }

  // MARK: - Performance Notes Section

  var performanceNotesHeader: XCUIElement {
    app.staticTexts["Performance Notes"]
  }

  var performanceNotesContent: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Performance notes:'"
    )).firstMatch
  }

  // MARK: - Edit Event Sheet

  var editSheetNavigationTitle: XCUIElement {
    app.navigationBars["Edit Event"]
  }

  var editEventNameField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "label == 'Event name, required'"
    )).firstMatch
  }

  var editSaveButton: XCUIElement {
    app.buttons["Save"]
  }

  var editCancelButton: XCUIElement {
    app.navigationBars["Edit Event"].buttons["Cancel"]
  }

  // MARK: - Quick Log Interaction Sheet

  var quickLogNavigationTitle: XCUIElement {
    app.navigationBars["Log Interaction"]
  }

  var quickLogSaveButton: XCUIElement {
    app.navigationBars["Log Interaction"].buttons["Save"]
  }

  var quickLogCancelButton: XCUIElement {
    app.navigationBars["Log Interaction"].buttons["Cancel"]
  }

  // MARK: - Delete Confirmation Dialog

  var deleteConfirmationTitle: XCUIElement {
    app.staticTexts["Delete Event"]
  }

  var deleteConfirmButton: XCUIElement {
    app.buttons["Delete"]
  }

  var deleteCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  // MARK: - Success Toast

  var successToast: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'updated' OR label CONTAINS 'deleted' OR label CONTAINS 'logged' OR label CONTAINS 'recorded'"
    )).firstMatch
  }

  // MARK: - Navigation Helpers

  func navigateToEventsTab() -> Bool {
    let eventsTab = app.tabBars.buttons["Events"]
    if eventsTab.waitForExistence(timeout: 5) {
      eventsTab.tap()
      return true
    }
    return false
  }

  func tapFirstEvent() -> Bool {
    let eventCell = app.cells.firstMatch
    guard eventCell.waitForExistence(timeout: 5) else { return false }
    eventCell.tap()
    return true
  }

  // MARK: - Wait Helpers

  func waitForEventToLoad() -> Bool {
    eventInfoHeader.waitForExistence(timeout: 10)
  }

  func waitForContentOrError() -> Bool {
    let hasContent = eventInfoHeader.waitForExistence(timeout: 10)
    if hasContent { return true }
    let hasError = retryButton.waitForExistence(timeout: 3)
    return hasError
  }

  func waitForEditSheet() -> Bool {
    editSheetNavigationTitle.waitForExistence(timeout: 5)
  }

  func waitForQuickLogSheet() -> Bool {
    quickLogNavigationTitle.waitForExistence(timeout: 5)
  }

  func waitForEditSheetDismissed() -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: editSheetNavigationTitle)
    let result = XCTWaiter.wait(for: [expectation], timeout: 5)
    return result == .completed
  }

  // MARK: - Action Helpers

  func openActionsMenu() {
    guard actionsMenuButton.waitForExistence(timeout: 5) else { return }
    actionsMenuButton.tap()
  }

  func tapEditAction() {
    openActionsMenu()
    guard editMenuAction.waitForExistence(timeout: 3) else { return }
    editMenuAction.tap()
  }

  func tapLogInteractionAction() {
    openActionsMenu()
    guard logInteractionMenuAction.waitForExistence(timeout: 3) else { return }
    logInteractionMenuAction.tap()
  }

  func tapAddMetricAction() {
    openActionsMenu()
    guard addMetricMenuAction.waitForExistence(timeout: 3) else { return }
    addMetricMenuAction.tap()
  }

  func tapDeleteAction() {
    openActionsMenu()
    guard deleteMenuAction.waitForExistence(timeout: 3) else { return }
    deleteMenuAction.tap()
  }

  // MARK: - Scroll Helpers

  func scrollDown() {
    let list = app.tables.firstMatch.exists ? app.tables.firstMatch : app.scrollViews.firstMatch
    if list.exists {
      list.swipeUp()
    }
  }

  func scrollUp() {
    let list = app.tables.firstMatch.exists ? app.tables.firstMatch : app.scrollViews.firstMatch
    if list.exists {
      list.swipeDown()
    }
  }

  func pullToRefresh() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
  }
}
