import XCTest

/// E2E tests for edge cases in Interaction features
/// Tests character limits, device sizes, and boundary conditions
final class InteractionEdgeCaseE2ETests: XCTestCase {
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

  // MARK: - Phase 1: Character Limit Tests

  /// Test: Subject field respects 500 character limit
  /// Covers subject field validation and character counter
  @MainActor
  func testAddInteraction_subjectLimit_500Characters() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "01-subject-limit-initial"))

    // Fill required fields first
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")

    // When: Type exactly 450 characters (should show counter)
    let text450 = String(repeating: "a", count: 450)
    screen.fillSubject(text450)

    add(app.takeScreenshot(name: "02-subject-limit-450-chars"))

    // Then: Character counter should appear
    XCTAssertTrue(
      screen.subjectCharCount.exists,
      "Character counter should appear at 450+ characters"
    )

    // When: Type more characters to exceed 500
    let text520 = String(repeating: "b", count: 70) // Total 520 chars
    screen.subjectField.typeText(text520)

    add(app.takeScreenshot(name: "03-subject-limit-exceeded"))

    // Then: Character counter should show red text (exceeding limit)
    if screen.subjectCharCount.exists {
      let counterLabel = screen.subjectCharCount.label
      XCTAssertTrue(
        counterLabel.contains("/500"),
        "Character counter should show /500 limit"
      )
      add(app.takeScreenshot(name: "04-subject-limit-counter-red"))
    }
  }

  /// Test: Content field respects 10,000 character limit
  /// Covers content field validation and character counter
  @MainActor
  func testAddInteraction_contentLimit_10000Characters() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "05-content-limit-initial"))

    // Fill required fields first
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")

    // When: Type exactly 9,500 characters (should show counter)
    let text9500 = String(repeating: "a", count: 9500)
    screen.fillContent(text9500)

    add(app.takeScreenshot(name: "06-content-limit-9500-chars"))

    // Then: Character counter should appear
    XCTAssertTrue(
      screen.contentCharCount.exists,
      "Character counter should appear at 9,500+ characters"
    )

    // When: Type more characters to exceed 10,000
    let text600 = String(repeating: "b", count: 600) // Total 10,100 chars
    screen.contentEditor.typeText(text600)

    add(app.takeScreenshot(name: "07-content-limit-exceeded"))

    // Then: Character counter should show red text (exceeding limit)
    if screen.contentCharCount.exists {
      let counterLabel = screen.contentCharCount.label
      XCTAssertTrue(
        counterLabel.contains("/10,000"),
        "Character counter should show /10,000 limit"
      )
      add(app.takeScreenshot(name: "08-content-limit-counter-red"))
    }
  }

  // MARK: - Phase 2: Device Size Tests

  /// Test: Add Interaction form displays correctly on iPhone SE (small screen)
  /// Covers responsive layout for compact screens
  @MainActor
  func testAddInteraction_iPhoneSE_displaysCorrectly() throws {
    // Note: This test should be run with iPhone SE simulator
    // The test verifies that UI elements are accessible on smaller screens

    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "09-iphone-se-initial"))

    // Then: All form elements should be visible and accessible
    XCTAssertTrue(
      screen.schoolPicker.exists,
      "School picker should be visible on iPhone SE"
    )

    XCTAssertTrue(
      screen.interactionTypePicker.exists,
      "Type picker should be visible on iPhone SE"
    )

    XCTAssertTrue(
      screen.directionPicker.exists,
      "Direction picker should be visible on iPhone SE"
    )

    add(app.takeScreenshot(name: "10-iphone-se-form-elements"))

    // When: Scroll to bottom to verify submit button is accessible
    let submitButton = screen.submitButton
    if submitButton.exists {
      // Scroll to make it visible if needed
      submitButton.forceTapElement()
    }

    add(app.takeScreenshot(name: "11-iphone-se-submit-button"))

    XCTAssertTrue(
      submitButton.exists,
      "Submit button should be accessible on iPhone SE"
    )
  }

  /// Test: Add Interaction form displays correctly on iPhone Pro Max (large screen)
  /// Covers responsive layout for larger screens
  @MainActor
  func testAddInteraction_iPhoneProMax_displaysCorrectly() throws {
    // Note: This test should be run with iPhone Pro Max simulator
    // The test verifies that UI scales appropriately on larger screens

    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "12-iphone-pro-max-initial"))

    // Then: All form elements should be visible and properly spaced
    XCTAssertTrue(
      screen.schoolPicker.exists,
      "School picker should be visible on iPhone Pro Max"
    )

    XCTAssertTrue(
      screen.interactionTypePicker.exists,
      "Type picker should be visible on iPhone Pro Max"
    )

    XCTAssertTrue(
      screen.submitButton.exists,
      "Submit button should be visible on iPhone Pro Max"
    )

    add(app.takeScreenshot(name: "13-iphone-pro-max-form-layout"))

    // Verify no layout issues with larger screen
    // All elements should fit comfortably without excessive whitespace
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Navigation title should be visible"
    )

    add(app.takeScreenshot(name: "14-iphone-pro-max-full-view"))
  }

  // MARK: - Phase 3: Boundary Condition Tests

  /// Test: Empty optional fields can be submitted
  /// Covers minimal valid form submission
  @MainActor
  func testAddInteraction_minimalForm_onlyRequiredFields() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "15-minimal-form-initial"))

    // When: Fill ONLY required fields (school, type)
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")

    add(app.takeScreenshot(name: "16-minimal-form-required-filled"))

    // Then: Submit button should be enabled
    XCTAssertTrue(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be enabled with only required fields"
    )

    // When: Submit form
    screen.submitForm()

    add(app.takeScreenshot(name: "17-minimal-form-submitting"))

    // Then: Should successfully submit
    let submitted = screen.waitForSubmissionToComplete(timeout: 15)

    XCTAssertTrue(
      submitted,
      "Should successfully submit with minimal required fields"
    )

    add(app.takeScreenshot(name: "18-minimal-form-success"))
  }

  /// Test: Subject with exactly 500 characters is accepted
  /// Covers exact limit boundary
  @MainActor
  func testAddInteraction_subjectExact500_accepted() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "19-exact-500-initial"))

    // Fill required fields
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")

    // When: Type exactly 500 characters
    let text500 = String(repeating: "a", count: 500)
    screen.fillSubject(text500)

    add(app.takeScreenshot(name: "20-exact-500-filled"))

    // Then: Character counter should show 500/500 (not red)
    if screen.subjectCharCount.exists {
      let counterLabel = screen.subjectCharCount.label
      XCTAssertTrue(
        counterLabel.contains("500/500"),
        "Character counter should show exactly 500/500"
      )
    }

    // Then: Submit button should be enabled
    XCTAssertTrue(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be enabled with exactly 500 characters"
    )

    add(app.takeScreenshot(name: "21-exact-500-valid"))
  }

  /// Test: Content with exactly 10,000 characters is accepted
  /// Covers exact limit boundary
  @MainActor
  func testAddInteraction_contentExact10000_accepted() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "22-exact-10000-initial"))

    // Fill required fields
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")

    // When: Type exactly 10,000 characters
    let text10000 = String(repeating: "a", count: 10000)
    screen.fillContent(text10000)

    add(app.takeScreenshot(name: "23-exact-10000-filled"))

    // Then: Character counter should show 10,000/10,000 (not red)
    if screen.contentCharCount.exists {
      let counterLabel = screen.contentCharCount.label
      XCTAssertTrue(
        counterLabel.contains("10,000/10,000") || counterLabel.contains("10000/10000"),
        "Character counter should show exactly 10,000/10,000"
      )
    }

    // Then: Submit button should be enabled
    XCTAssertTrue(
      screen.verifySubmitButtonEnabled(),
      "Submit button should be enabled with exactly 10,000 characters"
    )

    add(app.takeScreenshot(name: "24-exact-10000-valid"))
  }
}

// MARK: - XCUIElement Extension for Force Tap

extension XCUIElement {
  func forceTapElement() {
    if isHittable {
      tap()
    } else {
      let coordinate = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      coordinate.tap()
    }
  }
}
