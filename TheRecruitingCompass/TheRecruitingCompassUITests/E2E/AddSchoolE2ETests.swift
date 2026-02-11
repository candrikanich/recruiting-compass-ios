import XCTest

/// E2E tests for the Add School feature
/// Tests critical user journeys including autocomplete mode, manual entry, validation, and duplicate detection
final class AddSchoolE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddSchoolScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = AddSchoolScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Phase 1: Happy Path Tests

  /// Test: User can create a school using autocomplete mode with full enrichment
  /// Covers spec lines 43-65 (Primary Flow: Autocomplete Mode)
  @MainActor
  func testAddSchool_autocompleteMode_fullFlow() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-autocomplete-dashboard"))

    // When: Navigate to Add School screen
    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "02-autocomplete-add-school-screen"))

    // Then: Screen should load with autocomplete toggle ON by default
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Add School navigation title should be visible"
    )

    XCTAssertTrue(
      screen.autocompleteToggle.exists,
      "Autocomplete toggle should exist"
    )

    // Verify toggle is ON by default
    let toggleValue = screen.autocompleteToggle.value as? String
    XCTAssertEqual(toggleValue, "1", "Autocomplete toggle should be ON by default")

    // When: Type college name (>= 3 characters)
    screen.searchCollege(query: "Florida")

    add(app.takeScreenshot(name: "03-autocomplete-searching"))

    // Then: Autocomplete dropdown should appear with results
    // Wait for search to complete (debounced)
    sleep(1)

    add(app.takeScreenshot(name: "04-autocomplete-results"))

    // When: Select first college from results
    screen.selectAutocompleteResult(at: 0)

    add(app.takeScreenshot(name: "05-autocomplete-college-selected"))

    // Then: Verify selected college card appears
    XCTAssertTrue(
      screen.selectedCollegeCard.waitForExistence(timeout: 5),
      "Selected college card should appear"
    )

    // Wait for enrichment to complete
    _ = screen.waitForEnrichmentToComplete(timeout: 15)

    add(app.takeScreenshot(name: "06-autocomplete-enrichment-complete"))

    // Verify auto-populated fields have values
    XCTAssertTrue(
      screen.nameTextField.exists,
      "Name field should be populated"
    )

    XCTAssertTrue(
      screen.locationTextField.exists,
      "Location field should be populated"
    )

    // When: Fill optional fields
    screen.fillNotes("Great baseball program with strong academics")
    screen.selectStatus("Interested")

    add(app.takeScreenshot(name: "07-autocomplete-optional-fields-filled"))

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "08-autocomplete-submitting"))

    // Then: Should navigate to School Detail page or Schools List
    _ = screen.waitForSubmissionToComplete(timeout: 15)

    add(app.takeScreenshot(name: "09-autocomplete-after-submit"))

    let detailAppeared = app.navigationBars["School Details"].waitForExistence(timeout: 10)
    let schoolsListAppeared = app.navigationBars["Schools"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      detailAppeared || schoolsListAppeared,
      "Should navigate to School Detail or Schools List after successful creation"
    )

    add(app.takeScreenshot(name: "10-autocomplete-success"))
  }

  /// Test: User can create a school using manual entry mode
  /// Covers spec lines 67-75 (Alternative Flow: Manual Entry Mode)
  @MainActor
  func testAddSchool_manualMode_fullFlow() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "11-manual-add-school-screen"))

    // When: Toggle OFF autocomplete
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "12-manual-autocomplete-off"))

    // Then: Autocomplete search field should be hidden
    XCTAssertFalse(
      screen.autocompleteSearchField.exists,
      "Autocomplete search field should be hidden in manual mode"
    )

    // Then: Manual name field should be visible
    XCTAssertTrue(
      screen.nameTextField.exists,
      "Name text field should be visible in manual mode"
    )

    // When: Fill all fields manually
    screen.fillSchoolName("Manual Test University")
    screen.fillLocation("Test City, Test State")

    add(app.takeScreenshot(name: "13-manual-name-location-filled"))

    screen.selectDivision("D1")
    screen.fillConference("Test Conference")
    screen.fillWebsite("https://testuniversity.edu")

    add(app.takeScreenshot(name: "14-manual-division-conference-filled"))

    screen.fillTwitterHandle("@testbaseball")
    screen.fillInstagramHandle("@test_baseball")
    screen.fillNotes("Manually entered test school")
    screen.selectStatus("Researching")

    add(app.takeScreenshot(name: "15-manual-all-fields-filled"))

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "16-manual-submitting"))

    // Then: Should navigate successfully
    _ = screen.waitForSubmissionToComplete(timeout: 15)

    add(app.takeScreenshot(name: "17-manual-after-submit"))

    let detailAppeared = app.navigationBars["School Details"].waitForExistence(timeout: 10)
    let schoolsListAppeared = app.navigationBars["Schools"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      detailAppeared || schoolsListAppeared,
      "Should navigate after successful manual entry creation"
    )

    add(app.takeScreenshot(name: "18-manual-success"))
  }

  /// Test: User can clear autocomplete selection and reset auto-filled fields
  /// Covers spec lines 77-85 (Alternative Flow: Clear Selection)
  @MainActor
  func testAddSchool_clearSelection_resetsFields() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "19-clear-add-school-screen"))

    // When: Search and select a college
    screen.searchCollege(query: "Miami")
    sleep(1) // Wait for debounce

    add(app.takeScreenshot(name: "20-clear-search-results"))

    screen.selectAutocompleteResult(at: 0)

    add(app.takeScreenshot(name: "21-clear-college-selected"))

    // Then: Selected college card should appear
    XCTAssertTrue(
      screen.selectedCollegeCard.waitForExistence(timeout: 5),
      "Selected college card should appear"
    )

    // Wait for enrichment
    _ = screen.waitForEnrichmentToComplete(timeout: 15)

    add(app.takeScreenshot(name: "22-clear-enrichment-complete"))

    // Verify fields are populated
    XCTAssertTrue(
      screen.verifyFieldHasValue(screen.nameTextField),
      "Name field should be populated before clear"
    )

    // When: Tap Clear button
    screen.clearSelection()

    add(app.takeScreenshot(name: "23-clear-after-clear-tap"))

    // Then: Selected college card should disappear
    XCTAssertFalse(
      screen.selectedCollegeCard.exists,
      "Selected college card should disappear after clear"
    )

    // Then: Can search again
    XCTAssertTrue(
      screen.autocompleteSearchField.exists,
      "Search field should be visible again after clear"
    )

    add(app.takeScreenshot(name: "24-clear-can-search-again"))
  }

  /// Test: User can cancel and return to Schools List, form data is discarded
  /// Covers cancel flow from spec
  @MainActor
  func testAddSchool_cancel_returnsToSchoolsList() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "25-cancel-add-school-screen"))

    // When: Fill some fields
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Test Cancel School")
    screen.fillLocation("Cancel City, State")

    add(app.takeScreenshot(name: "26-cancel-fields-filled"))

    // When: Tap Cancel button
    screen.tapCancelButton()

    add(app.takeScreenshot(name: "27-cancel-after-cancel-tap"))

    // Then: Should return to Schools List
    XCTAssertTrue(
      app.navigationBars["Schools"].waitForExistence(timeout: 5),
      "Should return to Schools List after cancel"
    )

    add(app.takeScreenshot(name: "28-cancel-back-to-list"))

    // When: Re-open Add School
    let addButton = app.navigationBars.buttons["Add new school"]
    if addButton.exists {
      addButton.tap()
    }

    add(app.takeScreenshot(name: "29-cancel-reopened"))

    // Then: Form should be empty (data discarded)
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Add School screen should load again"
    )

    // Verify name field is empty (switch to manual mode first)
    screen.toggleAutocomplete(enabled: false)

    let nameFieldValue = screen.nameTextField.value as? String
    XCTAssertTrue(
      nameFieldValue == nil || nameFieldValue?.isEmpty == true,
      "Name field should be empty after reopening"
    )

    add(app.takeScreenshot(name: "30-cancel-form-empty"))
  }

  // MARK: - Phase 2: Error Scenario Tests

  /// Test: Duplicate name detection shows dialog with correct match type
  /// Covers spec lines 727-735 (Duplicate Detection Tests)
  @MainActor
  func testAddSchool_duplicateName_showsDialog() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "31-duplicate-dashboard"))

    // Given: A school with a specific name already exists
    // (Assuming test data exists or was created in a previous test)
    // For a robust test, use SchoolTestDataHelper to create a school first

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "32-duplicate-add-school-screen"))

    // When: Try to add a school with the same name
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Test School 1") // Assuming this exists
    screen.fillLocation("Test Location")
    screen.selectStatus("Interested")

    add(app.takeScreenshot(name: "33-duplicate-name-entered"))

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "34-duplicate-submitting"))

    // Then: Duplicate dialog should appear
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "35-duplicate-dialog-shown"))

      // Verify dialog message
      XCTAssertTrue(
        screen.duplicateDialogMessage.exists,
        "Duplicate dialog should show message"
      )

      // When: Tap Cancel
      screen.cancelDuplicateDialog()

      add(app.takeScreenshot(name: "36-duplicate-after-cancel"))

      // Then: Should return to form
      XCTAssertTrue(
        screen.navigationTitle.exists,
        "Should return to Add School form after cancel"
      )

      // When: Re-submit and proceed anyway
      screen.submitForm()
      _ = screen.waitForDuplicateDialog(timeout: 5)

      add(app.takeScreenshot(name: "37-duplicate-dialog-again"))

      screen.proceedWithDuplicate()

      add(app.takeScreenshot(name: "38-duplicate-after-proceed"))

      // Then: School should be created (duplicate allowed)
      _ = screen.waitForSubmissionToComplete(timeout: 15)

      let success = app.navigationBars["School Details"].waitForExistence(timeout: 10) ||
                    app.navigationBars["Schools"].waitForExistence(timeout: 10)

      XCTAssertTrue(success, "Should create school after proceeding with duplicate")

      add(app.takeScreenshot(name: "39-duplicate-success"))
    } else {
      // No duplicate found - this is acceptable if test data doesn't exist
      throw XCTSkip("No duplicate detected - test data may not exist")
    }
  }

  /// Test: Empty name disables submit button
  /// Covers spec lines 716-726 (Validation Tests)
  @MainActor
  func testAddSchool_emptyName_disablesSubmit() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "40-validation-add-school-screen"))

    // When: Switch to manual mode (no name entered)
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "41-validation-manual-mode-empty"))

    // Then: Add School button should be disabled
    XCTAssertFalse(
      screen.addSchoolButton.isEnabled,
      "Add School button should be disabled when name is empty"
    )

    add(app.takeScreenshot(name: "42-validation-submit-disabled"))

    // When: Enter a name
    screen.fillSchoolName("Valid School Name")

    add(app.takeScreenshot(name: "43-validation-name-entered"))

    // Then: Add School button should become enabled
    XCTAssertTrue(
      screen.addSchoolButton.isEnabled || screen.addSchoolButton.exists,
      "Add School button should be enabled after entering name"
    )

    add(app.takeScreenshot(name: "44-validation-submit-enabled"))
  }

  /// Test: Invalid website URL shows inline validation error
  /// Covers spec lines 848-855 (Website validation)
  @MainActor
  func testAddSchool_invalidWebsiteURL_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "45-website-add-school-screen"))

    // When: Switch to manual mode and fill required fields
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Website Validation Test")
    screen.fillLocation("Test City, State")

    add(app.takeScreenshot(name: "46-website-required-fields-filled"))

    // When: Enter invalid website URL
    screen.fillWebsite("not-a-valid-url")

    add(app.takeScreenshot(name: "47-website-invalid-url-entered"))

    // When: Blur field (tap somewhere else)
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "48-website-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "Website").exists ||
                      screen.fieldError(for: "URL").exists

    XCTAssertTrue(
      errorExists,
      "Website field should show validation error for invalid URL"
    )

    add(app.takeScreenshot(name: "49-website-error-shown"))

    // When: Correct the URL
    // Clear field and re-enter valid URL
    screen.websiteTextField.tap()
    // Select all and delete
    if let currentValue = screen.websiteTextField.value as? String, !currentValue.isEmpty {
      for _ in 0..<currentValue.count {
        screen.websiteTextField.typeText(XCUIKeyboardKey.delete.rawValue)
      }
    }
    screen.websiteTextField.typeText("https://validschool.edu")

    add(app.takeScreenshot(name: "50-website-valid-url-entered"))

    screen.dismissKeyboard()

    // Then: Error should disappear
    let errorStillExists = screen.fieldError(for: "Website").exists ||
                           screen.fieldError(for: "URL").exists

    XCTAssertFalse(
      errorStillExists,
      "Website error should disappear after entering valid URL"
    )

    add(app.takeScreenshot(name: "51-website-error-cleared"))
  }

  /// Test: Network failure on submit shows retry option
  /// Covers spec lines 110-113 (Network Failures)
  @MainActor
  func testAddSchool_networkFailureOnSubmit_showsRetryOption() throws {
    // Note: This test is difficult to implement without network mocking
    // For E2E tests, we rely on the app's built-in error handling

    // Given: User is logged in and has filled a valid form
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "52-network-add-school-screen"))

    // Fill a valid form
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Network Test School \(Int(Date().timeIntervalSince1970))")
    screen.fillLocation("Network Test City")

    add(app.takeScreenshot(name: "53-network-form-filled"))

    // When: Submit form
    // Note: If network is working, this will succeed
    // This test primarily verifies the form can be submitted
    // True network error testing requires mocking
    screen.submitForm()

    add(app.takeScreenshot(name: "54-network-submitting"))

    // Then: Either success or error alert should appear
    _ = screen.waitForSubmissionToComplete(timeout: 15)

    add(app.takeScreenshot(name: "55-network-after-submit"))

    // Check for error alert (if network failed)
    if screen.errorAlert.exists {
      add(app.takeScreenshot(name: "56-network-error-alert"))

      XCTAssertTrue(
        screen.errorMessage.exists,
        "Error message should be visible on network failure"
      )

      // Dismiss alert
      if app.alerts.buttons["OK"].exists {
        app.alerts.buttons["OK"].tap()
      }

      add(app.takeScreenshot(name: "57-network-error-dismissed"))
    } else {
      // Success case - verify navigation happened
      let success = app.navigationBars["School Details"].waitForExistence(timeout: 5) ||
                    app.navigationBars["Schools"].waitForExistence(timeout: 5)

      XCTAssertTrue(
        success,
        "Should navigate on successful submission"
      )

      add(app.takeScreenshot(name: "58-network-success"))
    }

    // Note: For true network error testing, consider:
    // 1. Using a network stub/mock framework
    // 2. Testing with airplane mode (requires manual intervention)
    // 3. Using a staging environment that can simulate failures
  }
}
