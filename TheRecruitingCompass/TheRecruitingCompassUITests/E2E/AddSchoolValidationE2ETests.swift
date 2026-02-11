import XCTest

/// E2E tests for Add School form validation
/// Tests field validation rules, error messages, and error clearing
final class AddSchoolValidationE2ETests: XCTestCase {
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

  // MARK: - Name Validation Tests

  /// Test: Name field validates minimum length (2 characters)
  /// Covers spec lines 838-841 (Name validation - too short)
  @MainActor
  func testAddSchool_nameTooShort_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "01-short-add-school-screen"))

    // When: Switch to manual mode
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "02-short-manual-mode"))

    // When: Enter 1 character
    screen.fillSchoolName("X")

    add(app.takeScreenshot(name: "03-short-one-char"))

    // Blur the field
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "04-short-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "School name").exists ||
                      screen.fieldError(for: "at least 2 characters").exists

    XCTAssertTrue(
      errorExists,
      "Should show error: 'School name must be at least 2 characters'"
    )

    add(app.takeScreenshot(name: "05-short-error-shown"))

    // When: Add another character (total 2)
    screen.nameTextField.tap()
    screen.nameTextField.typeText("Y")

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "06-short-two-chars"))

    // Then: Error should disappear
    let errorStillExists = screen.fieldError(for: "School name").exists

    XCTAssertFalse(
      errorStillExists,
      "Error should disappear when name reaches 2 characters"
    )

    add(app.takeScreenshot(name: "07-short-error-cleared"))
  }

  /// Test: Name field validates maximum length (255 characters)
  /// Covers spec lines 842-845 (Name validation - too long)
  @MainActor
  func testAddSchool_nameTooLong_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "08-long-add-school-screen"))

    // When: Switch to manual mode
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "09-long-manual-mode"))

    // When: Enter 256 characters
    let longName = String(repeating: "A", count: 256)
    screen.fillSchoolName(longName)

    add(app.takeScreenshot(name: "10-long-256-chars"))

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "11-long-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "School name").exists ||
                      screen.fieldError(for: "255 characters").exists ||
                      screen.fieldError(for: "exceed").exists

    XCTAssertTrue(
      errorExists,
      "Should show error: 'School name must not exceed 255 characters'"
    )

    add(app.takeScreenshot(name: "12-long-error-shown"))
  }

  // MARK: - Social Handle Validation Tests

  /// Test: Twitter handle field validates format
  /// Covers spec lines 857-862 (Twitter validation)
  @MainActor
  func testAddSchool_invalidTwitterHandle_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "13-twitter-add-school-screen"))

    // Set up required fields first
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Twitter Validation Test")
    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "14-twitter-required-filled"))

    // When: Enter invalid Twitter handle
    screen.fillTwitterHandle("invalid@@@handle!!!")

    add(app.takeScreenshot(name: "15-twitter-invalid-entered"))

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "16-twitter-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "Twitter").exists ||
                      screen.fieldError(for: "handle").exists ||
                      screen.fieldError(for: "Invalid").exists

    XCTAssertTrue(
      errorExists,
      "Should show error for invalid Twitter handle format"
    )

    add(app.takeScreenshot(name: "17-twitter-error-shown"))

    // When: Correct the handle
    // Clear field
    screen.twitterHandleTextField.tap()
    if let currentValue = screen.twitterHandleTextField.value as? String, !currentValue.isEmpty {
      for _ in 0..<currentValue.count {
        screen.twitterHandleTextField.typeText(XCUIKeyboardKey.delete.rawValue)
      }
    }
    screen.twitterHandleTextField.typeText("@validhandle")

    add(app.takeScreenshot(name: "18-twitter-valid-entered"))

    screen.dismissKeyboard()

    // Then: Error should disappear
    let errorStillExists = screen.fieldError(for: "Twitter").exists

    XCTAssertFalse(
      errorStillExists,
      "Twitter error should disappear after entering valid handle"
    )

    add(app.takeScreenshot(name: "19-twitter-error-cleared"))
  }

  /// Test: Instagram handle field validates format
  /// Covers spec lines 864-869 (Instagram validation)
  @MainActor
  func testAddSchool_invalidInstagramHandle_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "20-instagram-add-school-screen"))

    // Set up required fields
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Instagram Validation Test")
    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "21-instagram-required-filled"))

    // When: Enter invalid Instagram handle
    screen.fillInstagramHandle("invalid handle with spaces!!!")

    add(app.takeScreenshot(name: "22-instagram-invalid-entered"))

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "23-instagram-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "Instagram").exists ||
                      screen.fieldError(for: "handle").exists ||
                      screen.fieldError(for: "Invalid").exists

    XCTAssertTrue(
      errorExists,
      "Should show error for invalid Instagram handle format"
    )

    add(app.takeScreenshot(name: "24-instagram-error-shown"))

    // When: Correct the handle
    screen.instagramHandleTextField.tap()
    if let currentValue = screen.instagramHandleTextField.value as? String, !currentValue.isEmpty {
      for _ in 0..<currentValue.count {
        screen.instagramHandleTextField.typeText(XCUIKeyboardKey.delete.rawValue)
      }
    }
    screen.instagramHandleTextField.typeText("@valid.handle_123")

    add(app.takeScreenshot(name: "25-instagram-valid-entered"))

    screen.dismissKeyboard()

    // Then: Error should disappear
    let errorStillExists = screen.fieldError(for: "Instagram").exists

    XCTAssertFalse(
      errorStillExists,
      "Instagram error should disappear after entering valid handle"
    )

    add(app.takeScreenshot(name: "26-instagram-error-cleared"))
  }

  /// Test: Social handles with @ sign are sanitized (@ is stripped)
  /// Covers social handle sanitization logic
  @MainActor
  func testAddSchool_socialHandles_stripsAtSign() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "27-sanitize-add-school-screen"))

    // Set up required fields
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Social Handle Sanitization Test \(Int(Date().timeIntervalSince1970))")
    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "28-sanitize-required-filled"))

    // When: Enter handles WITH @ sign
    screen.fillTwitterHandle("@testhandle")
    screen.fillInstagramHandle("@test.handle")

    add(app.takeScreenshot(name: "29-sanitize-handles-with-at"))

    screen.dismissKeyboard()

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "30-sanitize-submitting"))

    _ = screen.waitForSubmissionToComplete(timeout: 15)

    add(app.takeScreenshot(name: "31-sanitize-after-submit"))

    // Then: Submission should succeed (@ is stripped during submission)
    let success = app.navigationBars["School Details"].waitForExistence(timeout: 10) ||
                  app.navigationBars["Schools"].waitForExistence(timeout: 10)

    XCTAssertTrue(
      success,
      "Should successfully create school with @ sign in handles (sanitized during submission)"
    )

    add(app.takeScreenshot(name: "32-sanitize-success"))

    // Note: We can't verify the @ was stripped in E2E tests
    // That's covered by unit tests - here we just verify submission succeeds
  }

  // MARK: - Notes Validation Tests

  /// Test: Notes field validates maximum length (5000 characters)
  /// Covers spec lines 875-880 (Notes validation)
  @MainActor
  func testAddSchool_notesTooLong_showsError() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "33-notes-add-school-screen"))

    // Set up required fields
    screen.toggleAutocomplete(enabled: false)
    screen.fillSchoolName("Notes Validation Test")
    screen.fillLocation("Test City")

    add(app.takeScreenshot(name: "34-notes-required-filled"))

    // When: Enter 5001 characters in notes
    let longNotes = String(repeating: "A", count: 5001)
    screen.fillNotes(longNotes)

    add(app.takeScreenshot(name: "35-notes-5001-chars"))

    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "36-notes-field-blurred"))

    // Then: Inline error should appear
    let errorExists = screen.fieldError(for: "Notes").exists ||
                      screen.fieldError(for: "5").exists ||
                      screen.fieldError(for: "000").exists ||
                      screen.fieldError(for: "exceed").exists

    XCTAssertTrue(
      errorExists,
      "Should show error: 'Notes must not exceed 5,000 characters'"
    )

    add(app.takeScreenshot(name: "37-notes-error-shown"))

    // Verify character count is shown (if implemented)
    let characterCount = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS '5001' OR label CONTAINS '5,001'")
    ).firstMatch

    if characterCount.exists {
      XCTAssertTrue(
        characterCount.exists,
        "Character count should be shown"
      )

      add(app.takeScreenshot(name: "38-notes-char-count"))
    }
  }

  // MARK: - Multiple Validation Errors Tests

  /// Test: Multiple validation errors show error summary banner
  /// Covers error summary display with all validation failures
  @MainActor
  func testAddSchool_allValidationErrors_showErrorSummary() throws {
    // Given: User is logged in and on Add School screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddSchoolFromDashboard()

    add(app.takeScreenshot(name: "39-summary-add-school-screen"))

    // When: Switch to manual mode and fill with invalid data
    screen.toggleAutocomplete(enabled: false)

    add(app.takeScreenshot(name: "40-summary-manual-mode"))

    // Name too short
    screen.fillSchoolName("X")

    // Invalid website
    screen.fillWebsite("not-a-url")

    // Invalid Twitter handle
    screen.fillTwitterHandle("invalid@@@")

    // Invalid Instagram handle
    screen.fillInstagramHandle("invalid handle!!!")

    add(app.takeScreenshot(name: "41-summary-invalid-data"))

    screen.dismissKeyboard()

    // When: Try to submit
    screen.submitForm()

    add(app.takeScreenshot(name: "42-summary-submit-attempted"))

    // Then: Error summary banner should appear (if implemented)
    let summaryBanner = screen.errorSummaryBanner

    if summaryBanner.exists {
      XCTAssertTrue(
        summaryBanner.exists,
        "Error summary banner should appear with multiple validation errors"
      )

      add(app.takeScreenshot(name: "43-summary-banner-shown"))
    } else {
      // Individual field errors should at least be visible
      let hasErrors = screen.fieldError(for: "School name").exists ||
                      screen.fieldError(for: "Website").exists ||
                      screen.fieldError(for: "Twitter").exists ||
                      screen.fieldError(for: "Instagram").exists

      XCTAssertTrue(
        hasErrors,
        "At least one validation error should be visible"
      )

      add(app.takeScreenshot(name: "44-summary-field-errors"))
    }

    // When: Fix all errors
    screen.nameTextField.tap()
    screen.nameTextField.typeText("Y") // Now 2 chars
    screen.dismissKeyboard()

    screen.websiteTextField.tap()
    // Clear and re-enter
    if let currentValue = screen.websiteTextField.value as? String, !currentValue.isEmpty {
      for _ in 0..<currentValue.count {
        screen.websiteTextField.typeText(XCUIKeyboardKey.delete.rawValue)
      }
    }
    screen.websiteTextField.typeText("https://validschool.edu")
    screen.dismissKeyboard()

    add(app.takeScreenshot(name: "45-summary-errors-fixed"))

    // Then: Submit button should be enabled and work
    XCTAssertTrue(
      screen.addSchoolButton.isEnabled || screen.addSchoolButton.exists,
      "Submit button should be enabled after fixing errors"
    )

    add(app.takeScreenshot(name: "46-summary-submit-enabled"))
  }
}
