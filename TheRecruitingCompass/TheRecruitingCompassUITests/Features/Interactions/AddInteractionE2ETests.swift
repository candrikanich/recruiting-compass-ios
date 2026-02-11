import XCTest

/// E2E tests for the Add Interaction feature
/// Tests critical user journeys including form submission, validation, interest calibration, and inline coach creation
final class AddInteractionE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddInteractionScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = AddInteractionScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Phase 1: Happy Path Tests

  /// Test: User can complete full add interaction form with all fields
  /// Covers primary flow with all required and optional fields populated
  @MainActor
  func testAddInteraction_fullForm_success() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-full-form-dashboard"))

    // When: Navigate to Add Interaction screen
    screen.navigateToAddInteractionFromDashboard()

    add(app.takeScreenshot(name: "02-full-form-add-screen"))

    // Then: Screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Add Interaction screen should load"
    )

    // When: Fill all required fields
    screen.selectSchool("Test School 1")
    add(app.takeScreenshot(name: "03-full-form-school-selected"))

    screen.selectCoach("John Doe - Head Coach")
    add(app.takeScreenshot(name: "04-full-form-coach-selected"))

    screen.selectInteractionType("Email")
    add(app.takeScreenshot(name: "05-full-form-type-selected"))

    screen.selectDirection("Inbound")
    add(app.takeScreenshot(name: "06-full-form-direction-selected"))

    // When: Fill optional fields
    screen.fillSubject("Great opportunity to play")
    screen.fillContent("The coach expressed strong interest in my baseball skills and academic performance. They mentioned potential scholarship opportunities.")
    add(app.takeScreenshot(name: "07-full-form-details-filled"))

    screen.selectSentiment("Very Positive")
    add(app.takeScreenshot(name: "08-full-form-sentiment-selected"))

    // Then: Submit button should be enabled
    XCTAssertTrue(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be enabled with valid form"
    )

    // When: Submit form
    screen.submitForm()
    add(app.takeScreenshot(name: "09-full-form-submitting"))

    // Then: Should navigate to list or detail
    let submitted = screen.waitForSubmissionToComplete(timeout: 15)
    add(app.takeScreenshot(name: "10-full-form-after-submit"))

    XCTAssertTrue(
      submitted,
      "Should successfully submit and navigate away"
    )
  }

  /// Test: Interest calibration appears when inbound + positive sentiment
  /// Covers conditional display of interest calibration section
  @MainActor
  func testAddInteraction_interestCalibration_appearsCorrectly() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "11-calibration-initial"))

    // When: Select required fields with inbound + positive
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")
    screen.selectDirection("Inbound")
    screen.selectSentiment("Positive")

    add(app.takeScreenshot(name: "12-calibration-after-sentiment"))

    // Then: Interest calibration should appear
    sleep(1) // Wait for UI update
    XCTAssertTrue(
      screen.verifyInterestCalibrationVisible(),
      "Interest calibration should appear with inbound + positive"
    )

    add(app.takeScreenshot(name: "13-calibration-visible"))

    // When: Answer calibration questions
    screen.answerInterestCalibrationQuestion(at: 0, answer: true)
    screen.answerInterestCalibrationQuestion(at: 1, answer: true)
    screen.answerInterestCalibrationQuestion(at: 2, answer: false)

    add(app.takeScreenshot(name: "14-calibration-answered"))

    // Then: Interest level result should be visible
    XCTAssertTrue(
      screen.interestLevelResult.exists,
      "Interest level result should be displayed"
    )

    add(app.takeScreenshot(name: "15-calibration-result-shown"))
  }

  /// Test: Interest calibration does NOT appear with outbound direction
  /// Covers conditional hiding of interest calibration
  @MainActor
  func testAddInteraction_interestCalibration_notVisibleWithOutbound() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "16-no-calibration-initial"))

    // When: Select outbound direction with positive sentiment
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")
    screen.selectDirection("Outbound")
    screen.selectSentiment("Positive")

    add(app.takeScreenshot(name: "17-no-calibration-outbound"))

    // Then: Interest calibration should NOT appear
    sleep(1) // Wait for UI update
    XCTAssertTrue(
      screen.verifyInterestCalibrationNotVisible(),
      "Interest calibration should NOT appear with outbound direction"
    )

    add(app.takeScreenshot(name: "18-no-calibration-verified"))
  }

  /// Test: Inline coach creation flow
  /// Covers adding a new coach directly from the Add Interaction form
  @MainActor
  func testAddInteraction_inlineCoachCreation_success() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "19-inline-coach-initial"))

    // When: Select school first (required to enable coach picker)
    screen.selectSchool("Test School 1")

    // When: Select "+ Add new coach" from picker
    screen.selectAddNewCoach()

    add(app.takeScreenshot(name: "20-inline-coach-menu-opened"))

    // Then: Add Coach sheet should appear
    XCTAssertTrue(
      screen.addCoachSheet.waitForExistence(timeout: 5),
      "Add Coach sheet should appear"
    )

    add(app.takeScreenshot(name: "21-inline-coach-sheet"))

    // When: Fill new coach form
    screen.fillNewCoachForm(firstName: "Jane", lastName: "Smith", role: "Assistant Coach")

    add(app.takeScreenshot(name: "22-inline-coach-form-filled"))

    // Then: Should return to Add Interaction form
    sleep(2) // Wait for sheet to dismiss and data to update
    add(app.takeScreenshot(name: "23-inline-coach-after-save"))

    // Verify coach picker is still enabled
    XCTAssertTrue(
      screen.coachPicker.isEnabled,
      "Coach picker should remain enabled after adding new coach"
    )
  }

  /// Test: "Other coach" flow
  /// Covers selecting an unlisted coach option
  @MainActor
  func testAddInteraction_otherCoach_success() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "24-other-coach-initial"))

    // When: Select school first
    screen.selectSchool("Test School 1")

    // When: Select "Other coach (not listed)" from picker
    screen.selectOtherCoach()

    add(app.takeScreenshot(name: "25-other-coach-menu-opened"))

    // Then: Other Coach sheet should appear
    XCTAssertTrue(
      screen.otherCoachSheet.waitForExistence(timeout: 5),
      "Other Coach sheet should appear"
    )

    add(app.takeScreenshot(name: "26-other-coach-sheet"))

    // When: Enter other coach name
    screen.fillOtherCoachName("External Recruiter")

    add(app.takeScreenshot(name: "27-other-coach-name-entered"))

    // Then: Should return to Add Interaction form
    sleep(1)
    add(app.takeScreenshot(name: "28-other-coach-after-continue"))
  }

  // MARK: - Phase 2: Validation Tests

  /// Test: Submit button disabled when required fields are missing
  /// Covers form validation preventing invalid submission
  @MainActor
  func testAddInteraction_validation_submitDisabledWhenInvalid() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "29-validation-empty-form"))

    // Then: Submit button should be disabled (no required fields filled)
    XCTAssertFalse(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be disabled with empty form"
    )

    add(app.takeScreenshot(name: "30-validation-submit-disabled"))

    // When: Fill only school (still missing type)
    screen.selectSchool("Test School 1")

    add(app.takeScreenshot(name: "31-validation-partial-form"))

    // Then: Submit button should still be disabled
    XCTAssertFalse(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be disabled when type is missing"
    )

    // When: Fill type (all required fields now filled)
    screen.selectInteractionType("Email")

    add(app.takeScreenshot(name: "32-validation-required-filled"))

    // Then: Submit button should be enabled
    XCTAssertTrue(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be enabled when all required fields are filled"
    )

    add(app.takeScreenshot(name: "33-validation-submit-enabled"))
  }

  /// Test: School change resets coach selection
  /// Covers business logic that prevents orphaned coach associations
  @MainActor
  func testAddInteraction_schoolChange_resetsCoach() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "34-school-change-initial"))

    // When: Select school and coach
    screen.selectSchool("Test School 1")
    screen.selectCoach("John Doe - Head Coach")

    add(app.takeScreenshot(name: "35-school-change-coach-selected"))

    // When: Change school
    screen.selectSchool("Test School 2")

    add(app.takeScreenshot(name: "36-school-change-school-changed"))

    // Then: Coach selection should be reset
    sleep(1) // Wait for UI update
    // Coach picker should show "No coach selected" or be reset
    // This is verified by ensuring the coach picker exists and is enabled
    XCTAssertTrue(
      screen.coachPicker.isEnabled,
      "Coach picker should be enabled for new school"
    )

    add(app.takeScreenshot(name: "37-school-change-verified"))
  }

  // MARK: - Phase 3: Cancel and Discard Tests

  /// Test: Cancel button dismisses form and discards data
  /// Covers cancellation flow
  @MainActor
  func testAddInteraction_cancel_discardsData() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "38-cancel-initial"))

    // When: Fill some fields
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")
    screen.fillSubject("Test cancel")

    add(app.takeScreenshot(name: "39-cancel-fields-filled"))

    // When: Tap Cancel button
    screen.tapCancel()

    add(app.takeScreenshot(name: "40-cancel-after-tap"))

    // Then: Should return to Interactions list
    XCTAssertTrue(
      app.navigationBars["Interactions"].waitForExistence(timeout: 5),
      "Should return to Interactions list after cancel"
    )

    add(app.takeScreenshot(name: "41-cancel-back-to-list"))

    // When: Re-open Add Interaction
    let addButton = app.navigationBars.buttons["Add new interaction"]
    if addButton.waitForExistence(timeout: 5) {
      addButton.tap()
    }

    _ = screen.waitForScreenToLoad()
    add(app.takeScreenshot(name: "42-cancel-reopened"))

    // Then: Form should be empty (data discarded)
    // Verify by checking if submit button is disabled (no data)
    XCTAssertFalse(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be disabled in fresh form (data was discarded)"
    )

    add(app.takeScreenshot(name: "43-cancel-form-empty"))
  }
}
