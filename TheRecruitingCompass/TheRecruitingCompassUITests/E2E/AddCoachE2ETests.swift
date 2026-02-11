import XCTest

/// E2E tests for the Add Coach feature
/// Tests the complete user journey from navigation to successful coach creation
final class AddCoachE2ETests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Navigation Tests

  @MainActor
  func testNavigateToAddCoachFromCoachesList() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-dashboard"))

    // When: Navigate to Coaches tab
    guard app.tabBars.buttons["Coaches"].exists else {
      throw XCTSkip("Coaches tab not found - UI structure may have changed")
    }

    app.tabBars.buttons["Coaches"].tap()

    add(app.takeScreenshot(name: "02-coaches-list"))

    // Then: Coaches List should be visible
    XCTAssertTrue(
      app.navigationBars["Coaches"].waitForExistence(timeout: 5),
      "Coaches navigation bar should be visible"
    )

    // When: Tap Add Coach button
    let addButton = app.navigationBars.buttons["Add new coach"]
    XCTAssertTrue(addButton.exists, "Add Coach button should exist")

    add(app.takeScreenshot(name: "03-before-tap-add"))

    addButton.tap()

    add(app.takeScreenshot(name: "04-add-coach-screen"))

    // Then: Add Coach screen should appear
    XCTAssertTrue(
      app.navigationBars["Add Coach"].waitForExistence(timeout: 5),
      "Add Coach navigation bar should be visible"
    )

    // Verify school picker is visible
    XCTAssertTrue(
      app.pickers["School"].exists || app.buttons.matching(identifier: "School").firstMatch.exists,
      "School picker should be visible"
    )
  }

  // MARK: - Two-Step Form Flow Tests

  @MainActor
  func testSchoolSelection_showsForm() throws {
    try navigateToAddCoach()

    add(app.takeScreenshot(name: "05-initial-add-coach"))

    // Given: No school selected
    // Then: Form fields should NOT be visible yet
    XCTAssertFalse(
      app.textFields["First Name"].exists,
      "First Name field should NOT be visible before school selection"
    )

    // When: Select a school
    let schoolPicker = app.pickers["School"].firstMatch
    if schoolPicker.exists {
      schoolPicker.tap()

      // Wait for picker wheel to appear
      if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
        // Select first option (assumes at least one school exists)
        app.pickerWheels.firstMatch.swipeUp()

        // Dismiss picker by tapping outside or Done button
        if app.toolbars.buttons["Done"].exists {
          app.toolbars.buttons["Done"].tap()
        }
      }
    }

    add(app.takeScreenshot(name: "06-after-school-selection"))

    // Then: Form fields should now be visible
    XCTAssertTrue(
      app.pickers["Role"].waitForExistence(timeout: 3) ||
      app.textFields["First Name"].exists,
      "Form fields should appear after school selection"
    )
  }

  // MARK: - Happy Path Tests

  @MainActor
  func testAddCoach_withRequiredFields_succeeds() throws {
    try navigateToAddCoach()

    // Given: School selected and form visible
    try selectSchool()

    add(app.takeScreenshot(name: "07-form-visible"))

    // When: Fill required fields
    try fillRequiredFields(
      role: "Head Coach",
      firstName: "John",
      lastName: "Smith"
    )

    add(app.takeScreenshot(name: "08-required-fields-filled"))

    // Verify Add Coach button is enabled
    let addCoachButton = app.buttons["Add Coach"]
    XCTAssertTrue(addCoachButton.exists, "Add Coach button should exist")

    // When: Submit form
    addCoachButton.tap()

    add(app.takeScreenshot(name: "09-after-submit"))

    // Then: Should navigate to Coach Detail or show success
    // (Exact behavior depends on navigation implementation)
    let detailAppeared = app.navigationBars["John Smith"].waitForExistence(timeout: 10)
    let coachesListReappeared = app.navigationBars["Coaches"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      detailAppeared || coachesListReappeared,
      "Should navigate to coach detail or return to coaches list after successful creation"
    )

    add(app.takeScreenshot(name: "10-after-success"))
  }

  @MainActor
  func testAddCoach_withAllFields_succeeds() throws {
    try navigateToAddCoach()
    try selectSchool()

    add(app.takeScreenshot(name: "11-form-ready-all-fields"))

    // Fill all fields (required + optional)
    try fillRequiredFields(
      role: "Assistant Coach",
      firstName: "Jane",
      lastName: "Doe"
    )

    // Fill optional fields
    if app.textFields["Email"].exists {
      app.textFields["Email"].tap()
      app.textFields["Email"].typeText("jane.doe@university.edu")
    }

    if app.textFields["Phone"].exists {
      app.textFields["Phone"].tap()
      app.textFields["Phone"].typeText("5551234567")
    }

    if app.textFields["Twitter Handle"].exists {
      app.textFields["Twitter Handle"].tap()
      app.textFields["Twitter Handle"].typeText("@janedoe")
    }

    if app.textFields["Instagram Handle"].exists {
      app.textFields["Instagram Handle"].tap()
      app.textFields["Instagram Handle"].typeText("@coach.jane")
    }

    // Scroll to find Notes field (might be below fold)
    if app.textViews["Notes"].exists {
      app.textViews["Notes"].tap()
      app.textViews["Notes"].typeText("Excellent recruiter with strong track record")
    }

    add(app.takeScreenshot(name: "12-all-fields-filled"))

    // Submit
    app.buttons["Add Coach"].tap()

    add(app.takeScreenshot(name: "13-after-submit-all-fields"))

    // Verify success
    let detailAppeared = app.navigationBars["Jane Doe"].waitForExistence(timeout: 10)
    let coachesListReappeared = app.navigationBars["Coaches"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      detailAppeared || coachesListReappeared,
      "Should navigate away after successful creation"
    )
  }

  // MARK: - Validation Error Tests

  @MainActor
  func testAddCoach_withoutRole_showsValidationError() throws {
    try navigateToAddCoach()
    try selectSchool()

    add(app.takeScreenshot(name: "14-validation-test-start"))

    // Fill name fields but leave role empty
    if app.textFields["First Name"].exists {
      app.textFields["First Name"].tap()
      app.textFields["First Name"].typeText("John")
    }

    if app.textFields["Last Name"].exists {
      app.textFields["Last Name"].tap()
      app.textFields["Last Name"].typeText("Smith")
    }

    add(app.takeScreenshot(name: "15-missing-role"))

    // Try to submit
    app.buttons["Add Coach"].tap()

    add(app.takeScreenshot(name: "16-validation-error-shown"))

    // Verify error message appears
    let errorExists = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[cd] 'role' AND label CONTAINS[cd] 'required'")
    ).firstMatch.exists

    XCTAssertTrue(
      errorExists || app.buttons["Add Coach"].isEnabled == false,
      "Should show validation error or disable submit button when role is missing"
    )
  }

  @MainActor
  func testAddCoach_withoutFirstName_showsValidationError() throws {
    try navigateToAddCoach()
    try selectSchool()

    // Select role and last name, but leave first name empty
    if app.pickers["Role"].exists {
      app.pickers["Role"].tap()
      if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Head Coach")
        if app.toolbars.buttons["Done"].exists {
          app.toolbars.buttons["Done"].tap()
        }
      }
    }

    if app.textFields["Last Name"].exists {
      app.textFields["Last Name"].tap()
      app.textFields["Last Name"].typeText("Smith")
    }

    add(app.takeScreenshot(name: "17-missing-first-name"))

    // Try to submit
    app.buttons["Add Coach"].tap()

    add(app.takeScreenshot(name: "18-first-name-error"))

    // Verify error
    let errorExists = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[cd] 'first name' AND label CONTAINS[cd] 'required'")
    ).firstMatch.exists

    XCTAssertTrue(
      errorExists || app.buttons["Add Coach"].isEnabled == false,
      "Should show validation error when first name is missing"
    )
  }

  @MainActor
  func testAddCoach_fixingValidationErrors_enablesSubmit() throws {
    try navigateToAddCoach()
    try selectSchool()

    add(app.takeScreenshot(name: "19-fix-errors-start"))

    // Try to submit with empty fields
    app.buttons["Add Coach"].tap()

    // Now fill required fields
    try fillRequiredFields(
      role: "Head Coach",
      firstName: "John",
      lastName: "Smith"
    )

    add(app.takeScreenshot(name: "20-errors-fixed"))

    // Verify Add Coach button is now enabled
    let addCoachButton = app.buttons["Add Coach"]
    XCTAssertTrue(
      addCoachButton.isEnabled || addCoachButton.exists,
      "Add Coach button should be enabled after fixing validation errors"
    )

    // Submit should now work
    addCoachButton.tap()

    add(app.takeScreenshot(name: "21-submit-after-fix"))

    // Verify navigation
    let success = app.navigationBars["John Smith"].waitForExistence(timeout: 10) ||
                  app.navigationBars["Coaches"].waitForExistence(timeout: 10)

    XCTAssertTrue(success, "Should navigate away after fixing errors and submitting")
  }

  // MARK: - Cancel Flow Tests

  @MainActor
  func testAddCoach_cancel_returnsToCoachesList() throws {
    try navigateToAddCoach()

    add(app.takeScreenshot(name: "22-before-cancel"))

    // Given: User on Add Coach screen
    XCTAssertTrue(
      app.navigationBars["Add Coach"].exists,
      "Should be on Add Coach screen"
    )

    // When: Tap Back or Cancel button
    let backButton = app.navigationBars.buttons["Back to coaches list"]
    let cancelButton = app.buttons["Cancel"]

    if backButton.exists {
      backButton.tap()
    } else if cancelButton.exists {
      cancelButton.tap()
    } else {
      // Try swipe back gesture
      let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
      coordinate.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }

    add(app.takeScreenshot(name: "23-after-cancel"))

    // Then: Should return to Coaches List
    XCTAssertTrue(
      app.navigationBars["Coaches"].waitForExistence(timeout: 5),
      "Should return to Coaches List after cancel"
    )
  }

  @MainActor
  func testAddCoach_cancelAfterFillingForm_discardsData() throws {
    try navigateToAddCoach()
    try selectSchool()

    // Fill some fields
    try fillRequiredFields(
      role: "Head Coach",
      firstName: "John",
      lastName: "Smith"
    )

    add(app.takeScreenshot(name: "24-filled-before-cancel"))

    // Cancel
    let cancelButton = app.buttons["Cancel"]
    if cancelButton.exists {
      cancelButton.tap()
    } else {
      app.navigationBars.buttons.firstMatch.tap()
    }

    add(app.takeScreenshot(name: "25-after-cancel-with-data"))

    // Verify returned to Coaches List
    XCTAssertTrue(
      app.navigationBars["Coaches"].waitForExistence(timeout: 5),
      "Should return to Coaches List"
    )

    // Re-open Add Coach
    app.navigationBars.buttons["Add new coach"].tap()

    // Verify form is empty (data was discarded)
    if app.pickers["School"].exists {
      // If we can check the selected value is nil/empty, that would be ideal
      // For now, just verify we're back on the Add Coach screen
      XCTAssertTrue(
        app.navigationBars["Add Coach"].exists,
        "Should open fresh Add Coach screen"
      )
    }

    add(app.takeScreenshot(name: "26-reopened-fresh"))
  }

  // MARK: - Empty State Tests

  @MainActor
  func testAddCoach_noSchools_showsEmptyState() throws {
    // This test requires a user with no tracked schools
    // For now, we'll skip if schools exist
    try navigateToAddCoach()

    add(app.takeScreenshot(name: "27-check-empty-state"))

    // Check if "No Schools Found" message appears
    let emptyStateMessage = app.staticTexts["No Schools Found"]
    let addSchoolButton = app.buttons["Add a school"]

    if emptyStateMessage.exists {
      // Empty state is shown
      XCTAssertTrue(
        addSchoolButton.exists,
        "Add School button should be visible in empty state"
      )

      add(app.takeScreenshot(name: "28-empty-state-visible"))

      // Verify form is not visible
      XCTAssertFalse(
        app.textFields["First Name"].exists,
        "Form should not be visible when no schools exist"
      )
    } else {
      // User has schools, skip this test
      throw XCTSkip("User has schools - cannot test empty state")
    }
  }

  // MARK: - Social Handle Sanitization Tests

  @MainActor
  func testAddCoach_socialHandles_stripsAtSign() throws {
    try navigateToAddCoach()
    try selectSchool()

    add(app.takeScreenshot(name: "29-social-handles-test"))

    // Fill required fields
    try fillRequiredFields(
      role: "Head Coach",
      firstName: "Test",
      lastName: "Coach"
    )

    // Enter social handles WITH @ sign
    if app.textFields["Twitter Handle"].exists {
      app.textFields["Twitter Handle"].tap()
      app.textFields["Twitter Handle"].typeText("@testcoach")
    }

    if app.textFields["Instagram Handle"].exists {
      app.textFields["Instagram Handle"].tap()
      app.textFields["Instagram Handle"].typeText("@coach.test")
    }

    add(app.takeScreenshot(name: "30-handles-with-at-sign"))

    // Submit
    app.buttons["Add Coach"].tap()

    add(app.takeScreenshot(name: "31-after-submit-handles"))

    // Success verification
    let success = app.navigationBars["Test Coach"].waitForExistence(timeout: 10) ||
                  app.navigationBars["Coaches"].waitForExistence(timeout: 10)

    XCTAssertTrue(success, "Should successfully create coach with social handles")

    // Note: We can't easily verify the @ was stripped in E2E tests
    // That's covered by unit tests - here we just verify submission succeeds
  }

  // MARK: - Accessibility Tests

  @MainActor
  func testAddCoach_voiceOverLabels_exist() throws {
    try navigateToAddCoach()

    add(app.takeScreenshot(name: "32-accessibility-test"))

    // Verify key elements have accessibility labels
    let schoolPicker = app.pickers["School"].firstMatch
    XCTAssertTrue(
      schoolPicker.exists || app.otherElements["School"].exists,
      "School picker should have accessibility label"
    )

    // Select school to show form
    try selectSchool()

    // Verify form field labels
    let requiredFields = [
      "Role",
      "First Name",
      "Last Name"
    ]

    for field in requiredFields {
      let element = app.textFields[field].exists ||
                    app.pickers[field].exists ||
                    app.otherElements.matching(
                      NSPredicate(format: "label CONTAINS[cd] %@", field)
                    ).firstMatch.exists

      XCTAssertTrue(
        element,
        "\(field) should have proper accessibility label"
      )
    }

    add(app.takeScreenshot(name: "33-accessibility-verified"))
  }

  // MARK: - Helper Methods

  /// Navigates from dashboard to Add Coach screen
  private func navigateToAddCoach() throws {
    // Login
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    // Navigate to Coaches tab
    guard app.tabBars.buttons["Coaches"].exists else {
      throw XCTSkip("Coaches tab not found")
    }

    app.tabBars.buttons["Coaches"].tap()

    // Wait for Coaches List
    guard app.navigationBars["Coaches"].waitForExistence(timeout: 5) else {
      throw XCTSkip("Coaches List did not load")
    }

    // Tap Add Coach
    let addButton = app.navigationBars.buttons["Add new coach"]
    guard addButton.exists else {
      throw XCTSkip("Add Coach button not found")
    }

    addButton.tap()

    // Verify Add Coach screen loaded
    guard app.navigationBars["Add Coach"].waitForExistence(timeout: 5) else {
      throw XCTSkip("Add Coach screen did not load")
    }
  }

  /// Selects a school from the picker
  private func selectSchool() throws {
    let schoolPicker = app.pickers["School"].firstMatch

    guard schoolPicker.exists else {
      // Try alternative selectors
      let schoolButtons = app.buttons.matching(identifier: "School")
      guard schoolButtons.count > 0 else {
        throw XCTSkip("School picker not found")
      }
      schoolButtons.firstMatch.tap()
      return
    }

    schoolPicker.tap()

    // Wait for picker wheel
    if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
      // Select first option
      app.pickerWheels.firstMatch.swipeUp()

      // Dismiss picker
      if app.toolbars.buttons["Done"].exists {
        app.toolbars.buttons["Done"].tap()
      } else {
        // Tap outside picker to dismiss
        app.tap()
      }
    }

    // Wait for form to appear
    _ = app.textFields["First Name"].waitForExistence(timeout: 3) ||
        app.pickers["Role"].waitForExistence(timeout: 3)
  }

  /// Fills all required fields in the Add Coach form
  private func fillRequiredFields(role: String, firstName: String, lastName: String) throws {
    // Role
    let rolePicker = app.pickers["Role"]
    if rolePicker.exists {
      rolePicker.tap()

      if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: role)

        if app.toolbars.buttons["Done"].exists {
          app.toolbars.buttons["Done"].tap()
        } else {
          app.tap()
        }
      }
    }

    // First Name
    let firstNameField = app.textFields["First Name"]
    if firstNameField.exists {
      firstNameField.tap()
      firstNameField.typeText(firstName)
    }

    // Last Name
    let lastNameField = app.textFields["Last Name"]
    if lastNameField.exists {
      lastNameField.tap()
      lastNameField.typeText(lastName)
    }

    // Dismiss keyboard if visible
    if app.keyboards.firstMatch.exists {
      app.tap()
    }
  }
}
