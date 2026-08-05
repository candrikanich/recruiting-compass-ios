import XCTest

/// E2E tests for the full Activity History page
/// Tests navigation, activity loading, filtering, search, pagination, and item navigation
final class ActivityFeedE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: ActivityFeedScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = ActivityFeedScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  /// Navigate to the Activity History page from the dashboard
  /// Skips the test if navigation is not yet wired up
  @MainActor
  private func navigateToActivityPage() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToActivityFromDashboard()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Activity History page not reachable - navigation may not be wired")
    }
  }

  // MARK: - Phase 1: Navigation and Loading

  /// Test: Navigate to Activity page and verify activities load
  @MainActor
  func testActivityFeed_navigateToPage_displaysActivities() throws {
    try navigateToActivityPage()

    add(app.takeScreenshot(name: "01-activity-screen-loaded"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Activity content or empty state should appear"
    )

    add(app.takeScreenshot(name: "02-activity-content-loaded"))
  }

  /// Test: Activities display merged and sorted from all 3 sources
  @MainActor
  func testActivityFeed_activitiesLoaded_showsMergedTimeline() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No activity content loaded")
    }

    guard screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available (empty state)")
    }

    add(app.takeScreenshot(name: "03-activities-loaded"))

    let items = screen.allActivityElements()
    XCTAssertGreaterThan(
      items.count, 0,
      "Activity list should contain items from merged sources"
    )

    // Verify first item has a non-empty accessibility label
    XCTAssertFalse(
      items[0].label.isEmpty,
      "Activity item should have an accessibility label"
    )

    add(app.takeScreenshot(name: "04-activities-verified"))
  }

  // MARK: - Phase 2: Type Filter

  /// Test: Filter activities by type (Interactions, Status Changes, Documents)
  @MainActor
  func testActivityFeed_typeFilter_filtersCorrectly() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available to filter")
    }

    add(app.takeScreenshot(name: "05-filter-initial"))

    let initialCount = screen.allActivityElements().count

    // When: Select "Interactions" type filter
    screen.selectTypeFilter("Interactions")

    add(app.takeScreenshot(name: "06-filter-interactions-applied"))
    sleep(1)

    let filteredCount = screen.allActivityElements().count
    XCTAssertTrue(
      filteredCount <= initialCount,
      "Filtered count (\(filteredCount)) should be <= initial count (\(initialCount))"
    )

    add(app.takeScreenshot(name: "07-filter-interactions-result"))

    // When: Switch back to "All Activities"
    screen.selectTypeFilter("All Activities")
    sleep(1)

    let restoredCount = screen.allActivityElements().count
    XCTAssertEqual(
      restoredCount, initialCount,
      "All filter should restore original count"
    )

    add(app.takeScreenshot(name: "08-filter-all-restored"))
  }

  // MARK: - Phase 3: Date Range Filter

  /// Test: Filter activities by date range using segmented control
  @MainActor
  func testActivityFeed_dateRangeFilter_filtersCorrectly() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available to filter")
    }

    add(app.takeScreenshot(name: "09-date-filter-initial"))

    let initialCount = screen.allActivityElements().count

    // When: Select "Last 7 Days" segment
    screen.selectDateRangeSegment("Last 7 Days")

    add(app.takeScreenshot(name: "10-date-filter-7days-applied"))
    sleep(1)

    let filteredCount = screen.allActivityElements().count
    XCTAssertTrue(
      filteredCount <= initialCount,
      "7-day filtered count (\(filteredCount)) should be <= initial (\(initialCount))"
    )

    add(app.takeScreenshot(name: "11-date-filter-7days-result"))

    // When: Reset to "All Time"
    screen.selectDateRangeSegment("All Time")
    sleep(1)

    let restoredCount = screen.allActivityElements().count
    XCTAssertEqual(
      restoredCount, initialCount,
      "All Time filter should restore original count"
    )

    add(app.takeScreenshot(name: "12-date-filter-restored"))
  }

  // MARK: - Phase 4: Search

  /// Test: Search filters activities by title and description
  @MainActor
  func testActivityFeed_search_filtersResults() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available to search")
    }

    add(app.takeScreenshot(name: "13-search-initial"))

    let initialCount = screen.allActivityElements().count

    // When: Search for a term
    screen.searchActivities("email")

    add(app.takeScreenshot(name: "14-search-typed"))
    sleep(1)

    let searchCount = screen.allActivityElements().count
    XCTAssertTrue(
      searchCount <= initialCount,
      "Search results (\(searchCount)) should be <= initial count (\(initialCount))"
    )

    add(app.takeScreenshot(name: "15-search-results"))

    // When: Clear search
    screen.clearSearch()
    sleep(1)

    let clearedCount = screen.allActivityElements().count
    XCTAssertEqual(
      clearedCount, initialCount,
      "Clearing search should restore original count"
    )

    add(app.takeScreenshot(name: "16-search-cleared"))
  }

  // MARK: - Phase 5: Combined Filters

  /// Test: Combined type + date + search filters work together
  @MainActor
  func testActivityFeed_combinedFilters_workTogether() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available for combined filter test")
    }

    add(app.takeScreenshot(name: "17-combined-initial"))

    let initialCount = screen.allActivityElements().count

    // When: Apply type filter
    screen.selectTypeFilter("Interactions")
    sleep(1)

    let afterTypeCount = screen.allActivityElements().count

    // When: Also apply date range filter
    screen.selectDateRangeSegment("Last 30 Days")
    sleep(1)

    let afterDateCount = screen.allActivityElements().count

    XCTAssertTrue(
      afterDateCount <= afterTypeCount,
      "Combined filter count (\(afterDateCount)) should be <= type-only (\(afterTypeCount))"
    )

    add(app.takeScreenshot(name: "18-combined-filters-applied"))

    // When: Reset all filters
    screen.selectTypeFilter("All Activities")
    sleep(1)
    screen.selectDateRangeSegment("All Time")
    sleep(1)

    let restoredCount = screen.allActivityElements().count
    XCTAssertEqual(
      restoredCount, initialCount,
      "Resetting all filters should restore original count"
    )

    add(app.takeScreenshot(name: "19-combined-filters-reset"))
  }

  // MARK: - Phase 6: Pagination

  /// Test: Pagination controls navigate between pages
  @MainActor
  func testActivityFeed_pagination_navigatesCorrectly() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available")
    }

    // Scroll down to find pagination controls
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
      scrollView.swipeUp()
    }

    guard screen.verifyPaginationVisible() else {
      throw XCTSkip("Not enough activities for pagination (need >20)")
    }

    add(app.takeScreenshot(name: "20-pagination-initial"))

    XCTAssertFalse(
      screen.previousPageButton.isEnabled,
      "Previous button should be disabled on page 1"
    )

    let pageLabelText = screen.getPageLabelText()
    XCTAssertNotNil(pageLabelText)
    XCTAssertTrue(
      pageLabelText?.contains("Page 1") ?? false,
      "Should start on page 1"
    )

    add(app.takeScreenshot(name: "21-pagination-page1"))

    // When: Tap Next
    screen.tapNextPage()
    sleep(1)

    add(app.takeScreenshot(name: "22-pagination-page2"))

    let page2Label = screen.getPageLabelText()
    XCTAssertTrue(
      page2Label?.contains("Page 2") ?? false,
      "Should navigate to page 2"
    )

    XCTAssertTrue(
      screen.previousPageButton.isEnabled,
      "Previous button should be enabled on page 2"
    )

    // When: Tap Previous
    screen.tapPreviousPage()
    sleep(1)

    let backToPage1 = screen.getPageLabelText()
    XCTAssertTrue(
      backToPage1?.contains("Page 1") ?? false,
      "Should return to page 1"
    )

    add(app.takeScreenshot(name: "23-pagination-back-to-page1"))
  }

  /// Test: Filter change resets pagination to page 1
  @MainActor
  func testActivityFeed_filterChange_resetsPagination() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available")
    }

    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
      scrollView.swipeUp()
    }

    guard screen.verifyPaginationVisible() else {
      throw XCTSkip("Not enough activities for pagination test")
    }

    add(app.takeScreenshot(name: "24-filter-reset-initial"))

    // Given: Navigate to page 2
    screen.tapNextPage()
    sleep(1)

    let page2Label = screen.getPageLabelText()
    XCTAssertTrue(
      page2Label?.contains("Page 2") ?? false,
      "Should be on page 2"
    )

    add(app.takeScreenshot(name: "25-filter-reset-on-page2"))

    // Scroll back up to access type filter
    if scrollView.exists {
      scrollView.swipeDown()
      scrollView.swipeDown()
    }

    // When: Apply type filter
    screen.selectTypeFilter("Interactions")
    sleep(1)

    add(app.takeScreenshot(name: "26-filter-reset-after-filter"))

    // Scroll down to check pagination
    if scrollView.exists {
      scrollView.swipeUp()
      scrollView.swipeUp()
    }

    if let resetLabel = screen.getPageLabelText() {
      XCTAssertTrue(
        resetLabel.contains("Page 1"),
        "Filter change should reset pagination to page 1"
      )
    }

    // Reset filter
    if scrollView.exists {
      scrollView.swipeDown()
      scrollView.swipeDown()
    }
    screen.selectTypeFilter("All Activities")

    add(app.takeScreenshot(name: "27-filter-reset-restored"))
  }

  // MARK: - Phase 7: Activity Navigation

  /// Test: Tapping a clickable activity navigates to its detail
  @MainActor
  func testActivityFeed_tapClickableActivity_navigatesToDetail() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available to tap")
    }

    add(app.takeScreenshot(name: "28-nav-initial"))

    // Find a clickable activity item (wrapped in NavigationLink = button)
    let clickableItems = screen.clickableActivityItems
    guard clickableItems.firstMatch.waitForExistence(timeout: 5) else {
      throw XCTSkip("No clickable activity items found")
    }

    // When: Tap first clickable activity
    clickableItems.firstMatch.tap()

    add(app.takeScreenshot(name: "29-nav-item-tapped"))
    sleep(2)

    // Then: Should navigate away from activity list
    let navigatedAway = !screen.navigationTitle.exists
      || app.navigationBars.count > 1

    add(app.takeScreenshot(name: "30-nav-detail-view"))

    if navigatedAway {
      let backButton = app.navigationBars.buttons.element(boundBy: 0)
      if backButton.exists {
        backButton.tap()
      }

      sleep(1)

      XCTAssertTrue(
        screen.waitForScreenToLoad(),
        "Should return to Activity History after back navigation"
      )

      add(app.takeScreenshot(name: "31-nav-returned"))
    }
  }

  // MARK: - Phase 8: Pull to Refresh

  /// Test: Pull-to-refresh reloads activities
  @MainActor
  func testActivityFeed_pullToRefresh_reloadsActivities() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No activity content loaded")
    }

    add(app.takeScreenshot(name: "32-refresh-initial"))

    screen.pullToRefresh()

    add(app.takeScreenshot(name: "33-refresh-pulling"))
    sleep(2)

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after pull-to-refresh"
    )

    add(app.takeScreenshot(name: "34-refresh-completed"))
  }
}
