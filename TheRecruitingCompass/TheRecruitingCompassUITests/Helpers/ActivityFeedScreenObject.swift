import XCTest

/// Page Object Model for the Activity Feed screens
/// Covers both the full Activity History page and the Dashboard RecentActivityFeed widget
final class ActivityFeedScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Full Page Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Activity History"]
  }

  // MARK: - Filter Controls

  /// The Activity Type picker (menu style) - label is "Activity Type"
  var typeFilterPicker: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Activity Type' OR label CONTAINS 'All Activities' OR label CONTAINS 'Interactions' OR label CONTAINS 'Documents'"
    )).firstMatch
  }

  /// The Date Range picker (segmented style) - contains segment buttons
  var dateRangeSegmentedControl: XCUIElement {
    app.segmentedControls.firstMatch
  }

  var searchField: XCUIElement {
    app.textFields["Search activities..."]
  }

  var clearSearchButton: XCUIElement {
    app.buttons["Clear search"]
  }

  // MARK: - Activity List

  /// Activity items use .accessibilityElement(children: .combine) with combined labels
  /// They appear as accessibility elements with labels like "Interactions, Email with ASU, ..., 2h ago"
  /// Clickable items have .isButton trait via NavigationLink
  var clickableActivityItems: XCUIElementQuery {
    // NavigationLink wraps clickable items, making them buttons
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Interactions' OR label CONTAINS 'Status Changes' OR label CONTAINS 'Documents'"
    ))
  }

  /// All activity items (both clickable and non-clickable) using their type prefix
  func allActivityElements() -> [XCUIElement] {
    var elements: [XCUIElement] = []

    // Clickable items appear as buttons (NavigationLink)
    let buttons = app.buttons.allElementsBoundByIndex
    for button in buttons {
      let label = button.label
      if label.contains("Interactions,") ||
         label.contains("School Status Changes,") ||
         label.contains("Documents,") {
        elements.append(button)
      }
    }

    // Non-clickable items appear as other elements
    let others = app.otherElements.allElementsBoundByIndex
    for other in others {
      let label = other.label
      if label.contains("Interactions,") ||
         label.contains("School Status Changes,") ||
         label.contains("Documents,") {
        elements.append(other)
      }
    }

    return elements
  }

  // MARK: - Pagination

  var previousPageButton: XCUIElement {
    app.buttons["Previous"]
  }

  var nextPageButton: XCUIElement {
    app.buttons["Next"]
  }

  var pageLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label MATCHES 'Page [0-9]+ of [0-9]+'"
    )).firstMatch
  }

  // MARK: - Loading / Error / Empty States

  var loadingText: XCUIElement {
    app.staticTexts["Loading activities..."]
  }

  var emptyStateText: XCUIElement {
    app.staticTexts["No activities found"]
  }

  var filteredEmptyStateSuggestion: XCUIElement {
    app.staticTexts["Try adjusting your filters or search query"]
  }

  var initialEmptyStateSuggestion: XCUIElement {
    app.staticTexts["Your recruiting activity will appear here"]
  }

  var clearFiltersButton: XCUIElement {
    app.buttons["Clear Filters"]
  }

  var retryButton: XCUIElement {
    app.buttons["Try Again"]
  }

  // MARK: - Dashboard Widget Elements

  var widgetTitle: XCUIElement {
    app.staticTexts["Recent Activity"]
  }

  var widgetEmptyState: XCUIElement {
    app.staticTexts["No recent activity"]
  }

  /// Widget "show more" / "show less" toggle button
  var widgetShowMoreButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'activities' AND (label CONTAINS 'Show' OR label CONTAINS 'show')"
    )).firstMatch
  }

  /// Widget activity rows (ActivityRow uses .accessibilityElement(children: .combine))
  func widgetActivityRows() -> [XCUIElement] {
    // Widget items are within the dashboard scroll view
    // They use .accessibilityElement(children: .combine) with .accessibilityLabel(activity.description)
    let rows: [XCUIElement] = []
    let elements = app.otherElements.allElementsBoundByIndex
    for element in elements {
      // ActivityRow has accessibility label = activity.description and value = timestamp
      if !element.label.isEmpty && !element.value.debugDescription.isEmpty {
        // This is a heuristic - may need refinement based on actual runtime behavior
      }
    }
    return rows
  }

  // MARK: - Navigation Actions

  /// Navigate to Activity History from dashboard (requires navigation link to be wired)
  func navigateToActivityFromDashboard() {
    // If there's a NavigationLink to Activity on dashboard
    let activityLink = app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'View All Activity' OR label CONTAINS 'Activity History'"
    )).firstMatch
    if activityLink.waitForExistence(timeout: 5) {
      activityLink.tap()
    }
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    // Check for activity items by looking for the search field (only shown when activities exist)
    let hasSearchField = searchField.waitForExistence(timeout: 10)
    if hasSearchField { return true }
    let hasEmpty = emptyStateText.waitForExistence(timeout: 2)
    if hasEmpty { return true }
    let hasError = retryButton.waitForExistence(timeout: 2)
    return hasError
  }

  func hasActivitiesLoaded() -> Bool {
    searchField.exists
  }

  func waitForWidgetToLoad() -> Bool {
    // Widget shows either activity descriptions or empty state
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
    }
    sleep(1)
    let hasTitle = widgetTitle.waitForExistence(timeout: 5)
    return hasTitle
  }

  // MARK: - Filter Actions

  func selectTypeFilter(_ type: String) {
    // Menu picker - tap to open, then select option
    if typeFilterPicker.waitForExistence(timeout: 5) {
      typeFilterPicker.tap()
    }
    let option = app.buttons[type]
    if option.waitForExistence(timeout: 3) {
      option.tap()
    }
  }

  func selectDateRangeSegment(_ range: String) {
    let segment = dateRangeSegmentedControl.buttons[range]
    if segment.waitForExistence(timeout: 5) {
      segment.tap()
    }
  }

  func searchActivities(_ query: String) {
    if searchField.waitForExistence(timeout: 5) {
      searchField.tap()
      searchField.typeText(query)
    }
  }

  func clearSearch() {
    if clearSearchButton.waitForExistence(timeout: 3) {
      clearSearchButton.tap()
    }
  }

  // MARK: - Pagination Actions

  func tapNextPage() {
    if nextPageButton.waitForExistence(timeout: 3) {
      nextPageButton.tap()
    }
  }

  func tapPreviousPage() {
    if previousPageButton.waitForExistence(timeout: 3) {
      previousPageButton.tap()
    }
  }

  func getPageLabelText() -> String? {
    guard pageLabel.waitForExistence(timeout: 3) else { return nil }
    return pageLabel.label
  }

  // MARK: - Pull to Refresh

  func pullToRefresh() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
  }

  // MARK: - Verification Helpers

  func verifyFilteredEmptyState() -> Bool {
    emptyStateText.exists && filteredEmptyStateSuggestion.exists
  }

  func verifyInitialEmptyState() -> Bool {
    emptyStateText.exists && initialEmptyStateSuggestion.exists
  }

  func verifyErrorState() -> Bool {
    retryButton.exists
  }

  func verifyPaginationVisible() -> Bool {
    pageLabel.exists && previousPageButton.exists && nextPageButton.exists
  }
}
