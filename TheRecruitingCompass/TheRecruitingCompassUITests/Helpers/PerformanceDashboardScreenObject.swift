import XCTest

/// Page Object Model for the Performance Dashboard screens
/// Covers the main dashboard, log/edit forms, chart, and trend views
final class PerformanceDashboardScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Performance"]
  }

  // MARK: - Loading / Error / Empty States

  var loadingIndicator: XCUIElement {
    app.activityIndicators.firstMatch
  }

  var emptyStateText: XCUIElement {
    app.staticTexts["No metrics logged yet"]
  }

  var emptyStateSubtext: XCUIElement {
    app.staticTexts["Start tracking your performance by logging your first metric."]
  }

  var errorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'Failed to load' OR label CONTAINS 'error' OR label CONTAINS 'try again'"
    )).firstMatch
  }

  var retryButton: XCUIElement {
    app.buttons["Try Again"]
  }

  // MARK: - Log Metric Button

  var logMetricButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Log Metric' OR label CONTAINS 'log metric' OR label CONTAINS 'Add Metric'"
    )).firstMatch
  }

  // MARK: - Metric Type Filter Bar

  func metricTypeFilterButton(_ typeName: String) -> XCUIElement {
    app.buttons["\(typeName) filter"]
  }

  var allFilterButtons: XCUIElementQuery {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'filter'"))
  }

  // MARK: - Latest Metric Cards

  func latestMetricCard(for metricName: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", metricName
    )).firstMatch
  }

  var allMetricCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'recorded'"
    ))
  }

  // MARK: - History Cards (with Edit/Delete)

  func historyCard(for metricName: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@", metricName
    )).firstMatch
  }

  /// Edit button inside a history card - uses the "Edit" button text
  var editButtons: XCUIElementQuery {
    app.buttons.matching(NSPredicate(format: "label == 'Edit'"))
  }

  /// Delete button inside a history card - uses the "Delete" button text
  var deleteButtons: XCUIElementQuery {
    app.buttons.matching(NSPredicate(format: "label == 'Delete'"))
  }

  func editButton(at index: Int) -> XCUIElement {
    editButtons.element(boundBy: index)
  }

  func deleteButton(at index: Int) -> XCUIElement {
    deleteButtons.element(boundBy: index)
  }

  // MARK: - Delete Confirmation

  var deleteConfirmationAlert: XCUIElement {
    app.alerts.firstMatch
  }

  var confirmDeleteButton: XCUIElement {
    app.alerts.buttons["Delete"]
  }

  var cancelDeleteButton: XCUIElement {
    app.alerts.buttons["Cancel"]
  }

  // MARK: - Trend Cards

  func trendCard(for metricName: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS %@ AND label CONTAINS 'records'", metricName
    )).firstMatch
  }

  func trendIndicator(_ direction: String) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Trend: \(direction)'"
    )).firstMatch
  }

  var allTrendCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'records, average'"
    ))
  }

  // MARK: - Chart

  var chartView: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'chart' OR label CONTAINS 'Chart'"
    )).firstMatch
  }

  // MARK: - Add/Edit Form Elements

  var formSheet: XCUIElement {
    app.sheets.firstMatch
  }

  var metricTypePicker: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Metric Type' OR label CONTAINS 'Select type' OR label CONTAINS 'metric type'"
    )).firstMatch
  }

  var valueTextField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "placeholderValue CONTAINS 'value' OR placeholderValue CONTAINS 'Value' OR label CONTAINS 'Value'"
    )).firstMatch
  }

  var notesTextField: XCUIElement {
    app.textFields.matching(NSPredicate(
      format: "placeholderValue CONTAINS 'notes' OR placeholderValue CONTAINS 'Notes' OR label CONTAINS 'Notes'"
    )).firstMatch
  }

  var verifiedToggle: XCUIElement {
    app.switches.matching(NSPredicate(
      format: "label CONTAINS 'Verified' OR label CONTAINS 'verified'"
    )).firstMatch
  }

  var saveButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label == 'Save' OR label == 'Log Metric' OR label == 'Save Metric'"
    )).firstMatch
  }

  var cancelFormButton: XCUIElement {
    app.buttons["Cancel"]
  }

  var datePicker: XCUIElement {
    app.datePickers.firstMatch
  }

  // MARK: - Success Toast

  var successToast: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'successfully' OR label CONTAINS 'logged' OR label CONTAINS 'deleted'"
    )).firstMatch
  }

  // MARK: - Export

  var exportButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Export' OR label CONTAINS 'export'"
    )).firstMatch
  }

  // MARK: - Navigation Actions

  func navigateToPerformanceTab() {
    let performanceTab = app.tabBars.buttons["Performance"]
    if performanceTab.waitForExistence(timeout: 5) {
      performanceTab.tap()
    }
  }

  func navigateFromDashboardWidget() {
    let widgetLink = app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'View All' OR label CONTAINS 'Performance' OR label CONTAINS 'See All Metrics'"
    )).firstMatch
    if widgetLink.waitForExistence(timeout: 5) {
      widgetLink.tap()
    }
  }

  func navigateToPerformance() -> Bool {
    // Try tab first
    let performanceTab = app.tabBars.buttons["Performance"]
    if performanceTab.waitForExistence(timeout: 3) {
      performanceTab.tap()
      return navigationTitle.waitForExistence(timeout: 5)
    }

    // Try dashboard widget link
    navigateFromDashboardWidget()
    return navigationTitle.waitForExistence(timeout: 5)
  }

  // MARK: - Wait Helpers

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    let hasMetrics = allMetricCards.firstMatch.waitForExistence(timeout: 10)
    if hasMetrics { return true }
    let hasEmpty = emptyStateText.waitForExistence(timeout: 3)
    if hasEmpty { return true }
    let hasError = retryButton.waitForExistence(timeout: 3)
    return hasError
  }

  func waitForFormToAppear() -> Bool {
    valueTextField.waitForExistence(timeout: 5)
  }

  func waitForFormToDismiss() -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: valueTextField)
    let result = XCTWaiter.wait(for: [expectation], timeout: 5)
    return result == .completed
  }

  // MARK: - Form Actions

  func selectMetricType(_ typeName: String) {
    if metricTypePicker.waitForExistence(timeout: 3) {
      metricTypePicker.tap()
    }
    let option = app.buttons[typeName]
    if option.waitForExistence(timeout: 3) {
      option.tap()
    }
  }

  func fillValue(_ value: String) {
    guard valueTextField.waitForExistence(timeout: 3) else { return }
    valueTextField.clearAndTypeText(value)
  }

  func fillNotes(_ notes: String) {
    guard notesTextField.waitForExistence(timeout: 3) else { return }
    notesTextField.clearAndTypeText(notes)
  }

  func toggleVerified() {
    guard verifiedToggle.waitForExistence(timeout: 3) else { return }
    verifiedToggle.tap()
  }

  func submitForm() {
    guard saveButton.waitForExistence(timeout: 3) else { return }
    saveButton.tap()
  }

  func cancelForm() {
    guard cancelFormButton.waitForExistence(timeout: 3) else { return }
    cancelFormButton.tap()
  }

  func dismissKeyboard() {
    app.tap()
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

  // MARK: - Verification Helpers

  func hasMetricsLoaded() -> Bool {
    allMetricCards.count > 0
  }

  func verifyEmptyState() -> Bool {
    emptyStateText.exists
  }

  func verifyErrorState() -> Bool {
    errorMessage.exists || retryButton.exists
  }

  func metricCardCount() -> Int {
    allMetricCards.count
  }

  func trendCardCount() -> Int {
    allTrendCards.count
  }
}
