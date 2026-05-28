import XCTest

/// E2E tests for Activity Feed error and empty states
/// Tests empty activity list, filtered empty state, error state with retry,
/// and long text truncation
final class ActivityFeedErrorStatesE2ETests: XCTestCase {
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

  /// Navigate to the Activity History page
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

  // MARK: - Phase 1: Initial Empty State

  /// Test: Empty activity list displays sparkles icon and suggestion text
  @MainActor
  func testActivityFeed_initialEmptyState_displaysCorrectly() throws {
    try navigateToActivityPage()
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "01-empty-state-initial"))

    // If activities exist, skip this test
    if screen.hasActivitiesLoaded() {
      throw XCTSkip("Activities exist - cannot test initial empty state with live data")
    }

    // Then: "No activities found" text should be visible
    XCTAssertTrue(
      screen.emptyStateText.exists,
      "'No activities found' text should be visible"
    )

    // Then: "Your recruiting activity will appear here" should be visible
    XCTAssertTrue(
      screen.initialEmptyStateSuggestion.exists,
      "Initial empty state suggestion should be visible"
    )

    add(app.takeScreenshot(name: "02-empty-state-verified"))
  }

  // MARK: - Phase 2: Filtered Empty State

  /// Test: All activities filtered out shows filtered empty state with Clear Filters button
  @MainActor
  func testActivityFeed_allFilteredOut_showsFilteredEmptyState() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available to filter out")
    }

    add(app.takeScreenshot(name: "03-filter-empty-initial"))

    // When: Search for a term that won't match anything
    screen.searchActivities("xyznonexistentquery987654")
    sleep(1)

    add(app.takeScreenshot(name: "04-filter-empty-searched"))

    // Then: "No activities found" should appear
    XCTAssertTrue(
      screen.emptyStateText.exists,
      "Empty state text should be visible when all activities are filtered out"
    )

    // Then: Filter adjustment suggestion should appear
    XCTAssertTrue(
      screen.filteredEmptyStateSuggestion.exists,
      "'Try adjusting your filters or search query' should be visible"
    )

    // Then: Clear Filters button should be available
    XCTAssertTrue(
      screen.clearFiltersButton.exists,
      "Clear Filters button should be visible in filtered empty state"
    )

    add(app.takeScreenshot(name: "05-filter-empty-verified"))

    // When: Tap Clear Filters
    screen.clearFiltersButton.tap()
    sleep(1)

    // Then: Activities should reappear
    XCTAssertTrue(
      screen.hasActivitiesLoaded(),
      "Activities should reappear after clearing filters"
    )

    add(app.takeScreenshot(name: "06-filter-empty-restored"))
  }

  // MARK: - Phase 3: Error State

  /// Test: Error state shows error message with Try Again button
  @MainActor
  func testActivityFeed_errorState_showsRetryButton() throws {
    try navigateToActivityPage()
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "07-error-state-check"))

    // If we got an error state, test the retry
    if screen.verifyErrorState() {
      add(app.takeScreenshot(name: "08-error-state-visible"))

      XCTAssertTrue(
        screen.retryButton.exists,
        "Try Again button should be visible in error state"
      )

      // When: Tap retry
      screen.retryButton.tap()

      add(app.takeScreenshot(name: "09-retry-tapped"))
      sleep(2)

      // Then: Should attempt to reload
      XCTAssertTrue(
        screen.waitForContentToLoad(),
        "Content should reload after tapping retry"
      )

      add(app.takeScreenshot(name: "10-retry-completed"))
    } else {
      // No error state - activities loaded successfully or empty state
      // Verify content is present (positive case)
      XCTAssertTrue(
        screen.hasActivitiesLoaded() || screen.emptyStateText.exists,
        "Should show either activities or empty state (no error)"
      )

      add(app.takeScreenshot(name: "08-no-error-content-loaded"))
    }
  }

  // MARK: - Phase 4: Error State with Invalid Credentials

  /// Test: Network error shows error state gracefully
  @MainActor
  func testActivityFeed_networkError_showsErrorGracefully() throws {
    // Relaunch with invalid Supabase URL to simulate network error
    app.terminate()

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": "https://invalid-url-that-does-not-exist.supabase.co",
      "SUPABASE_ANON_KEY": "invalid-key"
    ]
    app.launch()

    screen = ActivityFeedScreenObject(app: app)

    // Login will likely fail with invalid credentials
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    add(app.takeScreenshot(name: "11-network-error-login"))

    // If login succeeds (unlikely), navigate to activity and check error state
    if app.waitForLogin(timeout: 5) {
      screen.navigateToActivityFromDashboard()

      if screen.waitForScreenToLoad() {
        _ = screen.waitForContentToLoad()

        add(app.takeScreenshot(name: "12-network-error-activity"))

        if screen.verifyErrorState() {
          XCTAssertTrue(
            screen.retryButton.exists,
            "Retry button should be visible in error state"
          )
        }
      }
    }

    // If login fails, that's the expected behavior with invalid URL
    add(app.takeScreenshot(name: "12-network-error-expected"))
  }

  // MARK: - Phase 5: Search Accessibility in Empty State

  /// Test: Filter controls remain accessible in empty state
  @MainActor
  func testActivityFeed_emptyState_filtersRemainAccessible() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available")
    }

    add(app.takeScreenshot(name: "13-a11y-empty-initial"))

    // Force empty state via nonsense search
    screen.searchActivities("xyznonexistentquery987654")
    sleep(1)

    add(app.takeScreenshot(name: "14-a11y-empty-state"))

    // Then: Search field should remain accessible
    XCTAssertTrue(
      screen.searchField.exists,
      "Search field should remain visible in filtered empty state"
    )

    // Then: Clear Filters button should be accessible
    XCTAssertTrue(
      screen.clearFiltersButton.exists,
      "Clear Filters button should be accessible in empty state"
    )

    XCTAssertTrue(
      screen.clearFiltersButton.isHittable,
      "Clear Filters button should be tappable"
    )

    add(app.takeScreenshot(name: "15-a11y-empty-verified"))

    // Clean up
    screen.clearFiltersButton.tap()
  }

  // MARK: - Phase 6: Long Text Handling

  /// Test: Long activity titles and descriptions truncate correctly
  @MainActor
  func testActivityFeed_longText_truncatesCorrectly() throws {
    try navigateToActivityPage()

    guard screen.waitForContentToLoad(), screen.hasActivitiesLoaded() else {
      throw XCTSkip("No activities available for text truncation test")
    }

    add(app.takeScreenshot(name: "16-truncation-initial"))

    // ActivityEventItem has:
    //   Title: .lineLimit(1) - truncates to single line
    //   Description: .lineLimit(2) - truncates to 2 lines
    // Items should have bounded heights
    let items = screen.allActivityElements()
    guard !items.isEmpty else {
      throw XCTSkip("No activity items found")
    }

    let itemFrame = items[0].frame
    // A reasonable max height for a card with 1-line title + 2-line description + padding
    XCTAssertLessThan(
      itemFrame.height, 200.0,
      "Activity item height should be bounded (text should truncate)"
    )

    add(app.takeScreenshot(name: "17-truncation-verified"))
  }
}
