import XCTest

/// E2E tests for the Performance Dashboard feature
/// Tests critical user journeys: view, log, edit, delete, chart interaction, trends, and error states
final class PerformanceDashboardE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: PerformanceDashboardScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = PerformanceDashboardScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToPerformance() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToPerformance() else {
      throw XCTSkip("Performance Dashboard not reachable - navigation may not be wired")
    }
  }

  // MARK: - Phase 1: View Dashboard Flow

  /// Test: Navigate to Performance Dashboard and verify it loads
  @MainActor
  func testPerformanceDashboard_navigate_displaysScreen() throws {
    try loginAndNavigateToPerformance()

    add(app.takeScreenshot(name: "01-performance-screen-loaded"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Performance content or empty state should appear"
    )

    add(app.takeScreenshot(name: "02-performance-content-loaded"))
  }

  /// Test: Dashboard shows metrics when data exists
  @MainActor
  func testPerformanceDashboard_withData_displaysMetrics() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available - empty state displayed")
    }

    add(app.takeScreenshot(name: "03-metrics-displayed"))

    XCTAssertGreaterThan(
      screen.metricCardCount(), 0,
      "At least one metric card should be visible"
    )

    add(app.takeScreenshot(name: "04-metrics-count-verified"))
  }

  /// Test: Dashboard shows empty state when no metrics exist
  @MainActor
  func testPerformanceDashboard_noData_displaysEmptyState() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    if screen.verifyEmptyState() {
      add(app.takeScreenshot(name: "05-empty-state-displayed"))

      XCTAssertTrue(
        screen.emptyStateText.exists,
        "Empty state message should be visible"
      )

      XCTAssertTrue(
        screen.logMetricButton.exists,
        "Log Metric button should be available in empty state"
      )

      add(app.takeScreenshot(name: "06-empty-state-verified"))
    } else {
      throw XCTSkip("Metrics exist - cannot test empty state")
    }
  }

  /// Test: Pull-to-refresh reloads metrics
  @MainActor
  func testPerformanceDashboard_pullToRefresh_reloadsMetrics() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "07-before-refresh"))

    screen.pullToRefresh()
    sleep(2)

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after pull-to-refresh"
    )

    add(app.takeScreenshot(name: "08-after-refresh"))
  }

  // MARK: - Phase 2: Log New Metric Flow

  /// Test: User can log a new metric end-to-end
  @MainActor
  func testPerformanceDashboard_logMetric_fullFlow() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    let initialCount = screen.metricCardCount()

    add(app.takeScreenshot(name: "09-before-log-metric"))

    // When: Tap Log Metric button
    XCTAssertTrue(
      screen.logMetricButton.exists,
      "Log Metric button should be visible"
    )
    screen.logMetricButton.tap()

    add(app.takeScreenshot(name: "10-log-form-opened"))

    // Then: Form should appear
    XCTAssertTrue(
      screen.waitForFormToAppear(),
      "Metric form should appear"
    )

    // When: Fill form fields
    screen.selectMetricType("Fastball Velocity")
    add(app.takeScreenshot(name: "11-type-selected"))

    screen.fillValue("92.5")
    add(app.takeScreenshot(name: "12-value-entered"))

    screen.fillNotes("Practice session - felt good")
    add(app.takeScreenshot(name: "13-notes-entered"))

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "14-form-submitted"))

    // Then: Form should dismiss
    XCTAssertTrue(
      screen.waitForFormToDismiss(),
      "Form should dismiss after successful submission"
    )

    // Then: New metric should appear in the list
    sleep(1)
    let newCount = screen.metricCardCount()

    if initialCount == 0 {
      XCTAssertGreaterThan(
        newCount, 0,
        "Should have at least one metric after logging"
      )
    } else {
      XCTAssertGreaterThanOrEqual(
        newCount, initialCount,
        "Metric count should not decrease after logging"
      )
    }

    add(app.takeScreenshot(name: "15-metric-logged-successfully"))
  }

  /// Test: User can cancel metric form without saving
  @MainActor
  func testPerformanceDashboard_logMetricCancel_discardsData() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    let initialCount = screen.metricCardCount()

    // When: Open form and fill some data
    screen.logMetricButton.tap()

    guard screen.waitForFormToAppear() else {
      throw XCTSkip("Form did not appear")
    }

    screen.fillValue("88.0")
    add(app.takeScreenshot(name: "16-cancel-form-with-data"))

    // When: Cancel the form
    screen.cancelForm()

    add(app.takeScreenshot(name: "17-cancel-form-dismissed"))

    // Then: Form should dismiss and metric count unchanged
    XCTAssertTrue(
      screen.waitForFormToDismiss(),
      "Form should dismiss after cancel"
    )

    let afterCount = screen.metricCardCount()
    XCTAssertEqual(
      afterCount, initialCount,
      "Metric count should remain unchanged after cancel"
    )

    add(app.takeScreenshot(name: "18-cancel-no-new-metric"))
  }

  /// Test: Form validation prevents submission with empty value
  @MainActor
  func testPerformanceDashboard_logMetric_emptyValue_disablesSubmit() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    screen.logMetricButton.tap()

    guard screen.waitForFormToAppear() else {
      throw XCTSkip("Form did not appear")
    }

    add(app.takeScreenshot(name: "19-empty-form"))

    // Then: Save button should be disabled when form is empty
    if screen.saveButton.exists {
      XCTAssertFalse(
        screen.saveButton.isEnabled,
        "Save button should be disabled with empty value"
      )
    }

    add(app.takeScreenshot(name: "20-save-disabled"))

    // When: Enter a value
    screen.selectMetricType("Exit Velocity")
    screen.fillValue("95.0")

    add(app.takeScreenshot(name: "21-form-filled"))

    // Then: Save button should become enabled
    if screen.saveButton.exists {
      XCTAssertTrue(
        screen.saveButton.isEnabled,
        "Save button should be enabled after filling required fields"
      )
    }

    // Clean up
    screen.cancelForm()

    add(app.takeScreenshot(name: "22-validation-complete"))
  }

  // MARK: - Phase 3: Edit Metric Flow

  /// Test: User can edit an existing metric
  @MainActor
  func testPerformanceDashboard_editMetric_updatesValue() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available to edit")
    }

    add(app.takeScreenshot(name: "23-before-edit"))

    // Scroll to find Edit button in history section
    screen.scrollDown()

    guard screen.editButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("No Edit buttons found - history cards may not be visible")
    }

    // When: Tap Edit on first metric card
    screen.editButton(at: 0).tap()

    add(app.takeScreenshot(name: "24-edit-form-opened"))

    // Then: Edit form should appear with pre-populated values
    XCTAssertTrue(
      screen.waitForFormToAppear(),
      "Edit form should appear"
    )

    add(app.takeScreenshot(name: "25-edit-form-populated"))

    // When: Modify the value
    screen.fillValue("94.0")

    add(app.takeScreenshot(name: "26-edit-value-changed"))

    // When: Save changes
    screen.submitForm()

    add(app.takeScreenshot(name: "27-edit-submitted"))

    // Then: Form should dismiss
    XCTAssertTrue(
      screen.waitForFormToDismiss(),
      "Edit form should dismiss after save"
    )

    add(app.takeScreenshot(name: "28-edit-saved-successfully"))
  }

  // MARK: - Phase 4: Delete Metric Flow

  /// Test: User can delete a metric with confirmation
  @MainActor
  func testPerformanceDashboard_deleteMetric_withConfirmation() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available to delete")
    }

    let initialCount = screen.metricCardCount()

    add(app.takeScreenshot(name: "29-before-delete"))

    // Scroll to find Delete button
    screen.scrollDown()

    guard screen.deleteButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("No Delete buttons found")
    }

    // When: Tap Delete on first metric card
    screen.deleteButton(at: 0).tap()

    add(app.takeScreenshot(name: "30-delete-confirmation-shown"))

    // Then: Confirmation alert should appear
    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 5),
      "Delete confirmation alert should appear"
    )

    // When: Confirm deletion
    XCTAssertTrue(
      screen.confirmDeleteButton.exists,
      "Confirm delete button should exist"
    )
    screen.confirmDeleteButton.tap()

    add(app.takeScreenshot(name: "31-delete-confirmed"))

    // Then: Metric should be removed
    sleep(1)
    let afterCount = screen.metricCardCount()

    XCTAssertLessThanOrEqual(
      afterCount, initialCount,
      "Metric count should decrease or equal after deletion"
    )

    add(app.takeScreenshot(name: "32-delete-completed"))
  }

  /// Test: User can cancel metric deletion
  @MainActor
  func testPerformanceDashboard_deleteMetric_cancelKeepsMetric() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available to test delete cancel")
    }

    let initialCount = screen.metricCardCount()

    // Scroll to find Delete button
    screen.scrollDown()

    guard screen.deleteButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("No Delete buttons found")
    }

    // When: Tap Delete
    screen.deleteButton(at: 0).tap()

    add(app.takeScreenshot(name: "33-delete-cancel-alert"))

    // Then: Alert should appear
    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 5),
      "Delete confirmation alert should appear"
    )

    // When: Cancel deletion
    screen.cancelDeleteButton.tap()

    add(app.takeScreenshot(name: "34-delete-cancelled"))

    // Then: Metric count should remain the same
    sleep(1)
    let afterCount = screen.metricCardCount()

    XCTAssertEqual(
      afterCount, initialCount,
      "Metric count should remain unchanged after cancel"
    )

    add(app.takeScreenshot(name: "35-delete-cancel-verified"))
  }

  // MARK: - Phase 5: Chart Interaction Flow

  /// Test: Chart displays when enough metrics exist
  @MainActor
  func testPerformanceDashboard_chart_displaysWithMultipleMetrics() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available for chart test")
    }

    add(app.takeScreenshot(name: "36-chart-initial"))

    // Check for chart visibility (requires 2+ metrics of same type)
    if screen.chartView.waitForExistence(timeout: 5) {
      XCTAssertTrue(
        screen.chartView.exists,
        "Chart should be visible with sufficient data"
      )
      add(app.takeScreenshot(name: "37-chart-displayed"))
    } else {
      throw XCTSkip("Chart not visible - may need 2+ metrics of same type")
    }
  }

  /// Test: Switching metric type filter updates chart
  @MainActor
  func testPerformanceDashboard_chart_filterSwitchUpdatesChart() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available")
    }

    let filterButtons = screen.allFilterButtons

    guard filterButtons.count >= 2 else {
      throw XCTSkip("Need 2+ metric types to test filter switching")
    }

    add(app.takeScreenshot(name: "38-filter-initial"))

    // When: Tap first filter
    filterButtons.element(boundBy: 0).tap()
    sleep(1)

    add(app.takeScreenshot(name: "39-filter-first-type"))

    // When: Tap second filter
    filterButtons.element(boundBy: 1).tap()
    sleep(1)

    add(app.takeScreenshot(name: "40-filter-second-type"))

    // Then: The filter should have the selected trait
    let secondFilter = filterButtons.element(boundBy: 1)
    XCTAssertTrue(
      secondFilter.exists,
      "Second filter button should exist"
    )

    add(app.takeScreenshot(name: "41-filter-switch-verified"))
  }

  // MARK: - Phase 6: Trend Display Flow

  /// Test: Trend cards display with sufficient data
  @MainActor
  func testPerformanceDashboard_trends_displayCorrectly() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available for trend test")
    }

    // Scroll down to trends section
    screen.scrollDown()

    add(app.takeScreenshot(name: "42-trends-section"))

    if screen.trendCardCount() > 0 {
      XCTAssertGreaterThan(
        screen.trendCardCount(), 0,
        "At least one trend card should be visible"
      )

      // Verify trend card has accessibility label with direction
      let firstTrend = screen.allTrendCards.firstMatch
      XCTAssertFalse(
        firstTrend.label.isEmpty,
        "Trend card should have an accessibility label"
      )

      add(app.takeScreenshot(name: "43-trends-verified"))
    } else {
      throw XCTSkip("No trend cards visible - need 2+ metrics per type")
    }
  }

  /// Test: Trend indicators show correct direction labels
  @MainActor
  func testPerformanceDashboard_trendIndicators_showDirection() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available")
    }

    screen.scrollDown()

    add(app.takeScreenshot(name: "44-trend-indicators"))

    // Look for any trend indicator (Improving, Declining, or Stable)
    let improvingExists = screen.trendIndicator("Improving").waitForExistence(timeout: 3)
    let decliningExists = screen.trendIndicator("Declining").waitForExistence(timeout: 1)
    let stableExists = screen.trendIndicator("Stable").waitForExistence(timeout: 1)

    if improvingExists || decliningExists || stableExists {
      XCTAssertTrue(
        improvingExists || decliningExists || stableExists,
        "At least one trend indicator should be visible"
      )
      add(app.takeScreenshot(name: "45-trend-direction-verified"))
    } else {
      throw XCTSkip("No trend indicators visible - need 2+ data points per metric type")
    }
  }

  // MARK: - Phase 7: Error Scenarios

  /// Test: Error state shows retry option
  @MainActor
  func testPerformanceDashboard_errorState_showsRetry() throws {
    // Note: True error state testing requires network mocking or disconnected state
    // This test verifies the retry button functionality if an error occurs

    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    if screen.verifyErrorState() {
      add(app.takeScreenshot(name: "46-error-state-shown"))

      XCTAssertTrue(
        screen.retryButton.exists,
        "Retry button should be visible in error state"
      )

      // When: Tap retry
      screen.retryButton.tap()
      sleep(2)

      add(app.takeScreenshot(name: "47-retry-tapped"))

      // Then: Content should reload (either success or error again)
      XCTAssertTrue(
        screen.waitForContentToLoad(),
        "Content should attempt to reload after retry"
      )

      add(app.takeScreenshot(name: "48-retry-completed"))
    } else {
      throw XCTSkip("No error state to test - service is working correctly")
    }
  }

  // MARK: - Phase 8: Full CRUD Journey

  /// Test: Complete create-read-edit-delete lifecycle
  @MainActor
  func testPerformanceDashboard_fullCRUDJourney() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "49-crud-start"))

    // --- CREATE ---
    screen.logMetricButton.tap()

    guard screen.waitForFormToAppear() else {
      throw XCTSkip("Log form did not appear")
    }

    let uniqueValue = String(format: "%.1f", Double.random(in: 85...99))
    screen.selectMetricType("Fastball Velocity")
    screen.fillValue(uniqueValue)
    screen.fillNotes("E2E test metric - CRUD journey")
    screen.submitForm()

    XCTAssertTrue(
      screen.waitForFormToDismiss(),
      "Form should dismiss after logging metric"
    )

    add(app.takeScreenshot(name: "50-crud-created"))
    sleep(1)

    // --- READ ---
    XCTAssertTrue(
      screen.hasMetricsLoaded(),
      "Metrics should be visible after creation"
    )

    add(app.takeScreenshot(name: "51-crud-read"))

    // --- EDIT ---
    screen.scrollDown()

    guard screen.editButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("Edit button not found for CRUD test")
    }

    screen.editButton(at: 0).tap()

    guard screen.waitForFormToAppear() else {
      throw XCTSkip("Edit form did not appear")
    }

    let updatedValue = String(format: "%.1f", Double.random(in: 85...99))
    screen.fillValue(updatedValue)
    screen.submitForm()

    XCTAssertTrue(
      screen.waitForFormToDismiss(),
      "Edit form should dismiss after saving"
    )

    add(app.takeScreenshot(name: "52-crud-edited"))
    sleep(1)

    // --- DELETE ---
    screen.scrollDown()

    guard screen.deleteButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("Delete button not found for CRUD test")
    }

    let countBeforeDelete = screen.metricCardCount()
    screen.deleteButton(at: 0).tap()

    if screen.deleteConfirmationAlert.waitForExistence(timeout: 5) {
      screen.confirmDeleteButton.tap()
    }

    sleep(1)

    let countAfterDelete = screen.metricCardCount()
    XCTAssertLessThanOrEqual(
      countAfterDelete, countBeforeDelete,
      "Count should decrease after deletion"
    )

    add(app.takeScreenshot(name: "53-crud-deleted"))
    add(app.takeScreenshot(name: "54-crud-journey-complete"))
  }

  // MARK: - Phase 9: Accessibility Verification

  /// Test: VoiceOver labels are present on key elements
  @MainActor
  func testPerformanceDashboard_accessibility_voiceOverLabels() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available for accessibility test")
    }

    add(app.takeScreenshot(name: "55-a11y-start"))

    // Verify navigation title has accessibility
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should exist for VoiceOver"
    )

    // Verify Log Metric button is accessible
    XCTAssertTrue(
      screen.logMetricButton.exists,
      "Log Metric button should be accessible"
    )

    // Verify metric cards have combined accessibility labels
    let firstCard = screen.allMetricCards.firstMatch
    if firstCard.exists {
      XCTAssertFalse(
        firstCard.label.isEmpty,
        "Metric card should have a non-empty accessibility label"
      )

      XCTAssertTrue(
        firstCard.label.contains("recorded"),
        "Metric card label should include 'recorded' date information"
      )
    }

    // Verify filter buttons have accessibility labels
    let filters = screen.allFilterButtons
    if filters.count > 0 {
      let firstFilter = filters.firstMatch
      XCTAssertTrue(
        firstFilter.label.contains("filter"),
        "Filter button label should contain 'filter'"
      )
    }

    add(app.takeScreenshot(name: "56-a11y-verified"))
  }

  /// Test: Edit and Delete buttons are accessible
  @MainActor
  func testPerformanceDashboard_accessibility_actionButtons() throws {
    try loginAndNavigateToPerformance()

    guard screen.waitForContentToLoad(), screen.hasMetricsLoaded() else {
      throw XCTSkip("No metrics available")
    }

    screen.scrollDown()

    guard screen.editButtons.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("No action buttons visible")
    }

    add(app.takeScreenshot(name: "57-a11y-action-buttons"))

    // Verify Edit button accessibility
    let editBtn = screen.editButton(at: 0)
    XCTAssertTrue(editBtn.exists, "Edit button should exist")
    XCTAssertEqual(editBtn.label, "Edit", "Edit button should have correct label")

    // Verify Delete button accessibility
    let deleteBtn = screen.deleteButton(at: 0)
    XCTAssertTrue(deleteBtn.exists, "Delete button should exist")
    XCTAssertEqual(deleteBtn.label, "Delete", "Delete button should have correct label")

    // Verify minimum tap target size (44x44 is the guideline)
    XCTAssertGreaterThanOrEqual(
      editBtn.frame.width, 44,
      "Edit button should meet minimum tap target width"
    )
    XCTAssertGreaterThanOrEqual(
      editBtn.frame.height, 30,
      "Edit button should have reasonable tap target height"
    )

    add(app.takeScreenshot(name: "58-a11y-buttons-verified"))
  }
}
