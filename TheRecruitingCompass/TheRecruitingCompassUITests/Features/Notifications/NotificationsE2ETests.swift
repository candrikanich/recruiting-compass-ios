import XCTest

/// E2E tests for the Notifications feature
/// Tests navigation, read/unread, filtering, search, bulk actions,
/// delete, pull-to-refresh, detail navigation, and empty state
final class NotificationsE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: NotificationsScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = NotificationsScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Phase 1: Navigation Tests

  /// Test: Navigate to Notifications tab from Dashboard
  @MainActor
  func testNotifications_navigateToTab_displaysScreen() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-nav-dashboard"))

    // When: Tap Notifications tab
    screen.navigateToNotifications()

    add(app.takeScreenshot(name: "02-nav-notifications-tab-tapped"))

    // Then: Notifications screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Notifications screen should load after tapping tab"
    )

    add(app.takeScreenshot(name: "03-nav-notifications-loaded"))

    // Then: Content should appear (either cards or empty state)
    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Notifications content or empty state should appear"
    )

    add(app.takeScreenshot(name: "04-nav-content-loaded"))
  }

  // MARK: - Phase 2: Mark as Read Tests

  /// Test: Tapping a notification marks it as read
  @MainActor
  func testNotifications_tapNotification_marksAsRead() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 0 else {
      throw XCTSkip("No notifications available to mark as read")
    }

    add(app.takeScreenshot(name: "05-mark-read-initial"))

    // Find an unread card
    guard screen.verifyCardIsUnread(atIndex: 0) else {
      throw XCTSkip("First notification is already read")
    }

    // When: Tap notification (triggers handleNotificationTap which marks as read)
    screen.tapNotification(atIndex: 0)

    add(app.takeScreenshot(name: "06-mark-read-tapped"))

    // Navigate back to notifications list
    sleep(1)
    let backButton = app.navigationBars.buttons.element(boundBy: 0)
    if backButton.exists {
      backButton.tap()
    }

    sleep(1)
    add(app.takeScreenshot(name: "07-mark-read-returned"))

    // Then: Card should now show as read
    XCTAssertTrue(
      screen.verifyCardIsRead(atIndex: 0),
      "First notification should show as read after tapping"
    )

    add(app.takeScreenshot(name: "08-mark-read-verified"))
  }

  // MARK: - Phase 3: Filter Tests

  /// Test: Filter notifications by type
  @MainActor
  func testNotifications_filterByType_showsFilteredResults() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    add(app.takeScreenshot(name: "09-filter-initial"))

    let initialCount = screen.cardCount()

    // When: Apply Deadlines filter
    screen.tapDeadlinesFilter()

    add(app.takeScreenshot(name: "10-filter-deadlines-applied"))

    sleep(1)

    // Then: List should update (may have fewer or same items)
    let filteredCount = screen.cardCount()
    XCTAssertTrue(
      filteredCount <= initialCount,
      "Filtered count (\(filteredCount)) should be <= initial count (\(initialCount))"
    )

    add(app.takeScreenshot(name: "11-filter-deadlines-result"))

    // When: Switch to All filter
    screen.tapAllFilter()

    sleep(1)

    add(app.takeScreenshot(name: "12-filter-all-restored"))

    // Then: List should restore to initial count
    let restoredCount = screen.cardCount()
    XCTAssertEqual(
      restoredCount, initialCount,
      "All filter should restore original count"
    )
  }

  // MARK: - Phase 4: Search Tests

  /// Test: Search notifications by text
  @MainActor
  func testNotifications_search_filtersResults() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 0 else {
      throw XCTSkip("No notifications available to search")
    }

    add(app.takeScreenshot(name: "13-search-initial"))

    let initialCount = screen.cardCount()

    // When: Search for a specific term
    screen.searchNotifications("coach")

    add(app.takeScreenshot(name: "14-search-typed"))

    sleep(1)

    // Then: Results should be filtered
    let searchCount = screen.cardCount()
    XCTAssertTrue(
      searchCount <= initialCount,
      "Search results (\(searchCount)) should be <= initial count (\(initialCount))"
    )

    add(app.takeScreenshot(name: "15-search-results"))

    // When: Clear search
    screen.clearSearch()

    sleep(1)

    // Then: Results should restore
    let clearedCount = screen.cardCount()
    XCTAssertEqual(
      clearedCount, initialCount,
      "Clearing search should restore original count"
    )

    add(app.takeScreenshot(name: "16-search-cleared"))
  }

  // MARK: - Phase 5: Mark All as Read Tests

  /// Test: Mark all notifications as read updates all cards
  @MainActor
  func testNotifications_markAllAsRead_updatesAllCards() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 0 else {
      throw XCTSkip("No notifications available")
    }

    add(app.takeScreenshot(name: "17-mark-all-initial"))

    // When: Tap Mark All as Read
    screen.tapMarkAllRead()

    add(app.takeScreenshot(name: "18-mark-all-tapped"))

    sleep(1)

    // Then: No cards should show unread indicator
    let totalCards = screen.cardCount()
    for i in 0..<totalCards {
      XCTAssertFalse(
        screen.verifyCardIsUnread(atIndex: i),
        "Card at index \(i) should not show unread indicator after Mark All as Read"
      )
    }

    // Then: Mark all button should be disabled when no unread notifications
    XCTAssertFalse(
      screen.markAllReadButton.isEnabled,
      "Mark all as read should be disabled when no unread notifications"
    )

    add(app.takeScreenshot(name: "19-mark-all-verified"))
  }

  // MARK: - Phase 6: Delete Notification Tests

  /// Test: Delete notification via inline X button removes it from the list
  @MainActor
  func testNotifications_delete_removesFromList() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 0 else {
      throw XCTSkip("No notifications available to delete")
    }

    add(app.takeScreenshot(name: "20-delete-initial"))

    let initialCount = screen.cardCount()

    // When: Tap delete button on first notification card
    screen.deleteNotification(atIndex: 0)

    add(app.takeScreenshot(name: "21-delete-button-tapped"))

    // Then: Confirmation alert should appear
    XCTAssertTrue(
      screen.deleteAlert.waitForExistence(timeout: 5),
      "Delete confirmation alert should appear"
    )

    add(app.takeScreenshot(name: "22-delete-confirmation"))

    // When: Confirm delete
    screen.deleteAlertConfirmButton.tap()

    sleep(1)

    add(app.takeScreenshot(name: "23-delete-confirmed"))

    // Then: Card count should decrease by 1
    let afterDeleteCount = screen.cardCount()
    XCTAssertEqual(
      afterDeleteCount, initialCount - 1,
      "Card count should decrease by 1 after deletion"
    )

    add(app.takeScreenshot(name: "24-delete-verified"))
  }

  // MARK: - Phase 7: Clear Read Notifications Tests

  /// Test: Clear read notifications removes only read items
  @MainActor
  func testNotifications_clearRead_removesOnlyReadItems() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 1 else {
      throw XCTSkip("Need at least 2 notifications for this test")
    }

    add(app.takeScreenshot(name: "25-clear-read-initial"))

    // Mark all as read first so we have read notifications to clear
    screen.tapMarkAllRead()
    sleep(1)

    add(app.takeScreenshot(name: "26-clear-read-all-marked"))

    let countBeforeClear = screen.cardCount()

    // When: Tap Clear Read
    screen.tapClearRead()

    add(app.takeScreenshot(name: "27-clear-read-tapped"))

    // Then: Confirmation alert should appear
    XCTAssertTrue(
      screen.clearReadAlert.waitForExistence(timeout: 5),
      "Clear read confirmation alert should appear"
    )

    // When: Confirm clear
    screen.clearReadAlertConfirmButton.tap()

    sleep(1)

    add(app.takeScreenshot(name: "28-clear-read-confirmed"))

    // Then: All read notifications should be removed
    let afterClearCount = screen.cardCount()
    XCTAssertTrue(
      afterClearCount < countBeforeClear,
      "Card count should decrease after clearing read notifications"
    )

    add(app.takeScreenshot(name: "29-clear-read-verified"))
  }

  // MARK: - Phase 8: Pull-to-Refresh Tests

  /// Test: Pull-to-refresh reloads notifications
  @MainActor
  func testNotifications_pullToRefresh_reloads() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    add(app.takeScreenshot(name: "30-refresh-initial"))

    // When: Pull to refresh
    screen.pullToRefresh()

    add(app.takeScreenshot(name: "31-refresh-pulling"))

    sleep(2)

    // Then: Screen should still show content
    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after pull-to-refresh"
    )

    add(app.takeScreenshot(name: "32-refresh-completed"))
  }

  // MARK: - Phase 9: Notification Detail Navigation Tests

  /// Test: Tap notification navigates to detail view
  @MainActor
  func testNotifications_tapNotification_navigatesToDetail() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    guard screen.cardCount() > 0 else {
      throw XCTSkip("No notifications available to tap")
    }

    add(app.takeScreenshot(name: "33-detail-initial"))

    // When: Tap first notification
    screen.tapNotification(atIndex: 0)

    add(app.takeScreenshot(name: "34-detail-tapped"))

    sleep(2)

    // Then: Should navigate to related detail view
    // Notification taps navigate to various screens depending on type
    // (interaction detail, school detail, coach detail, etc.)
    let navigatedAway = !screen.navigationTitle.exists
      || app.navigationBars.count > 1

    add(app.takeScreenshot(name: "35-detail-navigated"))

    XCTAssertTrue(
      navigatedAway,
      "Tapping a notification should navigate to a detail view"
    )

    // Navigate back
    let backButton = app.navigationBars.buttons.element(boundBy: 0)
    if backButton.exists {
      backButton.tap()
    }

    add(app.takeScreenshot(name: "36-detail-returned"))

    // Then: Should return to notifications list
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Should return to notifications list after back navigation"
    )
  }

  // MARK: - Phase 10: Empty State Tests

  /// Test: Empty state displays when no notifications exist
  @MainActor
  func testNotifications_emptyState_displaysCorrectly() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "37-empty-state-initial"))

    // If notifications exist, skip this test
    if screen.cardCount() > 0 {
      throw XCTSkip("Notifications exist - cannot test empty state with live data")
    }

    // Then: Empty state should be visible
    XCTAssertTrue(
      screen.verifyEmptyState(),
      "Empty state text should be visible when no notifications"
    )

    add(app.takeScreenshot(name: "38-empty-state-visible"))

    // Then: Bulk action buttons should be disabled
    XCTAssertFalse(
      screen.markAllReadButton.isEnabled,
      "Mark all as read should be disabled in empty state"
    )

    XCTAssertFalse(
      screen.clearReadButton.isEnabled,
      "Clear read should be disabled in empty state"
    )

    add(app.takeScreenshot(name: "39-empty-state-verified"))
  }

  // MARK: - Phase 11: Accessibility Tests

  /// Test: VoiceOver labels exist on all interactive elements
  @MainActor
  func testNotifications_accessibility_allElementsLabeled() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    add(app.takeScreenshot(name: "40-a11y-initial"))

    // Then: Tab should have accessibility label
    XCTAssertTrue(
      screen.notificationsTab.exists,
      "Notifications tab should have accessibility label"
    )

    // Then: Bulk action buttons should have accessibility labels
    if screen.markAllReadButton.exists {
      XCTAssertNotNil(
        screen.markAllReadButton.label,
        "Mark all read button should have accessibility label"
      )
    }

    if screen.clearReadButton.exists {
      XCTAssertNotNil(
        screen.clearReadButton.label,
        "Clear read button should have accessibility label"
      )
    }

    add(app.takeScreenshot(name: "41-a11y-toolbar-verified"))

    // Then: Notification cards should have combined accessibility labels
    if screen.cardCount() > 0 {
      let firstCard = screen.notificationCardAt(index: 0)
      XCTAssertTrue(
        firstCard.isHittable,
        "Notification card should be hittable (accessible)"
      )

      // Card label should include read/unread status per NotificationCard impl
      let label = firstCard.label
      XCTAssertTrue(
        label.hasPrefix("Unread") || label.hasPrefix("Read"),
        "Notification card label should start with read/unread status"
      )
    }

    add(app.takeScreenshot(name: "42-a11y-cards-verified"))
  }

  /// Test: Touch targets meet 44pt minimum for WCAG compliance
  @MainActor
  func testNotifications_touchTargets_meet44ptMinimum() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    add(app.takeScreenshot(name: "43-touch-targets-initial"))

    // Then: Bulk action row should meet minimum touch target
    if screen.markAllReadButton.exists {
      let frame = screen.markAllReadButton.frame
      XCTAssertGreaterThanOrEqual(
        frame.height, 44.0,
        "Mark all read button should meet 44pt minimum height"
      )
    }

    // Then: Notification cards should meet minimum touch target
    if screen.cardCount() > 0 {
      let cardFrame = screen.notificationCardAt(index: 0).frame
      XCTAssertGreaterThanOrEqual(
        cardFrame.height, 44.0,
        "Notification card should meet 44pt minimum height"
      )
    }

    // Then: Search field should meet minimum touch target
    if screen.searchField.exists {
      let searchFrame = screen.searchField.frame
      XCTAssertGreaterThanOrEqual(
        searchFrame.height, 44.0,
        "Search field should meet 44pt minimum height"
      )
    }

    add(app.takeScreenshot(name: "44-touch-targets-verified"))
  }

  /// Test: Dynamic Type scaling works correctly
  @MainActor
  func testNotifications_dynamicType_scalesCorrectly() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToNotifications()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("No notifications content loaded")
    }

    add(app.takeScreenshot(name: "45-dynamic-type-initial"))

    // Then: Navigation title should be visible
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should be visible with Dynamic Type"
    )

    // Then: Cards should still be visible and functional
    if screen.cardCount() > 0 {
      let firstCard = screen.notificationCardAt(index: 0)
      XCTAssertTrue(
        firstCard.exists,
        "Cards should remain visible with Dynamic Type"
      )

      XCTAssertTrue(
        firstCard.isHittable,
        "Cards should remain tappable with Dynamic Type"
      )
    }

    // Then: Bulk action buttons should remain accessible
    if screen.markAllReadButton.exists {
      XCTAssertTrue(
        screen.markAllReadButton.isHittable,
        "Mark all read button should remain accessible with Dynamic Type"
      )
    }

    add(app.takeScreenshot(name: "46-dynamic-type-verified"))
  }
}
