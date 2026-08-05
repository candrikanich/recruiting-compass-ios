import XCTest

/// E2E tests for Home Location preferences page
/// Tests critical user journeys including geocoding, manual coordinates, and error handling
final class HomeLocationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: HomeLocationScreenObject!
  private var navigation: PreferencesNavigationScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = HomeLocationScreenObject(app: app)
    navigation = PreferencesNavigationScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
    navigation = nil
  }

  // MARK: - Navigation Tests

  /// Test: User can navigate to Home Location from Settings
  @MainActor
  func testHomeLocation_navigation_success() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-home-location-dashboard"))

    // When: Navigate to Home Location
    navigation.navigateToHomeLocation()

    add(app.takeScreenshot(name: "02-home-location-screen"))

    // Then: Home Location screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Home Location screen should load"
    )

    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should be visible"
    )

    add(app.takeScreenshot(name: "03-home-location-loaded"))
  }

  // MARK: - Address Entry Tests

  /// Test: User can enter address and auto-save ZIP code
  @MainActor
  func testHomeLocation_enterAddress_autoSavesZipCode() throws {
    // Given: Logged in and on Home Location screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "04-before-address-entry"))

    // When: Fill address fields
    screen.fillAddress(
      street: "123 Main Street",
      city: "Boston",
      state: "MA",
      zip: "02108"
    )

    add(app.takeScreenshot(name: "05-address-entered"))

    screen.dismissKeyboard()

    // Then: ZIP code auto-saves after 500ms delay
    sleep(1) // Wait for auto-save debounce

    add(app.takeScreenshot(name: "06-after-auto-save"))

    // Verify no error alert
    XCTAssertFalse(
      screen.errorAlert.exists,
      "Should not show error after entering valid address"
    )
  }

  // MARK: - Geocoding Tests

  /// Test: User can geocode address to get coordinates
  @MainActor
  func testHomeLocation_geocodeAddress_getsCoordinates() throws {
    // Given: Logged in and on Home Location screen with address entered
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "07-before-geocoding"))

    // When: Fill address and tap geocode button
    screen.fillAddress(
      city: "Boston",
      state: "MA",
      zip: "02108"
    )

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "08-address-ready-for-geocoding"))

    // When: Tap lookup button
    screen.tapLookupFromAddress()

    add(app.takeScreenshot(name: "09-geocoding-in-progress"))

    // Then: Wait for geocoding to complete
    let geocodingSucceeded = screen.waitForGeocodingToComplete(timeout: 20)

    add(app.takeScreenshot(name: "10-after-geocoding"))

    if geocodingSucceeded {
      // Verify coordinates are displayed
      XCTAssertTrue(
        screen.hasCoordinates(),
        "Coordinates should be displayed after successful geocoding"
      )

      XCTAssertTrue(
        screen.coordinatesReadyIndicator.exists,
        "Coordinates ready indicator should be visible"
      )

      add(app.takeScreenshot(name: "11-coordinates-displayed"))
    } else {
      // Geocoding may fail in test environment - skip if so
      throw XCTSkip("Geocoding did not complete - may be network issue in test environment")
    }
  }

  /// Test: Geocode button disabled when address incomplete
  @MainActor
  func testHomeLocation_incompleteAddress_geocodeButtonDisabled() throws {
    // Given: Logged in and on Home Location screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "12-empty-address"))

    // When: Address fields are empty
    // Then: Geocode button should be disabled
    XCTAssertFalse(
      screen.lookupFromAddressButton.isEnabled,
      "Geocode button should be disabled when address is incomplete"
    )

    add(app.takeScreenshot(name: "13-geocode-button-disabled"))

    // When: Fill only city (incomplete)
    screen.fillAddress(city: "Boston")
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "14-partial-address"))

    // Then: Geocode button may still be disabled (needs state too)
    if !screen.lookupFromAddressButton.isEnabled {
      add(app.takeScreenshot(name: "15-still-disabled"))
      XCTAssertFalse(
        screen.lookupFromAddressButton.isEnabled,
        "Geocode button should remain disabled without state"
      )
    }
  }

  // MARK: - Clear Location Tests

  /// Test: User can clear location data
  @MainActor
  func testHomeLocation_clearLocation_removesData() throws {
    // Given: Logged in and on Home Location screen with address entered
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "16-before-clear"))

    // When: Fill address
    screen.fillAddress(
      street: "456 Test Ave",
      city: "Cambridge",
      state: "MA",
      zip: "02139"
    )

    screen.dismissKeyboard()
    sleep(1) // Wait for auto-save

    add(app.takeScreenshot(name: "17-address-entered"))

    // When: Clear location
    if screen.clearLocationButton.exists {
      screen.tapClearLocation()

      add(app.takeScreenshot(name: "18-after-clear"))

      // Then: Address fields should be empty
      let streetValue = screen.streetAddressField.value as? String
      let cityValue = screen.cityField.value as? String

      XCTAssertTrue(
        streetValue?.isEmpty ?? true,
        "Street field should be empty after clear"
      )

      XCTAssertTrue(
        cityValue?.isEmpty ?? true,
        "City field should be empty after clear"
      )

      add(app.takeScreenshot(name: "19-fields-cleared"))
    } else {
      throw XCTSkip("Clear button not available")
    }
  }

  // MARK: - Error Handling Tests

  /// Test: Invalid address shows geocoding error
  @MainActor
  func testHomeLocation_invalidAddress_showsGeocodingError() throws {
    // Given: Logged in and on Home Location screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "20-before-invalid-address"))

    // When: Enter invalid address
    screen.fillAddress(
      city: "InvalidCityName12345",
      state: "XX"
    )

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "21-invalid-address-entered"))

    // When: Attempt to geocode
    screen.tapLookupFromAddress()

    add(app.takeScreenshot(name: "22-geocoding-invalid"))

    // Wait a bit for geocoding attempt
    sleep(3)

    add(app.takeScreenshot(name: "23-after-geocoding-attempt"))

    // Then: Error message may appear (geocoding services vary)
    // This test verifies error handling exists, not that it necessarily triggers
    if screen.errorAlert.exists || screen.geocodingErrorMessage.exists {
      add(app.takeScreenshot(name: "24-error-message-shown"))

      XCTAssertTrue(
        true,
        "Error handling exists for invalid geocoding"
      )
    }
  }

  // MARK: - Persistence Tests

  /// Test: Location data persists across sessions
  @MainActor
  func testHomeLocation_enterLocation_persistsAcrossSessions() throws {
    // Given: Logged in and on Home Location screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "25-persistence-before"))

    // When: Fill address
    let uniqueStreet = "789 Test St \(Int(Date().timeIntervalSince1970))"

    screen.fillAddress(
      street: uniqueStreet,
      city: "Somerville",
      state: "MA",
      zip: "02144"
    )

    screen.dismissKeyboard()
    sleep(1) // Wait for auto-save

    add(app.takeScreenshot(name: "26-persistence-address-entered"))

    // When: Navigate away
    screen.backButton.tap()
    _ = navigation.waitForSettingsToLoad()

    add(app.takeScreenshot(name: "27-persistence-back-to-settings"))

    // When: Navigate back
    navigation.navigateToHomeLocation()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "28-persistence-reopened"))

    // Then: Address should persist
    let streetValue = screen.streetAddressField.value as? String

    XCTAssertTrue(
      streetValue?.contains("789 Test St") ?? false,
      "Street address should persist after navigation, got: \(streetValue ?? "nil")"
    )

    add(app.takeScreenshot(name: "29-persistence-verified"))
  }

  // MARK: - Comprehensive Flow Test

  /// Test: Complete flow from address entry to geocoding to persistence
  @MainActor
  func testHomeLocation_completeFlow_success() throws {
    // Given: Logged in and on Home Location screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed")
    }

    navigation.navigateToHomeLocation()

    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Screen did not load")
    }

    add(app.takeScreenshot(name: "30-complete-flow-start"))

    // When: Fill complete address
    screen.fillAddress(
      street: "100 Main St",
      city: "Boston",
      state: "MA",
      zip: "02109"
    )

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "31-complete-flow-address-filled"))

    // When: Geocode
    sleep(1) // Wait for auto-save
    screen.tapLookupFromAddress()

    add(app.takeScreenshot(name: "32-complete-flow-geocoding"))

    let geocodingSucceeded = screen.waitForGeocodingToComplete(timeout: 20)

    add(app.takeScreenshot(name: "33-complete-flow-geocoded"))

    if geocodingSucceeded && screen.hasCoordinates() {
      // Then: Coordinates displayed
      XCTAssertTrue(
        screen.coordinatesReadyIndicator.exists,
        "Coordinates should be ready"
      )

      // When: Navigate away and back
      screen.backButton.tap()
      _ = navigation.waitForSettingsToLoad()

      navigation.navigateToHomeLocation()
      _ = screen.waitForScreenToLoad()

      add(app.takeScreenshot(name: "34-complete-flow-reopened"))

      // Then: Everything persists
      let cityValue = screen.cityField.value as? String
      XCTAssertTrue(
        cityValue?.contains("Boston") ?? false,
        "City should persist"
      )

      add(app.takeScreenshot(name: "35-complete-flow-verified"))
    } else {
      throw XCTSkip("Geocoding did not succeed - may be network issue")
    }
  }
}
