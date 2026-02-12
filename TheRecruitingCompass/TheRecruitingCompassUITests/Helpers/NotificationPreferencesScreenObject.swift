import XCTest

/// Page Object Model for Notification Preferences page
final class NotificationPreferencesScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Notifications"]
  }

  var saveButton: XCUIElement {
    app.buttons["Save"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.element(boundBy: 0)
  }

  // MARK: - In-App Notifications

  var followUpRemindersToggle: XCUIElement {
    app.switches["Coach Follow-Up Reminders"]
  }

  var reminderDaysStepper: XCUIElement {
    app.steppers.firstMatch
  }

  var reminderDaysLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Days between reminders'")).firstMatch
  }

  var deadlineAlertsToggle: XCUIElement {
    app.switches["Deadline Alerts"]
  }

  var dailyDigestToggle: XCUIElement {
    app.switches["Daily Digest"]
  }

  var inboundContactAlertsToggle: XCUIElement {
    app.switches["Inbound Contact Alerts"]
  }

  // MARK: - Email Notifications

  var emailNotificationsToggle: XCUIElement {
    app.switches["Enable Email Notifications"]
  }

  var highPriorityOnlyToggle: XCUIElement {
    app.switches["High-Priority Only"]
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

  func toggleFollowUpReminders(_ enabled: Bool) {
    let currentValue = followUpRemindersToggle.value as? String
    if (enabled && currentValue != "1") || (!enabled && currentValue == "1") {
      followUpRemindersToggle.tap()
    }
  }

  func getReminderDaysValue() -> String? {
    return reminderDaysLabel.label
  }

  func tapSave() {
    if saveButton.exists && saveButton.isEnabled {
      saveButton.tap()
    }
  }

  func tapResetToDefaults() {
    if resetToDefaultsButton.exists {
      resetToDefaultsButton.tap()
    }
  }

  func waitForSaveToComplete(timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }
}
