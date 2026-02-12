import XCTest

/// Page Object Model for Dashboard Customization page
final class DashboardCustomizationScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Dashboard"]
  }

  var saveButton: XCUIElement {
    app.buttons["Save"]
  }

  // MARK: - Stats Cards Toggles

  var selectAllStatsButton: XCUIElement {
    app.buttons["Select All"]
  }

  var deselectAllStatsButton: XCUIElement {
    app.buttons["Deselect All"]
  }

  func statsCardToggle(_ label: String) -> XCUIElement {
    app.switches[label]
  }

  var coachesStatsToggle: XCUIElement {
    statsCardToggle("Coaches")
  }

  var schoolsStatsToggle: XCUIElement {
    statsCardToggle("Schools")
  }

  var interactionsStatsToggle: XCUIElement {
    statsCardToggle("Interactions")
  }

  var offersStatsToggle: XCUIElement {
    statsCardToggle("Offers")
  }

  var eventsStatsToggle: XCUIElement {
    statsCardToggle("Events")
  }

  var performanceStatsToggle: XCUIElement {
    statsCardToggle("Performance")
  }

  var notificationsStatsToggle: XCUIElement {
    statsCardToggle("Notifications")
  }

  var socialMediaStatsToggle: XCUIElement {
    statsCardToggle("Social Media")
  }

  // MARK: - Widget Toggles

  func widgetToggle(_ label: String) -> XCUIElement {
    app.switches[label]
  }

  var recentNotificationsToggle: XCUIElement {
    widgetToggle("Recent Notifications")
  }

  var upcomingEventsToggle: XCUIElement {
    widgetToggle("Upcoming Events")
  }

  var deadlinesToggle: XCUIElement {
    widgetToggle("Deadlines")
  }

  var recentInteractionsToggle: XCUIElement {
    widgetToggle("Recent Interactions")
  }

  var activeConversationsToggle: XCUIElement {
    widgetToggle("Active Conversations")
  }

  var topSchoolsToggle: XCUIElement {
    widgetToggle("Top Schools")
  }

  var suggestedActionsToggle: XCUIElement {
    widgetToggle("Suggested Actions")
  }

  var recentOffersToggle: XCUIElement {
    widgetToggle("Recent Offers")
  }

  // MARK: - Actions

  var resetToDefaultsButton: XCUIElement {
    app.buttons["Reset to Defaults"]
  }

  // MARK: - States

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading preferences..."]
  }

  var errorAlert: XCUIElement {
    app.alerts["Error"]
  }

  var successMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved'")).firstMatch
  }

  // MARK: - Helper Methods

  func waitForScreenToLoad() -> Bool {
    return navigationTitle.waitForExistence(timeout: 10)
  }

  func toggleStatsCard(_ label: String, enabled: Bool) {
    let toggle = statsCardToggle(label)
    let currentValue = toggle.value as? String
    if (enabled && currentValue != "1") || (!enabled && currentValue == "1") {
      toggle.tap()
    }
  }

  func toggleWidget(_ label: String, enabled: Bool) {
    let toggle = widgetToggle(label)
    let currentValue = toggle.value as? String
    if (enabled && currentValue != "1") || (!enabled && currentValue == "1") {
      toggle.tap()
    }
  }

  func tapSelectAllStats() {
    if selectAllStatsButton.exists {
      selectAllStatsButton.tap()
    }
  }

  func tapDeselectAllStats() {
    if deselectAllStatsButton.exists {
      deselectAllStatsButton.tap()
    }
  }

  func tapResetToDefaults() {
    if resetToDefaultsButton.exists {
      resetToDefaultsButton.tap()
    }
  }

  func tapSave() {
    if saveButton.exists && saveButton.isEnabled {
      saveButton.tap()
    }
  }

  func waitForSaveToComplete(timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }
}
