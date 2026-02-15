import XCTest

/// Page Object Model for the Notifications screen
/// Provides helper methods for UI test interactions
final class NotificationsScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var notificationsTab: XCUIElement {
    app.tabBars.buttons["Notifications"]
  }

  var navigationTitle: XCUIElement {
    app.navigationBars["Notifications"]
  }

  // MARK: - Bulk Action Buttons

  var markAllReadButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "identifier == 'Mark all as read'"
    )).firstMatch
  }

  var clearReadButton: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "identifier == 'Clear read notifications'"
    )).firstMatch
  }

  // MARK: - Search

  var searchField: XCUIElement {
    app.textFields["Search notifications"]
  }

  var clearSearchButton: XCUIElement {
    app.buttons["Clear text"]
  }

  // MARK: - Filter Chips

  var filterChipsContainer: XCUIElement {
    app.scrollViews.matching(NSPredicate(
      format: "identifier == 'Filter notifications'"
    )).firstMatch
  }

  // MARK: - List Content

  var notificationCards: XCUIElementQuery {
    app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH 'notification-card-'"
    ))
  }

  var emptyStateText: XCUIElement {
    app.staticTexts["No notifications"]
  }

  // MARK: - Loading States

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading notifications..."]
  }

  // MARK: - Confirmation Alerts

  var deleteAlert: XCUIElement {
    app.alerts["Delete Notification"]
  }

  var deleteAlertConfirmButton: XCUIElement {
    deleteAlert.buttons["Delete"]
  }

  var deleteAlertCancelButton: XCUIElement {
    deleteAlert.buttons["Cancel"]
  }

  var clearReadAlert: XCUIElement {
    app.alerts["Clear Read Notifications"]
  }

  var clearReadAlertConfirmButton: XCUIElement {
    clearReadAlert.buttons["Clear"]
  }

  var clearReadAlertCancelButton: XCUIElement {
    clearReadAlert.buttons["Cancel"]
  }

  // MARK: - Navigation

  func navigateToNotifications() {
    if notificationsTab.waitForExistence(timeout: 5) {
      notificationsTab.tap()
    }
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    let hasCards = notificationCards.firstMatch.waitForExistence(timeout: 10)
    let hasEmpty = emptyStateText.waitForExistence(timeout: 1)
    return hasCards || hasEmpty
  }

  // MARK: - Card Interactions

  func cardCount() -> Int {
    notificationCards.count
  }

  func notificationCardAt(index: Int) -> XCUIElement {
    notificationCards.element(boundBy: index)
  }

  func tapNotification(atIndex index: Int) {
    let card = notificationCardAt(index: index)
    if card.waitForExistence(timeout: 5) {
      card.tap()
    }
  }

  /// Tap the inline X delete button on a notification card
  func deleteNotification(atIndex index: Int) {
    let card = notificationCardAt(index: index)
    guard card.waitForExistence(timeout: 5) else { return }

    let deleteButton = card.buttons["Delete notification"]
    if deleteButton.waitForExistence(timeout: 2) {
      deleteButton.tap()
    }
  }

  // MARK: - Bulk Actions

  func tapMarkAllRead() {
    if markAllReadButton.waitForExistence(timeout: 3) {
      markAllReadButton.tap()
    }
  }

  func tapClearRead() {
    if clearReadButton.waitForExistence(timeout: 3) {
      clearReadButton.tap()
    }
  }

  // MARK: - Filter Interactions

  /// Tap a filter chip by its accessibility label prefix
  /// Filter chip labels follow the pattern: "emoji label filter"
  /// e.g., "All filter", "Follow-ups filter", "Deadlines filter"
  func tapFilterChip(_ labelPrefix: String) {
    let chip = app.buttons.matching(NSPredicate(
      format: "label BEGINSWITH %@", labelPrefix
    )).firstMatch
    if chip.waitForExistence(timeout: 3) {
      chip.tap()
    }
  }

  func tapAllFilter() {
    tapFilterChip("All filter")
  }

  func tapDeadlinesFilter() {
    tapFilterChip("Deadlines filter")
  }

  func tapFollowUpsFilter() {
    tapFilterChip("Follow-ups filter")
  }

  // MARK: - Search Interactions

  func searchNotifications(_ query: String) {
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

  // MARK: - Pull to Refresh

  func pullToRefresh() {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
    start.press(forDuration: 0.1, thenDragTo: end)
  }

  // MARK: - Verification Helpers

  func verifyEmptyState() -> Bool {
    emptyStateText.exists
  }

  /// Checks if a card is unread via its accessibility label
  /// NotificationCard sets label prefix to "Unread" or "Read"
  func verifyCardIsUnread(atIndex index: Int) -> Bool {
    let card = notificationCardAt(index: index)
    guard card.exists else { return false }
    return card.label.hasPrefix("Unread")
  }

  func verifyCardIsRead(atIndex index: Int) -> Bool {
    let card = notificationCardAt(index: index)
    guard card.exists else { return false }
    return card.label.hasPrefix("Read")
  }
}
