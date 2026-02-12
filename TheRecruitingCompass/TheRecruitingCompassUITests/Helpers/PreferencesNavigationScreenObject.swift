import XCTest

/// Page Object Model for navigating to Preferences pages
/// Provides helper methods for accessing preference screens from various entry points
final class PreferencesNavigationScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var settingsTab: XCUIElement {
    app.tabBars.buttons["Settings"]
  }

  var settingsNavigationBar: XCUIElement {
    app.navigationBars["Settings"]
  }

  // Preference Category Buttons
  var playerDetailsButton: XCUIElement {
    app.buttons["Player Details"]
  }

  var schoolPreferencesButton: XCUIElement {
    app.buttons["School Preferences"]
  }

  var notificationPreferencesButton: XCUIElement {
    app.buttons["Notification Preferences"]
  }

  var dashboardCustomizationButton: XCUIElement {
    app.buttons["Dashboard Customization"]
  }

  var homeLocationButton: XCUIElement {
    app.buttons["Home Location"]
  }

  // MARK: - Navigation Methods

  /// Navigate to Settings tab from any screen
  func navigateToSettings() {
    if settingsTab.exists {
      settingsTab.tap()
    }

    // Wait for Settings screen to load
    _ = settingsNavigationBar.waitForExistence(timeout: 5)
  }

  /// Navigate to Player Details from Dashboard
  func navigateToPlayerDetails() {
    navigateToSettings()

    if playerDetailsButton.waitForExistence(timeout: 5) {
      playerDetailsButton.tap()
    }
  }

  /// Navigate to School Preferences from Dashboard
  func navigateToSchoolPreferences() {
    navigateToSettings()

    if schoolPreferencesButton.waitForExistence(timeout: 5) {
      schoolPreferencesButton.tap()
    }
  }

  /// Navigate to Notification Preferences from Dashboard
  func navigateToNotificationPreferences() {
    navigateToSettings()

    if notificationPreferencesButton.waitForExistence(timeout: 5) {
      notificationPreferencesButton.tap()
    }
  }

  /// Navigate to Dashboard Customization from Dashboard
  func navigateToDashboardCustomization() {
    navigateToSettings()

    if dashboardCustomizationButton.waitForExistence(timeout: 5) {
      dashboardCustomizationButton.tap()
    }
  }

  /// Navigate to Home Location from Dashboard
  func navigateToHomeLocation() {
    navigateToSettings()

    if homeLocationButton.waitForExistence(timeout: 5) {
      homeLocationButton.tap()
    }
  }

  // MARK: - Verification Methods

  func waitForSettingsToLoad() -> Bool {
    return settingsNavigationBar.waitForExistence(timeout: 10)
  }

  func isOnSettingsScreen() -> Bool {
    return settingsNavigationBar.exists
  }
}
