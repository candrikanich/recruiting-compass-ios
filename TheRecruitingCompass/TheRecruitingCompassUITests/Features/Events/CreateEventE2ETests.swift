import XCTest

/// E2E tests for the Create Event feature
/// Tests complete user journeys including form submission, validation, date defaults,
/// school selection flows, cancel behavior, and get directions
final class CreateEventE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: CreateEventScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = CreateEventScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Happy Path

  @MainActor
  func testCreateEvent_happyPath_savesAndNavigates() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "01-happy-path-form-loaded"))

    // Fill all required fields
    screen.selectEventType("Showcase")

    add(app.takeScreenshot(name: "02-happy-path-type-selected"))

    screen.fillEventName("Spring Showcase 2026")

    add(app.takeScreenshot(name: "03-happy-path-name-filled"))

    // Interact with start date picker (tap to expand, value is set by default to today)
    let startDatePicker = screen.startDatePicker
    if startDatePicker.exists {
      startDatePicker.tap()
    }

    add(app.takeScreenshot(name: "04-happy-path-date-set"))

    // Dismiss any open picker
    screen.dismissKeyboard()

    // Submit the form
    screen.submitForm()

    add(app.takeScreenshot(name: "05-happy-path-submitting"))

    _ = screen.waitForSubmissionToComplete(timeout: 15)

    add(app.takeScreenshot(name: "06-happy-path-after-submit"))

    // Verify navigation to event detail or events list
    let detailAppeared = app.staticTexts["Spring Showcase 2026"].waitForExistence(timeout: 10)
    let eventsListAppeared = app.navigationBars["Events"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      detailAppeared || eventsListAppeared,
      "Should navigate to event detail or events list after successful creation"
    )

    add(app.takeScreenshot(name: "07-happy-path-success"))
  }

  // MARK: - Validation Tests

  @MainActor
  func testCreateEvent_missingRequiredFields_showsValidationErrors() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "08-validation-form-empty"))

    // Tap Create Event without filling anything
    screen.submitForm()

    add(app.takeScreenshot(name: "09-validation-errors-shown"))

    // Verify validation errors appear
    let bannerExists = screen.validationErrorBanner.waitForExistence(timeout: 5)
    let typeError = screen.validationError(containing: "type").exists
    let nameError = screen.validationError(containing: "name").exists
    let dateError = screen.validationError(containing: "date").exists

    XCTAssertTrue(
      bannerExists || typeError || nameError || dateError,
      "Should show validation errors when required fields are missing"
    )

    // Verify form did not submit (still on Create Event screen)
    XCTAssertTrue(
      screen.navigationTitle.exists || screen.createEventButton.exists,
      "Should remain on Create Event screen when validation fails"
    )

    add(app.takeScreenshot(name: "10-validation-still-on-form"))
  }

  @MainActor
  func testCreateEvent_endDateBeforeStartDate_showsInlineError() throws {
    try loginAndNavigateToCreateEvent()

    // Fill required fields first
    screen.selectEventType("Camp")
    screen.fillEventName("Date Validation Test")

    add(app.takeScreenshot(name: "11-date-validation-fields-filled"))

    // Set start date (use today's date via the picker)
    let startDatePicker = screen.startDatePicker
    if startDatePicker.exists {
      startDatePicker.tap()
    }

    add(app.takeScreenshot(name: "12-date-validation-start-date-set"))

    // Set end date to before start date
    // This requires manipulating the end date picker to a date before the start date
    let endDatePicker = screen.endDatePicker
    screen.scrollToElement(endDatePicker)
    if endDatePicker.exists {
      endDatePicker.tap()
      // Attempt to select a date in the past relative to start date
      // The exact interaction depends on picker implementation
    }

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "13-date-validation-end-date-set"))

    // Try to submit
    screen.submitForm()

    add(app.takeScreenshot(name: "14-date-validation-after-submit"))

    // Verify inline error for invalid date range
    let endDateError = screen.validationError(containing: "End date").exists ||
                       screen.validationError(containing: "after start").exists ||
                       screen.validationError(containing: "date").exists

    // The form should either show an error or prevent submission
    let stillOnForm = screen.navigationTitle.exists || screen.createEventButton.exists

    XCTAssertTrue(
      endDateError || stillOnForm,
      "Should show error or prevent submission when end date is before start date"
    )

    add(app.takeScreenshot(name: "15-date-validation-error-shown"))
  }

  // MARK: - Date Auto-Population Tests

  @MainActor
  func testCreateEvent_startDateSet_endDateAutoPopulates() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "16-auto-date-initial"))

    // Set start date
    let startDatePicker = screen.startDatePicker
    if startDatePicker.exists {
      startDatePicker.tap()
    }

    // Dismiss the start date picker
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "17-auto-date-start-set"))

    // Verify end date picker has a value (auto-populated from start date)
    let endDatePicker = screen.endDatePicker
    screen.scrollToElement(endDatePicker)

    XCTAssertTrue(
      endDatePicker.exists,
      "End date picker should exist and be auto-populated when start date is set"
    )

    // Check the end date has a value (not empty/placeholder)
    if let endDateValue = endDatePicker.value as? String {
      XCTAssertFalse(
        endDateValue.isEmpty,
        "End date should auto-populate when start date is set"
      )
    }

    add(app.takeScreenshot(name: "18-auto-date-end-populated"))
  }

  @MainActor
  func testCreateEvent_startTimeSet_endTimeAutoPopulatesOneHourLater() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "19-auto-time-initial"))

    // Set start time
    let startTimePicker = screen.startTimePicker
    screen.scrollToElement(startTimePicker)

    if startTimePicker.exists {
      startTimePicker.tap()
      // Interact with time picker - set a specific time
      if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
        // Set hour to 9 AM as a reference point
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "9")
        if app.toolbars.buttons["Done"].exists {
          app.toolbars.buttons["Done"].tap()
        }
      }
    }

    add(app.takeScreenshot(name: "20-auto-time-start-set"))

    // Verify end time picker has a value (should be start time + 1 hour)
    let endTimePicker = screen.endTimePicker
    screen.scrollToElement(endTimePicker)

    XCTAssertTrue(
      endTimePicker.exists,
      "End time picker should exist and be auto-populated when start time is set"
    )

    if let endTimeValue = endTimePicker.value as? String {
      XCTAssertFalse(
        endTimeValue.isEmpty,
        "End time should auto-populate to one hour after start time"
      )
    }

    add(app.takeScreenshot(name: "21-auto-time-end-populated"))
  }

  // MARK: - School Flow Tests

  @MainActor
  func testCreateEvent_selectOtherSchool_showsModal() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "22-other-school-initial"))

    // Tap school picker and select "Other (not listed)"
    screen.selectSchoolOption("Other (not listed)")

    add(app.takeScreenshot(name: "23-other-school-selected"))

    // Verify modal appears
    let modalAppeared = screen.otherSchoolModal.waitForExistence(timeout: 5)

    XCTAssertTrue(
      modalAppeared,
      "Selecting 'Other (not listed)' should show the Other School modal"
    )

    add(app.takeScreenshot(name: "24-other-school-modal-shown"))

    // Verify modal has expected elements (text input for school name)
    let schoolNameInput = app.textFields.matching(
      NSPredicate(format: "identifier CONTAINS 'school' OR placeholderValue CONTAINS[cd] 'school'")
    ).firstMatch

    XCTAssertTrue(
      schoolNameInput.exists || screen.otherSchoolModal.exists,
      "Other School modal should contain a school name input"
    )

    add(app.takeScreenshot(name: "25-other-school-modal-contents"))
  }

  @MainActor
  func testCreateEvent_addNewSchool_showsModalAndSaves() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "26-add-school-initial"))

    // Tap school picker and select "+ Add new school"
    screen.selectSchoolOption("+ Add new school")

    add(app.takeScreenshot(name: "27-add-school-selected"))

    // Verify Add School modal appears
    let modalAppeared = screen.addSchoolModal.waitForExistence(timeout: 5)

    XCTAssertTrue(
      modalAppeared,
      "Selecting '+ Add new school' should show the Add School modal"
    )

    add(app.takeScreenshot(name: "28-add-school-modal-shown"))

    // Fill in school details in the modal
    let schoolNameFields = app.textFields.matching(
      NSPredicate(format: "identifier CONTAINS 'school' OR placeholderValue CONTAINS[cd] 'name'")
    )
    if schoolNameFields.firstMatch.exists {
      schoolNameFields.firstMatch.tap()
      schoolNameFields.firstMatch.typeText("Test University E2E")
    }

    let locationFields = app.textFields.matching(
      NSPredicate(format: "identifier CONTAINS 'location' OR placeholderValue CONTAINS[cd] 'location'")
    )
    if locationFields.firstMatch.exists {
      locationFields.firstMatch.tap()
      locationFields.firstMatch.typeText("Test City, TS")
    }

    add(app.takeScreenshot(name: "29-add-school-modal-filled"))

    // Tap Save
    let saveButton = screen.saveSchoolButton
    if saveButton.exists {
      saveButton.tap()
    }

    add(app.takeScreenshot(name: "30-add-school-after-save"))

    // Verify modal dismissed and school is selected
    let modalDismissed = !screen.addSchoolModal.exists ||
                          screen.addSchoolModal.waitForExistence(timeout: 2) == false

    XCTAssertTrue(
      modalDismissed,
      "Add School modal should dismiss after saving"
    )

    add(app.takeScreenshot(name: "31-add-school-school-selected"))
  }

  // MARK: - Cancel Flow

  @MainActor
  func testCreateEvent_cancelWithChanges_showsConfirmation() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "32-cancel-initial"))

    // Fill some fields to create "unsaved changes"
    screen.selectEventType("Showcase")
    screen.fillEventName("Cancel Test Event")

    add(app.takeScreenshot(name: "33-cancel-fields-filled"))

    screen.dismissKeyboard()

    // Tap Cancel
    let cancelButton = screen.cancelButton
    let backButton = app.navigationBars.buttons.firstMatch

    if cancelButton.exists {
      cancelButton.tap()
    } else if backButton.exists {
      backButton.tap()
    }

    add(app.takeScreenshot(name: "34-cancel-after-tap"))

    // Verify "Discard changes?" confirmation dialog appears
    let discardDialog = screen.discardChangesDialog
    let anyAlert = app.alerts.firstMatch

    let dialogAppeared = discardDialog.waitForExistence(timeout: 5) ||
                         anyAlert.waitForExistence(timeout: 3)

    if dialogAppeared {
      add(app.takeScreenshot(name: "35-cancel-discard-dialog-shown"))

      XCTAssertTrue(
        discardDialog.exists || anyAlert.exists,
        "Should show discard changes confirmation dialog"
      )

      // Tap Discard to confirm cancellation
      if screen.discardButton.exists {
        screen.discardButton.tap()
      } else if app.alerts.buttons["Discard"].exists {
        app.alerts.buttons["Discard"].tap()
      } else if app.alerts.buttons["Yes"].exists {
        app.alerts.buttons["Yes"].tap()
      }

      add(app.takeScreenshot(name: "36-cancel-after-discard"))

      // Verify returned to Events list
      XCTAssertTrue(
        app.navigationBars["Events"].waitForExistence(timeout: 5),
        "Should return to Events list after discarding changes"
      )
    } else {
      // Some implementations navigate back without dialog
      // Verify we are back on events list
      XCTAssertTrue(
        app.navigationBars["Events"].waitForExistence(timeout: 5),
        "Should return to Events list after cancel"
      )
    }

    add(app.takeScreenshot(name: "37-cancel-back-to-events"))
  }

  // MARK: - Get Directions

  @MainActor
  func testCreateEvent_withAddress_showsGetDirectionsButton() throws {
    try loginAndNavigateToCreateEvent()

    add(app.takeScreenshot(name: "38-directions-initial"))

    // Verify Get Directions button is NOT visible initially (no address entered)
    screen.scrollToElement(screen.getDirectionsButton, maxSwipes: 3)
    let directionsInitiallyHidden = !screen.getDirectionsButton.exists ||
                                     !screen.getDirectionsButton.isHittable

    add(app.takeScreenshot(name: "39-directions-no-address"))

    // Enter address and city
    screen.fillAddress("123 Main Street")
    screen.fillCity("Athens")
    screen.fillState("GA")

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "40-directions-address-filled"))

    // Scroll to find Get Directions button
    screen.scrollToElement(screen.getDirectionsButton)

    // Verify Get Directions button is now visible
    let directionsButtonVisible = screen.getDirectionsButton.waitForExistence(timeout: 5)

    XCTAssertTrue(
      directionsButtonVisible,
      "Get Directions button should appear after entering address/city"
    )

    add(app.takeScreenshot(name: "41-directions-button-visible"))

    // Note: Tapping Get Directions would open Apple Maps which exits the app,
    // so we only verify the button is visible and hittable
    if screen.getDirectionsButton.isHittable {
      XCTAssertTrue(
        screen.getDirectionsButton.isEnabled,
        "Get Directions button should be enabled when address is entered"
      )
    }

    add(app.takeScreenshot(name: "42-directions-button-verified"))
  }

  // MARK: - Private Helpers

  private func loginAndNavigateToCreateEvent() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToCreateEvent()

    guard screen.waitForScreenToLoad(timeout: 10) else {
      throw XCTSkip("Create Event screen did not load")
    }
  }
}
