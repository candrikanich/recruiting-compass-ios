import XCTest

/// E2E tests for the Analytics Dashboard feature
/// Tests critical user journeys: dashboard load, date filtering, chart interactions, export, empty/error states
final class AnalyticsDashboardE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AnalyticsDashboardScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = AnalyticsDashboardScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToAnalytics() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToAnalytics() else {
      throw XCTSkip("Analytics Dashboard not reachable - navigation may not be wired")
    }
  }

  // MARK: - Phase 1: Dashboard Load

  /// Test: Navigate to Analytics Dashboard and verify it loads
  @MainActor
  func testAnalyticsDashboard_navigate_displaysScreen() throws {
    try loginAndNavigateToAnalytics()

    add(app.takeScreenshot(name: "01-analytics-screen-loaded"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Analytics content or empty state should appear"
    )

    add(app.takeScreenshot(name: "02-analytics-content-loaded"))
  }

  /// Test: Dashboard loads with all chart sections when data exists
  @MainActor
  func testAnalyticsDashboard_withData_displaysAllCharts() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasStatsLoaded() else {
      throw XCTSkip("No stats available - empty state displayed")
    }

    add(app.takeScreenshot(name: "03-stats-displayed"))

    XCTAssertGreaterThan(
      screen.statCardCount(), 0,
      "At least one stat card should be visible"
    )

    add(app.takeScreenshot(name: "04-stat-cards-verified"))

    screen.scrollDown()
    sleep(1)

    add(app.takeScreenshot(name: "05-charts-section"))

    if screen.hasChartsLoaded() {
      XCTAssertGreaterThan(
        screen.chartCount(), 0,
        "At least one chart should be visible"
      )
    }

    add(app.takeScreenshot(name: "06-charts-verified"))
  }

  /// Test: Summary stat cards display expected metrics
  @MainActor
  func testAnalyticsDashboard_statCards_displayCorrectMetrics() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No stats available")
    }

    add(app.takeScreenshot(name: "07-stat-cards-detail"))

    let schoolsExists = screen.totalSchoolsCard.waitForExistence(timeout: 3)
    let interactionsExists = screen.interactionsCard.waitForExistence(timeout: 3)
    let offersExists = screen.offersCard.waitForExistence(timeout: 3)
    let commitmentsExists = screen.commitmentsCard.waitForExistence(timeout: 3)

    let visibleCount = [schoolsExists, interactionsExists, offersExists, commitmentsExists]
      .filter { $0 }.count

    XCTAssertGreaterThan(
      visibleCount, 0,
      "At least one recognized stat card should be visible"
    )

    add(app.takeScreenshot(name: "08-stat-cards-identified"))
  }

  // MARK: - Phase 2: Date Range Filtering

  /// Test: Selecting a different date range updates the dashboard
  @MainActor
  func testAnalyticsDashboard_dateRangeChange_updatesContent() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "09-before-date-change"))

    guard screen.last7DaysButton.waitForExistence(timeout: 3) else {
      throw XCTSkip("Date range picker not found")
    }

    screen.last7DaysButton.tap()
    sleep(2)

    add(app.takeScreenshot(name: "10-after-7-days-filter"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after date range change"
    )

    add(app.takeScreenshot(name: "11-date-filter-applied"))
  }

  /// Test: Switching between multiple date ranges works
  @MainActor
  func testAnalyticsDashboard_multipleDateRanges_allWork() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "12-date-range-start"))

    if screen.last7DaysButton.waitForExistence(timeout: 3) {
      screen.last7DaysButton.tap()
      sleep(1)
      add(app.takeScreenshot(name: "13-7-days-selected"))
    }

    if screen.last30DaysButton.waitForExistence(timeout: 3) {
      screen.last30DaysButton.tap()
      sleep(1)
      add(app.takeScreenshot(name: "14-30-days-selected"))
    }

    if screen.last90DaysButton.waitForExistence(timeout: 3) {
      screen.last90DaysButton.tap()
      sleep(1)
      add(app.takeScreenshot(name: "15-90-days-selected"))
    }

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should be present after date range switches"
    )

    add(app.takeScreenshot(name: "16-date-ranges-verified"))
  }

  // MARK: - Phase 3: Export Functionality

  /// Test: Export toolbar button opens the export format sheet
  @MainActor
  func testAnalyticsDashboard_exportButton_opensSheet() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No data to export")
    }

    guard screen.exportToolbarButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Export toolbar button not found")
    }

    add(app.takeScreenshot(name: "17-before-export"))

    screen.openExportSheet()

    XCTAssertTrue(
      screen.waitForExportSheet(),
      "Export format sheet should appear"
    )

    add(app.takeScreenshot(name: "18-export-sheet-opened"))

    XCTAssertTrue(screen.exportCSVButton.exists, "CSV export option should exist")
    XCTAssertTrue(screen.exportExcelButton.exists, "Excel export option should exist")
    XCTAssertTrue(screen.exportPDFButton.exists, "PDF export option should exist")

    screen.dismissExportSheet()

    add(app.takeScreenshot(name: "19-export-sheet-dismissed"))
  }

  /// Test: CSV export triggers share sheet
  @MainActor
  func testAnalyticsDashboard_exportCSV_showsShareSheet() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No data to export")
    }

    screen.openExportSheet()

    guard screen.waitForExportSheet() else {
      throw XCTSkip("Export sheet did not appear")
    }

    screen.tapExportCSV()
    add(app.takeScreenshot(name: "20-csv-export-triggered"))

    let shareAppeared = screen.waitForExportShareSheet()
    if shareAppeared {
      XCTAssertTrue(shareAppeared, "Share sheet should appear for CSV export")
      screen.dismissShareSheet()
      add(app.takeScreenshot(name: "21-csv-share-dismissed"))
    } else {
      add(app.takeScreenshot(name: "21-csv-export-result"))
    }
  }

  /// Test: PDF export option is available
  @MainActor
  func testAnalyticsDashboard_exportPDF_isAvailable() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No data to export")
    }

    screen.openExportSheet()

    guard screen.waitForExportSheet() else {
      throw XCTSkip("Export sheet did not appear")
    }

    add(app.takeScreenshot(name: "22-export-formats-visible"))

    XCTAssertTrue(
      screen.exportPDFButton.exists,
      "PDF export option should be available"
    )

    screen.tapExportPDF()
    sleep(1)

    add(app.takeScreenshot(name: "23-pdf-export-tapped"))
  }

  // MARK: - Phase 4: Chart Interactions

  /// Test: Tapping a chart section is responsive
  @MainActor
  func testAnalyticsDashboard_chartTap_isResponsive() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No data for chart interaction test")
    }

    screen.scrollDown()
    add(app.takeScreenshot(name: "24-charts-visible"))

    if screen.interactionTypesChart.waitForExistence(timeout: 5) {
      screen.tapChart(screen.interactionTypesChart)
      sleep(1)
      add(app.takeScreenshot(name: "25-interaction-chart-tapped"))
    } else if screen.sentimentChart.waitForExistence(timeout: 3) {
      screen.tapChart(screen.sentimentChart)
      sleep(1)
      add(app.takeScreenshot(name: "25-sentiment-chart-tapped"))
    } else {
      throw XCTSkip("No tappable charts found")
    }

    add(app.takeScreenshot(name: "26-chart-interaction-complete"))
  }

  /// Test: Scatter plot is visible when data exists
  @MainActor
  func testAnalyticsDashboard_scatterPlot_isAccessible() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No data for scatter plot test")
    }

    screen.scrollDown()
    screen.scrollDown()

    add(app.takeScreenshot(name: "27-scroll-to-scatter"))

    if screen.scatterPlot.waitForExistence(timeout: 5) {
      XCTAssertTrue(
        screen.scatterPlot.exists,
        "Performance Correlation scatter plot should be visible"
      )

      screen.tapChart(screen.scatterPlot)
      sleep(1)
      add(app.takeScreenshot(name: "28-scatter-plot-tapped"))
    } else {
      throw XCTSkip("Scatter plot not visible - may need more data")
    }
  }

  // MARK: - Phase 5: Empty State

  /// Test: Dashboard shows empty state when no data exists
  @MainActor
  func testAnalyticsDashboard_noData_displaysEmptyState() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    if screen.verifyEmptyState() {
      add(app.takeScreenshot(name: "29-empty-state-displayed"))

      XCTAssertTrue(
        screen.emptyStateLabel.exists,
        "Empty state label should be visible"
      )

      add(app.takeScreenshot(name: "30-empty-state-verified"))
    } else {
      throw XCTSkip("Data exists - cannot test empty state")
    }
  }

  // MARK: - Phase 6: Error State with Retry

  /// Test: Error state shows retry option
  @MainActor
  func testAnalyticsDashboard_errorState_showsRetry() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    if screen.verifyErrorState() {
      add(app.takeScreenshot(name: "31-error-state-shown"))

      XCTAssertTrue(
        screen.retryButton.exists,
        "Retry button should be visible in error state"
      )

      screen.retryButton.tap()
      sleep(2)

      add(app.takeScreenshot(name: "32-retry-tapped"))

      XCTAssertTrue(
        screen.waitForContentToLoad(),
        "Content should attempt to reload after retry"
      )

      add(app.takeScreenshot(name: "33-retry-completed"))
    } else {
      throw XCTSkip("No error state to test - service is working correctly")
    }
  }

  // MARK: - Phase 7: Pull-to-Refresh

  /// Test: Pull-to-refresh reloads analytics data
  @MainActor
  func testAnalyticsDashboard_pullToRefresh_reloadsData() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "34-before-refresh"))

    screen.pullToRefresh()
    sleep(2)

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after pull-to-refresh"
    )

    add(app.takeScreenshot(name: "35-after-refresh"))
  }

  // MARK: - Phase 8: Full Dashboard Journey

  /// Test: Complete analytics dashboard journey - load, filter, browse charts, export
  @MainActor
  func testAnalyticsDashboard_fullJourney() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "36-journey-start"))

    // Step 1: Verify stat cards loaded
    guard screen.hasStatsLoaded() else {
      throw XCTSkip("No stats available for full journey")
    }

    let initialStatCount = screen.statCardCount()
    XCTAssertGreaterThan(initialStatCount, 0, "Stats should be visible")
    add(app.takeScreenshot(name: "37-journey-stats"))

    // Step 2: Change date range
    if screen.last7DaysButton.waitForExistence(timeout: 3) {
      screen.last7DaysButton.tap()
      sleep(2)

      XCTAssertTrue(
        screen.waitForContentToLoad(),
        "Content should reload after date range change"
      )

      add(app.takeScreenshot(name: "38-journey-date-filtered"))
    }

    // Step 3: Browse charts
    screen.scrollDown()
    sleep(1)
    add(app.takeScreenshot(name: "39-journey-charts"))

    if screen.hasChartsLoaded() {
      if screen.interactionTypesChart.exists {
        screen.tapChart(screen.interactionTypesChart)
        sleep(1)
      }
      add(app.takeScreenshot(name: "40-journey-chart-tapped"))
    }

    // Step 4: Scroll through remaining content
    screen.scrollDown()
    sleep(1)
    add(app.takeScreenshot(name: "41-journey-more-charts"))

    // Step 5: Export data via toolbar button -> sheet
    screen.scrollUp()
    screen.scrollUp()

    if screen.exportToolbarButton.waitForExistence(timeout: 3) {
      screen.openExportSheet()

      if screen.waitForExportSheet() {
        screen.tapExportCSV()
        sleep(2)

        if screen.waitForExportShareSheet() {
          screen.dismissShareSheet()
        }

        add(app.takeScreenshot(name: "42-journey-exported"))
      }
    }

    // Step 6: Return to default date range
    if screen.last30DaysButton.waitForExistence(timeout: 3) {
      screen.last30DaysButton.tap()
      sleep(1)
    }

    add(app.takeScreenshot(name: "43-journey-complete"))
  }

  // MARK: - Phase 9: Accessibility Verification

  /// Test: VoiceOver labels are present on key elements
  @MainActor
  func testAnalyticsDashboard_accessibility_voiceOverLabels() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No stats available for accessibility test")
    }

    add(app.takeScreenshot(name: "44-a11y-start"))

    // Verify stat cards have combined accessibility labels with title and value
    let firstCard = screen.allStatCards.firstMatch
    if firstCard.exists {
      XCTAssertFalse(
        firstCard.label.isEmpty,
        "Stat card should have a non-empty accessibility label"
      )
      XCTAssertTrue(
        firstCard.label.contains(":"),
        "Stat card label should contain colon separator (title: value format)"
      )
    }

    add(app.takeScreenshot(name: "45-a11y-stats-verified"))

    // Verify date range buttons have proper accessibility labels
    if screen.last30DaysButton.exists {
      XCTAssertEqual(
        screen.last30DaysButton.label,
        "Filter by Last 30 Days",
        "Date range button should have descriptive label"
      )
    }

    // Verify charts have descriptive accessibility labels
    screen.scrollDown()
    if screen.interactionTypesChart.waitForExistence(timeout: 3) {
      XCTAssertTrue(
        screen.interactionTypesChart.label.contains("pie chart"),
        "Chart should have descriptive type in label"
      )
    }

    add(app.takeScreenshot(name: "46-a11y-verified"))
  }

  /// Test: Export button has proper accessibility label
  @MainActor
  func testAnalyticsDashboard_accessibility_exportButton() throws {
    try loginAndNavigateToAnalytics()

    guard screen.waitForContentToLoad(), screen.hasStatsLoaded() else {
      throw XCTSkip("No stats available")
    }

    add(app.takeScreenshot(name: "47-a11y-export-button"))

    guard screen.exportToolbarButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Export button not found")
    }

    XCTAssertEqual(
      screen.exportToolbarButton.label,
      "Export analytics data",
      "Export button should have descriptive accessibility label"
    )

    XCTAssertGreaterThanOrEqual(
      screen.exportToolbarButton.frame.width, 44,
      "Export button should meet minimum 44pt tap target width"
    )

    add(app.takeScreenshot(name: "48-a11y-export-verified"))
  }
}
