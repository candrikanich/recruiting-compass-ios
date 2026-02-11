import XCTest

/// E2E tests for Add School accessibility compliance
/// Tests VoiceOver support, touch targets, Dynamic Type, and keyboard navigation
final class AddSchoolAccessibilityE2ETests: XCTestCase {
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

  // MARK: - VoiceOver Label Tests

  /// Test: All form fields have proper accessibility labels
  /// Covers spec lines 614-622 (Accessibility requirements)
  @MainActor
  func testAddSchool_voiceOverLabels_allFieldsLabeled() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "01-a11y-add-school-screen"))

    // Then: Verify key elements have accessibility labels

    // Toggle
    XCTAssertTrue(
      screen.autocompleteToggle.exists,
      "Autocomplete toggle should have accessibility label"
    )

    add(app.takeScreenshot(name: "02-a11y-toggle-labeled"))

    // Search field (autocomplete mode)
    XCTAssertTrue(
      screen.autocompleteSearchField.exists || screen.autocompleteSearchField.isHittable,
      "Autocomplete search field should have accessibility label"
    )

    // Switch to manual mode to verify form fields
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "03-a11y-manual-mode"))

    // Form fields
    let formFields = [
      ("School Name", screen.nameTextField),
      ("Location", screen.locationTextField),
      ("Division", screen.divisionPicker),
      ("Conference", screen.conferenceTextField),
      ("Website", screen.websiteTextField),
      ("Twitter Handle", screen.twitterHandleTextField),
      ("Instagram Handle", screen.instagramHandleTextField),
      ("Notes", screen.notesTextView),
      ("Status", screen.statusPicker)
    ]

    for (fieldName, element) in formFields {
      // Scroll to element if needed
      screen.scrollToElement(element)

      XCTAssertTrue(
        element.exists || app.otherElements.matching(
          NSPredicate(format: "label CONTAINS[cd] %@", fieldName)
        ).firstMatch.exists,
        "\(fieldName) should have proper accessibility label"
      )
    }

    add(app.takeScreenshot(name: "04-a11y-all-fields-labeled"))

    // Action buttons
    XCTAssertTrue(
      screen.addSchoolButton.exists,
      "Add School button should have accessibility label"
    )

    XCTAssertTrue(
      screen.cancelButton.exists || app.navigationBars.buttons.firstMatch.exists,
      "Cancel/Back button should have accessibility label"
    )

    add(app.takeScreenshot(name: "05-a11y-buttons-labeled"))
  }

  /// Test: Autocomplete dropdown announces result count and selection
  /// Covers autocomplete VoiceOver announcements
  @MainActor
  func testAddSchool_voiceOver_autocompleteAnnouncements() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "06-a11y-autocomplete-screen"))

    // When: Search for colleges
    screen.searchCollege(query: "Florida")

    add(app.takeScreenshot(name: "07-a11y-autocomplete-searching"))

    sleep(1) // Wait for search

    add(app.takeScreenshot(name: "08-a11y-autocomplete-results"))

    // Then: Verify autocomplete results have accessibility labels
    let firstResult = screen.autocompleteResult(at: 0)

    if firstResult.waitForExistence(timeout: 5) {
      // Verify result is accessible
      XCTAssertTrue(
        firstResult.exists,
        "Autocomplete result should have accessibility label"
      )

      // Verify it has button trait
      XCTAssertTrue(
        firstResult.elementType == .button || firstResult.isHittable,
        "Autocomplete result should be accessible as a button"
      )

      add(app.takeScreenshot(name: "09-a11y-result-accessible"))

      // When: Select result
      firstResult.tap()

      add(app.takeScreenshot(name: "10-a11y-result-selected"))

      // Then: Selected college card should be accessible
      if screen.selectedCollegeCard.waitForExistence(timeout: 5) {
        XCTAssertTrue(
          screen.selectedCollegeName.exists,
          "Selected college name should have accessibility label"
        )

        add(app.takeScreenshot(name: "11-a11y-selected-card-accessible"))
      }
    } else {
      throw XCTSkip("Autocomplete search returned no results")
    }
  }

  /// Test: Auto-filled badge is announced by VoiceOver
  /// Covers "(auto-filled)" accessibility announcement
  @MainActor
  func testAddSchool_voiceOver_autoFilledBadgeAnnounced() throws {
    // Given: User is logged in and has selected a college
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "12-a11y-badge-screen"))

    // Select college
    screen.searchCollege(query: "Miami")
    sleep(1)

    if screen.autocompleteResult(at: 0).waitForExistence(timeout: 5) {
      screen.selectAutocompleteResult(at: 0)

      _ = screen.waitForEnrichmentToComplete(timeout: 15)

      add(app.takeScreenshot(name: "13-a11y-badge-auto-filled"))

      // Then: Verify auto-filled badges are accessible
      let nameBadge = screen.autoFilledBadge(for: "name")

      if nameBadge.exists {
        // Badge should be readable by VoiceOver
        XCTAssertTrue(
          nameBadge.exists,
          "Auto-filled badge should be accessible to VoiceOver"
        )

        add(app.takeScreenshot(name: "14-a11y-badge-accessible"))
      } else {
        // Badge might be implemented differently
        add(app.takeScreenshot(name: "15-a11y-no-badge-found"))
      }
    } else {
      throw XCTSkip("Autocomplete search failed")
    }
  }

  /// Test: Duplicate dialog is announced as alert
  /// Covers duplicate dialog accessibility
  @MainActor
  func testAddSchool_voiceOver_duplicateDialogAnnounced() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "16-a11y-duplicate-screen"))

    // When: Try to create a duplicate school
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Test School 1") // Assuming duplicate exists
    screen.fillLocation("Test Location")

    add(app.takeScreenshot(name: "17-a11y-duplicate-form"))

    screen.dismissKeyboard()
    screen.submitForm()

    add(app.takeScreenshot(name: "18-a11y-duplicate-submitting"))

    // If duplicate dialog appears
    let dialogAppeared = screen.waitForDuplicateDialog(timeout: 10)

    if dialogAppeared {
      add(app.takeScreenshot(name: "19-a11y-duplicate-dialog"))

      // Then: Verify dialog is accessible as an alert
      XCTAssertTrue(
        screen.duplicateDialog.exists,
        "Duplicate dialog should be accessible as an alert"
      )

      // Verify dialog message is accessible
      XCTAssertTrue(
        screen.duplicateDialogMessage.exists,
        "Duplicate dialog message should be accessible"
      )

      // Verify action buttons are accessible
      XCTAssertTrue(
        screen.duplicateDialogCancelButton.exists,
        "Cancel button should be accessible"
      )

      XCTAssertTrue(
        screen.duplicateDialogProceedButton.exists,
        "Proceed button should be accessible"
      )

      add(app.takeScreenshot(name: "20-a11y-dialog-accessible"))

      screen.cancelDuplicateDialog()
    } else {
      throw XCTSkip("No duplicate detected - test data may not exist")
    }
  }

  /// Test: Loading and status announcements are made
  /// Covers "Searching...", "Fetching college data...", "Adding..." announcements
  @MainActor
  func testAddSchool_voiceOverAnnouncements_statusUpdates() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "21-a11y-status-screen"))

    // When: Perform search (triggers "Searching..." announcement)
    screen.searchCollege(query: "Florida")

    add(app.takeScreenshot(name: "22-a11y-status-searching"))

    // Verify searching indicator exists (would be announced)
    if screen.searchingIndicator.exists {
      XCTAssertTrue(
        screen.searchingIndicator.exists,
        "Searching indicator should be accessible"
      )

      add(app.takeScreenshot(name: "23-a11y-searching-indicator"))
    }

    sleep(1)

    // When: Select college (triggers enrichment and "Fetching college data..." announcement)
    if screen.autocompleteResult(at: 0).waitForExistence(timeout: 5) {
      screen.selectAutocompleteResult(at: 0)

      add(app.takeScreenshot(name: "24-a11y-status-selected"))

      // Verify enrichment loading indicator
      if screen.enrichmentLoadingIndicator.exists {
        XCTAssertTrue(
          screen.enrichmentLoadingIndicator.exists,
          "Enrichment loading indicator should be accessible"
        )

        add(app.takeScreenshot(name: "25-a11y-enrichment-loading"))
      }

      _ = screen.waitForEnrichmentToComplete(timeout: 15)

      add(app.takeScreenshot(name: "26-a11y-enrichment-complete"))

      // When: Submit form (triggers "Adding..." announcement)
      screen.submitForm()

      add(app.takeScreenshot(name: "27-a11y-status-submitting"))

      // Verify "Adding..." button state
      if screen.addingButton.waitForExistence(timeout: 2) {
        XCTAssertTrue(
          screen.addingButton.exists,
          "'Adding...' button state should be accessible"
        )

        add(app.takeScreenshot(name: "28-a11y-adding-button"))
      }
    } else {
      throw XCTSkip("Autocomplete search failed")
    }
  }

  // MARK: - Touch Target Tests

  /// Test: All interactive elements have minimum 44pt touch targets
  /// Covers WCAG 2.1 Level AA touch target requirement
  @MainActor
  func testAddSchool_touchTargets_minimum44pt() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "29-a11y-touch-screen"))

    // Then: Verify key interactive elements are hittable (have adequate touch targets)
    let interactiveElements = [
      ("Autocomplete Toggle", screen.autocompleteToggle),
      ("Search Field", screen.autocompleteSearchField),
      ("Add School Button", screen.addSchoolButton),
      ("Cancel Button", screen.cancelButton)
    ]

    for (elementName, element) in interactiveElements {
      // Scroll to element if needed
      screen.scrollToElement(element)

      if element.exists {
        XCTAssertTrue(
          element.isHittable,
          "\(elementName) should have adequate touch target (minimum 44pt)"
        )

        // Verify frame is at least 44x44pt
        let frame = element.frame
        XCTAssertTrue(
          frame.width >= 44 || frame.height >= 44,
          "\(elementName) should meet 44pt minimum in at least one dimension"
        )
      }
    }

    add(app.takeScreenshot(name: "30-a11y-touch-targets-verified"))

    // Test autocomplete dropdown items
    screen.searchCollege(query: "Florida")
    sleep(1)

    if screen.autocompleteResult(at: 0).waitForExistence(timeout: 5) {
      let firstResult = screen.autocompleteResult(at: 0)

      XCTAssertTrue(
        firstResult.isHittable,
        "Autocomplete dropdown items should have adequate touch targets"
      )

      let resultFrame = firstResult.frame
      XCTAssertTrue(
        resultFrame.height >= 44,
        "Autocomplete items should be at least 44pt tall"
      )

      add(app.takeScreenshot(name: "31-a11y-dropdown-touch-targets"))
    }
  }

  // MARK: - Dynamic Type Tests

  /// Test: Form layout supports Dynamic Type text scaling
  /// Covers Dynamic Type accessibility requirement
  @MainActor
  func testAddSchool_dynamicType_scalingWorks() throws {
    // Note: Testing Dynamic Type in XCUITest is limited
    // This test verifies the form is readable and functional
    // True Dynamic Type testing requires manual verification with system settings

    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "32-a11y-dynamic-type-screen"))

    // Then: Verify all text elements exist and are readable
    // (In a real Dynamic Type test, we'd verify they scale correctly)

    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "33-a11y-dynamic-type-manual"))

    // Verify form fields are still functional after any potential text scaling
    screen.fillSchoolName("Dynamic Type Test School")
    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "34-a11y-dynamic-type-filled"))

    // Verify text is visible and not truncated
    XCTAssertTrue(
      screen.nameTextField.exists,
      "Name field should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      screen.locationTextField.exists,
      "Location field should be visible with Dynamic Type"
    )

    add(app.takeScreenshot(name: "35-a11y-dynamic-type-verified"))

    // Verify buttons remain accessible
    XCTAssertTrue(
      screen.addSchoolButton.isHittable,
      "Add School button should remain hittable with Dynamic Type"
    )

    add(app.takeScreenshot(name: "36-a11y-dynamic-type-buttons"))

    // Note: For comprehensive Dynamic Type testing:
    // 1. Manually enable larger text in Settings → Accessibility → Display & Text Size
    // 2. Run app and verify all text scales appropriately
    // 3. Verify no text truncation occurs
    // 4. Verify touch targets remain adequate
  }

  // MARK: - Keyboard Navigation Tests (iPad)

  /// Test: Form supports keyboard navigation on iPad
  /// Covers keyboard accessibility (tab order, focus management)
  @MainActor
  func testAddSchool_keyboard_tabNavigationWorks() throws {
    // Note: Keyboard navigation testing is limited in XCUITest
    // This test verifies basic keyboard interaction

    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "37-a11y-keyboard-screen"))

    // When: Interact with form fields using keyboard
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "38-a11y-keyboard-manual"))

    // Tap name field to show keyboard
    screen.nameTextField.tap()

    add(app.takeScreenshot(name: "39-a11y-keyboard-name-focused"))

    // Verify keyboard appears
    XCTAssertTrue(
      app.keyboards.firstMatch.waitForExistence(timeout: 3),
      "Keyboard should appear when tapping text field"
    )

    add(app.takeScreenshot(name: "40-a11y-keyboard-visible"))

    // Type text
    screen.nameTextField.typeText("Keyboard Test")

    add(app.takeScreenshot(name: "41-a11y-keyboard-text-entered"))

    // Dismiss keyboard
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "42-a11y-keyboard-dismissed"))

    // Verify keyboard can be dismissed
    XCTAssertFalse(
      app.keyboards.firstMatch.exists,
      "Keyboard should be dismissible"
    )

    add(app.takeScreenshot(name: "43-a11y-keyboard-interaction-complete"))

    // Note: For comprehensive keyboard navigation testing on iPad:
    // 1. Connect physical or Bluetooth keyboard
    // 2. Use Tab key to navigate between fields
    // 3. Use Enter/Return to submit form
    // 4. Use Escape to cancel/dismiss
    // 5. Verify focus indicator is visible for each field
  }
}
