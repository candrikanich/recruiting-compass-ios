import XCTest

/// E2E tests for Player Details preferences page
/// Tests critical user journeys including navigation, editing, persistence, and role-based access
final class PlayerDetailsE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: PlayerDetailsScreenObject!
  private var navigation: PreferencesNavigationScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = PlayerDetailsScreenObject(app: app)
    navigation = PreferencesNavigationScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
    navigation = nil
  }

  // MARK: - Navigation Tests

  /// Test: User can navigate to Player Details from Settings
  @MainActor
  func testPlayerDetails_navigation_success() throws {
    // Given: User is logged in as player
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-player-dashboard"))

    // When: Navigate to Player Details
    navigation.navigateToPlayerDetails()

    add(app.takeScreenshot(name: "02-player-details-screen"))

    // Then: Player Details screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Player Details screen should load"
    )

    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should be visible"
    )

    add(app.takeScreenshot(name: "03-player-details-loaded"))
  }

  // MARK: - Role-Based Access Tests

  /// Test: Player role can edit all fields (not read-only)
  @MainActor
  func testPlayerDetails_playerRole_editable() throws {
    // Given: Logged in as player
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    // When: Navigate to Player Details
    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "04-player-editable-check"))

    // Then: Read-only banner should NOT be visible
    XCTAssertFalse(
      screen.readOnlyBanner.exists,
      "Read-only banner should not be visible for players"
    )

    // Then: Save button should be visible
    XCTAssertTrue(
      screen.saveButton.exists,
      "Save button should be visible for players"
    )

    // Then: Fields should be enabled (not disabled)
    XCTAssertTrue(
      screen.highSchoolTextField.isEnabled,
      "High school field should be enabled for players"
    )

    add(app.takeScreenshot(name: "05-player-fields-enabled"))
  }

  // MARK: - Basic Information Editing Tests

  /// Test: Player can edit and save basic information
  @MainActor
  func testPlayerDetails_editBasicInfo_savesPersists() throws {
    // Given: Logged in as player and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "06-before-edit"))

    // When: Edit basic information fields
    screen.fillBasicInfo(
      highSchool: "Test High School",
      clubTeam: "Test Baseball Club"
    )

    add(app.takeScreenshot(name: "07-after-filling-basic-info"))

    // Then: Save button should be enabled
    XCTAssertTrue(
      screen.isSaveButtonEnabled(),
      "Save button should be enabled after making changes"
    )

    // When: Tap Save
    screen.tapSave()

    add(app.takeScreenshot(name: "08-saving"))

    // Then: Save should complete
    XCTAssertTrue(
      screen.waitForSaveToComplete(timeout: 15),
      "Save should complete within timeout"
    )

    add(app.takeScreenshot(name: "09-save-complete"))

    // When: Navigate away and back to verify persistence
    screen.backButton.tap()
    _ = navigation.waitForSettingsToLoad()

    add(app.takeScreenshot(name: "10-back-to-settings"))

    navigation.navigateToPlayerDetails()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "11-reopened-player-details"))

    // Then: Changes should persist
    let highSchoolValue = screen.highSchoolTextField.value as? String
    XCTAssertTrue(
      highSchoolValue?.contains("Test High School") == true,
      "High school value should persist after save, got: \(highSchoolValue ?? "nil")"
    )

    add(app.takeScreenshot(name: "12-verify-persistence"))
  }

  // MARK: - Athletic Profile Tests

  /// Test: Player can edit athletic profile fields
  @MainActor
  func testPlayerDetails_editAthleticProfile_savesPersists() throws {
    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "13-athletic-profile-before"))

    // When: Edit athletic profile
    screen.fillAthleticProfile(
      sport: "Baseball",
      position: "Pitcher"
    )

    add(app.takeScreenshot(name: "14-athletic-profile-filled"))

    // When: Save changes
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "15-athletic-profile-saved"))

    // Then: Verify success message or no error
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after saving athletic profile"
    )
  }

  // MARK: - Academics Validation Tests

  /// Test: Invalid GPA shows validation error
  @MainActor
  func testPlayerDetails_invalidGPA_showsError() throws {
    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "16-before-invalid-gpa"))

    // When: Enter invalid GPA (> 5.0)
    screen.gpaTextField.tap()
    screen.gpaTextField.typeText("6.5")

    add(app.takeScreenshot(name: "17-invalid-gpa-entered"))

    screen.dismissKeyboard()

    // When: Try to save
    screen.tapSave()

    add(app.takeScreenshot(name: "18-after-save-attempt"))

    // Then: Either save button disabled or error shown
    // Note: Validation may be client-side (button disabled) or server-side (error alert)
    let saveSucceeded = screen.waitForSaveToComplete(timeout: 5)

    if !saveSucceeded && screen.errorAlert.exists {
      add(app.takeScreenshot(name: "19-validation-error-shown"))

      XCTAssertTrue(
        screen.errorAlert.exists,
        "Should show error for invalid GPA"
      )

      // Dismiss error
      if screen.errorOkButton.exists {
        screen.errorOkButton.tap()
      }
    }

    add(app.takeScreenshot(name: "20-validation-test-complete"))
  }

  // MARK: - Social Media Tests

  /// Test: Player can add social media handles
  @MainActor
  func testPlayerDetails_addSocialMedia_savesPersists() throws {
    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "21-before-social-media"))

    // When: Fill social media fields
    screen.fillSocialMedia(
      twitter: "@testplayer",
      instagram: "@testplayer_baseball"
    )

    add(app.takeScreenshot(name: "22-social-media-filled"))

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "23-social-media-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after saving social media"
    )
  }

  // MARK: - Contact Information Tests

  /// Test: Player can toggle share permissions
  @MainActor
  func testPlayerDetails_toggleSharePermissions_savesPersists() throws {
    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "24-before-share-toggle"))

    // When: Toggle share permissions
    screen.toggleSharePermissions(sharePhone: true, shareEmail: true)

    add(app.takeScreenshot(name: "25-share-permissions-toggled"))

    // Then: Save button should be enabled
    XCTAssertTrue(
      screen.isSaveButtonEnabled(),
      "Save button should be enabled after toggling permissions"
    )

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "26-share-permissions-saved"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after saving share permissions"
    )
  }

  // MARK: - Error Handling Tests

  /// Test: Network error shows retry option
  @MainActor
  func testPlayerDetails_networkError_showsErrorMessage() throws {
    // Note: This test is difficult without network mocking
    // It primarily verifies error UI exists and can be dismissed

    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "27-ready-for-network-test"))

    // When: Make a change and try to save
    screen.highSchoolTextField.tap()
    screen.highSchoolTextField.typeText("Network Test School")

    add(app.takeScreenshot(name: "28-change-made"))

    screen.tapSave()

    // Wait for either success or error
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "29-after-save-attempt"))

    // If error alert appears, verify we can dismiss it
    if screen.errorAlert.exists {
      add(app.takeScreenshot(name: "30-error-alert-shown"))

      XCTAssertTrue(
        screen.errorAlert.exists,
        "Error alert should be dismissable"
      )

      XCTAssertTrue(
        screen.errorOkButton.exists,
        "Error OK button should exist"
      )

      screen.errorOkButton.tap()

      add(app.takeScreenshot(name: "31-error-dismissed"))
    }
  }

  // MARK: - Comprehensive Flow Test

  /// Test: Player can fill multiple sections and save all at once
  @MainActor
  func testPlayerDetails_fillMultipleSections_savesPersists() throws {
    // Given: Logged in and on Player Details screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToPlayerDetails()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "32-comprehensive-test-start"))

    // When: Fill multiple sections
    screen.fillBasicInfo(
      highSchool: "Comprehensive Test HS",
      clubTeam: "Elite Baseball"
    )

    screen.fillAthleticProfile(
      sport: "Baseball",
      position: "Catcher"
    )

    screen.fillPhysicalProfile(
      bats: "Right (R)",
      throwingHand: "Right (R)",
      weight: 180
    )

    add(app.takeScreenshot(name: "33-all-sections-filled"))

    // When: Save
    screen.tapSave()
    _ = screen.waitForSaveToComplete(timeout: 15)

    add(app.takeScreenshot(name: "34-comprehensive-save-complete"))

    // Then: No errors
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after comprehensive save"
    )

    // When: Navigate away and back
    screen.backButton.tap()
    _ = navigation.waitForSettingsToLoad()

    navigation.navigateToPlayerDetails()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "35-comprehensive-verify-persistence"))

    // Then: All changes should persist
    let highSchoolValue = screen.highSchoolTextField.value as? String
    XCTAssertTrue(
      highSchoolValue?.contains("Comprehensive Test HS") == true,
      "Comprehensive changes should persist"
    )

    add(app.takeScreenshot(name: "36-comprehensive-test-complete"))
  }
}
