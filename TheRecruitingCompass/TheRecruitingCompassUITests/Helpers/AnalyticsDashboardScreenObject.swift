import XCTest

/// Page Object Model for the Analytics Dashboard screens
/// Matches actual implementation: accessibility labels (not identifiers), toolbar export, sheet-based format picker
final class AnalyticsDashboardScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Analytics Dashboard"]
  }

  var screenSubtitle: XCUIElement {
    app.staticTexts["Comprehensive recruiting metrics and performance insights"]
  }

  // MARK: - Loading / Error / Empty States

  var loadingIndicator: XCUIElement {
    app.activityIndicators.firstMatch
  }

  var loadingText: XCUIElement {
    app.staticTexts["Loading analytics..."]
  }

  var emptyStateLabel: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'No analytics data available'"
    )).firstMatch
  }

  var emptyStateImage: XCUIElement {
    app.images["chart.bar.xaxis"]
  }

  var errorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'Failed to load' OR label CONTAINS 'Unable to Load' OR label CONTAINS 'Pull to refresh'"
    )).firstMatch
  }

  var retryButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Retry' OR label == 'Retry loading analytics'"
    )).firstMatch
  }

  // MARK: - Date Range Toolbar

  var last7DaysButton: XCUIElement {
    app.buttons["Filter by Last 7 Days"]
  }

  var last30DaysButton: XCUIElement {
    app.buttons["Filter by Last 30 Days"]
  }

  var last90DaysButton: XCUIElement {
    app.buttons["Filter by Last 90 Days"]
  }

  var customRangeButton: XCUIElement {
    app.buttons["Select custom date range"]
  }

  var allDateRangeButtons: XCUIElementQuery {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Filter by '"))
  }

  // MARK: - Summary Stat Cards
  // StatCardView uses .accessibilityElement(children: .combine)
  // with .accessibilityLabel("\(card.title): \(card.value)")

  var allStatCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Total Schools:' OR label CONTAINS 'Interactions:' OR label CONTAINS 'Offers:' OR label CONTAINS 'Commitments:'"
    ))
  }

  var totalSchoolsCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Total Schools:'"
    )).firstMatch
  }

  var interactionsCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Interactions:'"
    )).firstMatch
  }

  var offersCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Offers:'"
    )).firstMatch
  }

  var commitmentsCard: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Commitments:'"
    )).firstMatch
  }

  // Aliases for compatibility
  var totalInteractionsCard: XCUIElement { interactionsCard }
  var totalOffersCard: XCUIElement { offersCard }
  var statCards: XCUIElementQuery { allStatCards }

  var emptyStateText: XCUIElement { emptyStateLabel }
  var emptyStateSubtext: XCUIElement {
    app.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'Start adding' OR label CONTAINS 'schools and logging'"
    )).firstMatch
  }

  func statCardCount() -> Int {
    allStatCards.count
  }

  // MARK: - Charts
  // Charts use .accessibilityElement(children: .combine)
  // PieChartView: "\(title) pie chart with N segments"
  // FunnelChartView: "\(title) funnel chart with N stages"
  // ScatterChartView: "\(title) scatter plot with N data points"

  var interactionTypesChart: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Interaction Types pie chart'"
    )).firstMatch
  }

  var sentimentChart: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Sentiment Breakdown pie chart'"
    )).firstMatch
  }

  var pipelineChart: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Recruiting Pipeline funnel chart'"
    )).firstMatch
  }

  var schoolStatusChart: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'School Status' AND label CONTAINS 'pie chart'"
    )).firstMatch
  }

  var scatterPlot: XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label BEGINSWITH 'Performance Correlation scatter plot'"
    )).firstMatch
  }

  var allCharts: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'pie chart' OR label CONTAINS 'funnel chart' OR label CONTAINS 'scatter plot'"
    ))
  }

  func chartCount() -> Int {
    allCharts.count
  }

  // MARK: - Export (Toolbar button -> Sheet with format options)

  var exportToolbarButton: XCUIElement {
    app.buttons["Export analytics data"]
  }

  var exportSheetTitle: XCUIElement {
    app.navigationBars["Export Analytics"]
  }

  var exportCSVButton: XCUIElement {
    app.buttons["Export as CSV"]
  }

  var exportExcelButton: XCUIElement {
    app.buttons["Export as Excel"]
  }

  var exportPDFButton: XCUIElement {
    app.buttons["Export as PDF"]
  }

  var exportCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  var shareSheet: XCUIElement {
    app.otherElements["ActivityListView"]
  }

  // MARK: - Custom Date Picker Sheet

  var customDatePickerTitle: XCUIElement {
    app.navigationBars["Custom Date Range"]
  }

  var customDateApplyButton: XCUIElement {
    app.buttons["Apply"]
  }

  var customDateCancelButton: XCUIElement {
    app.buttons["Cancel"]
  }

  // MARK: - Navigation Actions

  func navigateToAnalytics() -> Bool {
    // Try tab bar first
    let analyticsTab = app.tabBars.buttons["Analytics"]
    if analyticsTab.waitForExistence(timeout: 3) {
      analyticsTab.tap()
      return waitForScreenToLoad()
    }

    // Try navigation link from dashboard
    let widgetLink = app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'View Analytics' OR label CONTAINS 'Analytics'"
    )).firstMatch
    if widgetLink.waitForExistence(timeout: 5) {
      widgetLink.tap()
    }
    return waitForScreenToLoad()
  }

  // MARK: - Wait Helpers

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    // Check for stat cards (primary success indicator)
    let hasStats = allStatCards.firstMatch.waitForExistence(timeout: 10)
    if hasStats { return true }

    // Check for empty state
    let hasEmpty = emptyStateLabel.waitForExistence(timeout: 3)
    if hasEmpty { return true }

    // Check for error state
    let hasError = retryButton.waitForExistence(timeout: 3)
    return hasError
  }

  func waitForChartsToLoad() -> Bool {
    allCharts.firstMatch.waitForExistence(timeout: 15)
  }

  func waitForExportSheet() -> Bool {
    exportSheetTitle.waitForExistence(timeout: 5)
  }

  func waitForExportShareSheet() -> Bool {
    shareSheet.waitForExistence(timeout: 10)
  }

  // MARK: - Export Actions

  func openExportSheet() {
    guard exportToolbarButton.waitForExistence(timeout: 3) else { return }
    exportToolbarButton.tap()
  }

  func tapExportCSV() {
    guard exportCSVButton.waitForExistence(timeout: 3) else { return }
    exportCSVButton.tap()
  }

  func tapExportExcel() {
    guard exportExcelButton.waitForExistence(timeout: 3) else { return }
    exportExcelButton.tap()
  }

  func tapExportPDF() {
    guard exportPDFButton.waitForExistence(timeout: 3) else { return }
    exportPDFButton.tap()
  }

  func dismissExportSheet() {
    guard exportCancelButton.waitForExistence(timeout: 3) else { return }
    exportCancelButton.tap()
  }

  func dismissShareSheet() {
    let closeButton = app.buttons["Close"]
    if closeButton.waitForExistence(timeout: 3) {
      closeButton.tap()
    } else {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }
  }

  // MARK: - Chart Interaction

  func tapChart(_ chart: XCUIElement) {
    guard chart.waitForExistence(timeout: 5) else { return }
    chart.tap()
  }

  // MARK: - Scroll Helpers

  func scrollToExportButtons() {
    // Scroll down until export toolbar button is visible
    for _ in 0..<5 {
      if exportToolbarButton.exists { return }
      scrollDown()
    }
  }

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

  func hasStatsLoaded() -> Bool {
    allStatCards.count > 0
  }

  func hasChartsLoaded() -> Bool {
    allCharts.count > 0
  }

  func verifyEmptyState() -> Bool {
    emptyStateLabel.exists
  }

  func verifyErrorState() -> Bool {
    errorMessage.exists || retryButton.exists
  }
}
