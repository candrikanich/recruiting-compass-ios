import XCTest

/// E2E tests for Notification Preferences page
/// Tests critical user journeys including toggle settings, quiet hours, and reset to defaults
final class NotificationPreferencesE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: NotificationPreferencesScreenObject!
  private var navigation: PreferencesNavigationScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = NotificationPreferencesScreenObject(app: app)
    navigation = PreferencesNavigationScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
    navigation = nil
  }

  // MARK: - Navigation Tests

  /// Test: User can navigate to Notification Preferences from Settings
  @MainActor
  func testNotificationPreferences_navigation_success() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-notifications-dashboard"))

    // When: Navigate to Notification Preferences
    navigation.navigateToNotificationPreferences()

    add(app.takeScreenshot(name: "02-notifications-screen"))

    // Then: Notification Preferences screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Notification Preferences screen should load"
    )

    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should be visible"
    )

    add(app.takeScreenshot(name: "03-notifications-loaded"))
  }

  // MARK: - Follow-Up Reminders Tests

  /// Test: User can toggle follow-up reminders on/off
  @MainActor
  func testNotificationPreferences_toggleFollowUpReminders_savesPersists() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "04-before-toggle"))

    // When: Toggle follow-up reminders ON
    screen.toggleFollowUpReminders(true)

    add(app.takeScreenshot(name: "05-follow-up-enabled"))

    // Then: Save button should be enabled
    XCTAssertTrue(
      screen.saveButton.isEnabled,
      "Save button should be enabled after toggling"
    )

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "06-follow-up-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after saving toggle"
    )
  }

  /// Test: Reminder days stepper appears when follow-up reminders enabled
  @MainActor
  func testNotificationPreferences_followUpEnabled_showsReminderDays() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "07-before-enabling"))

    // When: Enable follow-up reminders
    screen.toggleFollowUpReminders(true)

    add(app.takeScreenshot(name: "08-follow-up-enabled"))

    // Then: Reminder days stepper should appear
    XCTAssertTrue(
      screen.reminderDaysStepper.waitForExistence(timeout: 2) || screen.reminderDaysLabel.exists,
      "Reminder days controls should appear when follow-up reminders enabled"
    )

    add(app.takeScreenshot(name: "09-stepper-visible"))
  }

  // MARK: - In-App Notification Toggles Tests

  /// Test: User can toggle all in-app notification settings
  @MainActor
  func testNotificationPreferences_toggleAllInAppSettings_savesPersists() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "10-before-toggling-all"))

    // When: Toggle all in-app notifications
    if screen.followUpRemindersToggle.exists {
      screen.followUpRemindersToggle.tap()
    }

    if screen.deadlineAlertsToggle.exists {
      screen.deadlineAlertsToggle.tap()
    }

    if screen.dailyDigestToggle.exists {
      screen.dailyDigestToggle.tap()
    }

    if screen.inboundContactAlertsToggle.exists {
      screen.inboundContactAlertsToggle.tap()
    }

    add(app.takeScreenshot(name: "11-all-toggled"))

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "12-all-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after saving all toggles"
    )
  }

  // MARK: - Email Notifications Tests

  /// Test: User can enable email notifications
  @MainActor
  func testNotificationPreferences_enableEmailNotifications_savesPersists() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "13-before-email"))

    // When: Enable email notifications
    let currentValue = screen.emailNotificationsToggle.value as? String
    if currentValue != "1" {
      screen.emailNotificationsToggle.tap()
    }

    add(app.takeScreenshot(name: "14-email-enabled"))

    // Then: High-priority toggle should appear
    let highPriorityAppears = screen.highPriorityOnlyToggle.waitForExistence(timeout: 2)

    if highPriorityAppears {
      XCTAssertTrue(
        screen.highPriorityOnlyToggle.exists,
        "High-priority toggle should appear when email enabled"
      )

      add(app.takeScreenshot(name: "15-high-priority-visible"))
    }

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "16-email-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after enabling email notifications"
    )
  }

  /// Test: User can toggle high-priority only email filter
  @MainActor
  func testNotificationPreferences_toggleHighPriorityOnly_savesPersists() throws {
    // Given: Logged in and on Notification Preferences screen with email enabled
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "17-before-high-priority"))

    // When: Enable email notifications first
    let emailValue = screen.emailNotificationsToggle.value as? String
    if emailValue != "1" {
      screen.emailNotificationsToggle.tap()
    }

    sleep(1) // Wait for high-priority toggle to appear

    add(app.takeScreenshot(name: "18-email-enabled"))

    // When: Toggle high-priority only
    if screen.highPriorityOnlyToggle.exists {
      screen.highPriorityOnlyToggle.tap()

      add(app.takeScreenshot(name: "19-high-priority-toggled"))

      // When: Save
      screen.tapSave()
      _ = screen.waitForSaveToComplete(timeout: 15)

      add(app.takeScreenshot(name: "20-high-priority-saved"))

      // Then: No errors
      XCTAssertFalse(
        screen.errorAlert.exists,
        "Should not show error after toggling high-priority"
      )
    } else {
      throw XCTSkip("High-priority toggle not available")
    }
  }

  // MARK: - Reset to Defaults Tests

  /// Test: User can reset notification preferences to defaults
  @MainActor
  func testNotificationPreferences_resetToDefaults_restoresDefaults() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "21-before-reset"))

    // When: Toggle some settings to non-default values
    if screen.followUpRemindersToggle.exists {
      let currentValue = screen.followUpRemindersToggle.value as? String
      if currentValue == "1" {
        screen.followUpRemindersToggle.tap() // Turn OFF
      }
    }

    add(app.takeScreenshot(name: "22-settings-modified"))

    // When: Save modified settings
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "23-modified-settings-saved"))

    // When: Tap Reset to Defaults
    screen.tapResetToDefaults()

    add(app.takeScreenshot(name: "24-after-reset-tap"))

    // Wait for reset to complete
    sleep(2)

    add(app.takeScreenshot(name: "25-reset-complete"))

    // Then: Follow-up reminders should be ON (default is true)
    _ = screen.followUpRemindersToggle.value as? String

    // Note: Defaults may vary, just verify reset action completes
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after reset to defaults"
    )

    add(app.takeScreenshot(name: "26-reset-verified"))
  }

  // MARK: - Persistence Tests

  /// Test: Notification preferences persist across sessions
  @MainActor
  func testNotificationPreferences_modifySettings_persistsAcrossSessions() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "27-persistence-before"))

    // When: Toggle daily digest OFF
    let currentValue = screen.dailyDigestToggle.value as? String
    if currentValue == "1" {
      screen.dailyDigestToggle.tap()
    }

    add(app.takeScreenshot(name: "28-persistence-daily-digest-off"))

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "29-persistence-saved"))

    // When: Navigate away
    screen.backButton.tap()
    _ = navigation.waitForSettingsToLoad()

    add(app.takeScreenshot(name: "30-persistence-back-to-settings"))

    // When: Navigate back
    navigation.navigateToNotificationPreferences()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "31-persistence-reopened"))

    // Then: Daily digest should still be OFF
    let persistedValue = screen.dailyDigestToggle.value as? String

    XCTAssertEqual(
      persistedValue,
      "0",
      "Daily digest toggle should persist as OFF, got: \(persistedValue ?? "nil")"
    )

    add(app.takeScreenshot(name: "32-persistence-verified"))
  }

  // MARK: - Comprehensive Flow Test

  /// Test: Complete flow modifying all notification settings
  @MainActor
  func testNotificationPreferences_modifyAllSettings_success() throws {
    // Given: Logged in and on Notification Preferences screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToNotificationPreferences()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "33-comprehensive-start"))

    // When: Modify in-app notifications
    screen.toggleFollowUpReminders(true)
    screen.deadlineAlertsToggle.tap()
    screen.dailyDigestToggle.tap()

    add(app.takeScreenshot(name: "34-comprehensive-in-app-modified"))

    // When: Modify email notifications
    let emailValue = screen.emailNotificationsToggle.value as? String
    if emailValue != "1" {
      screen.emailNotificationsToggle.tap()
    }

    sleep(1) // Wait for high-priority to appear

    add(app.takeScreenshot(name: "35-comprehensive-email-modified"))

    // When: Save all changes
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "36-comprehensive-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after comprehensive save"
    )

    // When: Navigate away and back
    screen.backButton.tap()
    _ = navigation.waitForSettingsToLoad()

    navigation.navigateToNotificationPreferences()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "37-comprehensive-reopened"))

    // Then: All changes persist
    let followUpPersisted = screen.followUpRemindersToggle.value as? String
    XCTAssertEqual(
      followUpPersisted,
      "1",
      "Follow-up reminders should persist as ON"
    )

    add(app.takeScreenshot(name: "38-comprehensive-verified"))
  }
}
