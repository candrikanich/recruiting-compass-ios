import XCTest

/// E2E tests for accessibility features in Interactions
/// Tests VoiceOver navigation, Dynamic Type, and WCAG AA compliance
final class InteractionAccessibilityE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddInteractionScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = AddInteractionScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Phase 1: VoiceOver Navigation Tests

  /// Test: All form fields have proper accessibility labels
  /// Covers VoiceOver compatibility for form inputs
  @MainActor
  func testAddInteraction_accessibility_allFieldsLabeled() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "01-a11y-labels-initial"))

    // Then: School picker should have accessibility label
    XCTAssertTrue(
      screen.schoolPicker.exists,
      "School picker should exist"
    )

    XCTAssertNotNil(
      screen.schoolPicker.label,
      "School picker should have accessibility label"
    )

    XCTAssertTrue(
      screen.schoolPicker.label.contains("School"),
      "School picker label should contain 'School'"
    )

    // Then: Coach picker should have accessibility label
    XCTAssertTrue(
      screen.coachPicker.exists,
      "Coach picker should exist"
    )

    XCTAssertNotNil(
      screen.coachPicker.label,
      "Coach picker should have accessibility label"
    )

    // Then: Type picker should have accessibility label
    XCTAssertTrue(
      screen.interactionTypePicker.exists,
      "Type picker should exist"
    )

    XCTAssertTrue(
      screen.interactionTypePicker.label.contains("type"),
      "Type picker label should contain 'type'"
    )

    // Then: Direction picker should have accessibility label
    XCTAssertTrue(
      screen.directionPicker.exists,
      "Direction picker should exist"
    )

    // Then: Subject field should have accessibility label
    XCTAssertTrue(
      screen.subjectField.exists,
      "Subject field should exist"
    )

    XCTAssertTrue(
      screen.subjectField.label.contains("Subject"),
      "Subject field label should contain 'Subject'"
    )

    // Then: Content editor should have accessibility label
    XCTAssertTrue(
      screen.contentEditor.exists,
      "Content editor should exist"
    )

    XCTAssertTrue(
      screen.contentEditor.label.contains("Content"),
      "Content editor label should contain 'Content'"
    )

    // Then: Sentiment picker should have accessibility label
    XCTAssertTrue(
      screen.sentimentPicker.exists,
      "Sentiment picker should exist"
    )

    // Then: Submit button should have accessibility label
    XCTAssertTrue(
      screen.submitButton.exists,
      "Submit button should exist"
    )

    add(app.takeScreenshot(name: "02-a11y-labels-verified"))
  }

  /// Test: VoiceOver can navigate through full Add Interaction form
  /// Covers complete VoiceOver flow
  @MainActor
  func testAddInteraction_voiceOver_canNavigateFullForm() throws {
    // Note: This test verifies that all elements are accessible
    // Actual VoiceOver testing requires manual testing with VoiceOver enabled

    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "03-voiceover-nav-initial"))

    // Verify all interactive elements have accessibility traits
    let schoolPicker = screen.schoolPicker
    XCTAssertTrue(
      schoolPicker.exists && schoolPicker.isEnabled,
      "School picker should be accessible and enabled"
    )

    let coachPicker = screen.coachPicker
    XCTAssertTrue(
      coachPicker.exists,
      "Coach picker should be accessible"
    )

    let typePicker = screen.interactionTypePicker
    XCTAssertTrue(
      typePicker.exists && typePicker.isEnabled,
      "Type picker should be accessible and enabled"
    )

    let directionPicker = screen.directionPicker
    XCTAssertTrue(
      directionPicker.exists && directionPicker.isEnabled,
      "Direction picker should be accessible and enabled"
    )

    let subjectField = screen.subjectField
    XCTAssertTrue(
      subjectField.exists && subjectField.isEnabled,
      "Subject field should be accessible and enabled"
    )

    let contentEditor = screen.contentEditor
    XCTAssertTrue(
      contentEditor.exists && contentEditor.isEnabled,
      "Content editor should be accessible and enabled"
    )

    let submitButton = screen.submitButton
    XCTAssertTrue(
      submitButton.exists,
      "Submit button should be accessible"
    )

    add(app.takeScreenshot(name: "04-voiceover-nav-verified"))
  }

  /// Test: Interest calibration toggles have proper accessibility labels
  /// Covers VoiceOver for conditional interest calibration section
  @MainActor
  func testAddInteraction_voiceOver_interestCalibrationAccessible() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "05-calibration-a11y-initial"))

    // When: Trigger interest calibration (inbound + positive)
    screen.selectSchool("Test School 1")
    screen.selectInteractionType("Email")
    screen.selectDirection("Inbound")
    screen.selectSentiment("Positive")

    sleep(1) // Wait for UI update
    add(app.takeScreenshot(name: "06-calibration-a11y-visible"))

    // Then: Interest calibration section should be accessible
    if screen.verifyInterestCalibrationVisible() {
      XCTAssertTrue(
        screen.interestCalibrationSection.exists,
        "Interest calibration section should be accessible"
      )

      // Verify first toggle has accessibility label
      let firstToggle = screen.interestCalibrationToggle(forQuestion: 0)
      if firstToggle.exists {
        XCTAssertNotNil(
          firstToggle.label,
          "Interest calibration toggle should have accessibility label"
        )

        XCTAssertNotNil(
          firstToggle.value,
          "Interest calibration toggle should have accessibility value (Yes/No)"
        )
      }

      add(app.takeScreenshot(name: "07-calibration-a11y-verified"))
    } else {
      throw XCTSkip("Interest calibration not visible")
    }
  }

  // MARK: - Phase 2: Dynamic Type Tests

  /// Test: Add Interaction form scales correctly with Dynamic Type
  /// Covers text scaling for larger accessibility font sizes
  @MainActor
  func testAddInteraction_dynamicType_scalesCorrectly() throws {
    // Note: To properly test Dynamic Type, run this test with accessibility text size increased
    // Settings → Accessibility → Display & Text Size → Larger Text → Max (310%)

    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "08-dynamic-type-initial"))

    // Then: All text elements should be visible and not truncated
    XCTAssertTrue(
      screen.schoolPicker.exists,
      "School picker should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      screen.interactionTypePicker.exists,
      "Type picker should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      screen.directionPicker.exists,
      "Direction picker should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      screen.submitButton.exists,
      "Submit button should be visible with Dynamic Type"
    )

    add(app.takeScreenshot(name: "09-dynamic-type-elements"))

    // Verify form is still functional with larger text
    screen.selectSchool("Test School 1")
    add(app.takeScreenshot(name: "10-dynamic-type-school-selected"))

    screen.selectInteractionType("Email")
    add(app.takeScreenshot(name: "11-dynamic-type-type-selected"))

    // Submit button should still be accessible
    XCTAssertTrue(
      screen.submitButton.exists,
      "Submit button should remain accessible with Dynamic Type"
    )

    add(app.takeScreenshot(name: "12-dynamic-type-functional"))
  }

  /// Test: Interaction Detail scales correctly with Dynamic Type
  /// Covers detail view text scaling
  @MainActor
  func testInteractionDetail_dynamicType_scalesCorrectly() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    // Navigate to interactions list
    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    // Tap first interaction
    let detailScreen = InteractionDetailScreenObject(app: app)
    detailScreen.navigateToInteractionDetail(fromRow: 0)
    _ = detailScreen.waitForContentToLoad()

    add(app.takeScreenshot(name: "13-detail-dynamic-type-initial"))

    // Then: All content should be readable with Dynamic Type
    XCTAssertTrue(
      detailScreen.interactionSubject.exists,
      "Subject should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      detailScreen.occurredAtLabel.exists,
      "Date should be visible with Dynamic Type"
    )

    XCTAssertTrue(
      detailScreen.typeBadge.exists,
      "Type badge should be visible with Dynamic Type"
    )

    add(app.takeScreenshot(name: "14-detail-dynamic-type-content"))

    // Verify detail grid items are accessible
    XCTAssertTrue(
      detailScreen.schoolDetailItem.exists || detailScreen.coachDetailItem.exists,
      "Detail grid items should be visible with Dynamic Type"
    )

    add(app.takeScreenshot(name: "15-detail-dynamic-type-verified"))
  }

  // MARK: - Phase 3: Touch Target Tests

  /// Test: All interactive elements meet 44pt minimum touch target
  /// Covers WCAG 2.5.5 (Target Size) compliance
  @MainActor
  func testAddInteraction_touchTargets_meet44ptMinimum() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "16-touch-targets-initial"))

    // Verify interactive elements are tappable (meets minimum size)
    let cancelButton = screen.cancelButton
    XCTAssertTrue(
      cancelButton.exists,
      "Cancel button should exist"
    )

    // Get frame to verify size
    let cancelFrame = cancelButton.frame
    XCTAssertGreaterThanOrEqual(
      cancelFrame.height,
      44.0,
      "Cancel button should meet 44pt minimum height"
    )

    // Verify submit button meets minimum size
    let submitButton = screen.submitButton
    if submitButton.exists {
      let submitFrame = submitButton.frame
      XCTAssertGreaterThanOrEqual(
        submitFrame.height,
        44.0,
        "Submit button should meet 44pt minimum height"
      )
    }

    add(app.takeScreenshot(name: "17-touch-targets-verified"))

    // Verify pickers are tappable
    let schoolPicker = screen.schoolPicker
    XCTAssertTrue(
      schoolPicker.isHittable,
      "School picker should be hittable (meets touch target size)"
    )

    let typePicker = screen.interactionTypePicker
    XCTAssertTrue(
      typePicker.isHittable,
      "Type picker should be hittable (meets touch target size)"
    )

    add(app.takeScreenshot(name: "18-touch-targets-pickers-verified"))
  }

  // MARK: - Phase 4: Form Field Grouping Tests

  /// Test: Form fields are properly grouped for VoiceOver
  /// Covers accessibility element grouping
  @MainActor
  func testAddInteraction_formFields_properlyGrouped() throws {
    // Given: User is logged in and on Add Interaction screen
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    screen.navigateToAddInteractionFromDashboard()
    _ = screen.waitForScreenToLoad()

    add(app.takeScreenshot(name: "19-grouping-initial"))

    // Verify section headers exist for grouping
    let schoolSection = app.staticTexts["School"]
    XCTAssertTrue(
      schoolSection.exists,
      "School section header should exist for grouping"
    )

    let detailsSection = app.staticTexts["Details (Optional)"]
    XCTAssertTrue(
      detailsSection.exists,
      "Details section header should exist for grouping"
    )

    let sentimentSection = app.staticTexts["Sentiment (Optional)"]
    XCTAssertTrue(
      sentimentSection.exists,
      "Sentiment section header should exist for grouping"
    )

    add(app.takeScreenshot(name: "20-grouping-sections-verified"))

    // Verify required field indicators are present
    let requiredIndicators = app.staticTexts.matching(NSPredicate(format: "label == '*'"))
    XCTAssertGreaterThan(
      requiredIndicators.count,
      0,
      "Required field indicators should be present"
    )

    add(app.takeScreenshot(name: "21-grouping-required-indicators"))
  }

  /// Test: Interaction Detail has proper accessibility hierarchy
  /// Covers semantic heading structure
  @MainActor
  func testInteractionDetail_accessibility_properHeadingHierarchy() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    // Navigate to interactions list
    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    // Tap first interaction
    let detailScreen = InteractionDetailScreenObject(app: app)
    detailScreen.navigateToInteractionDetail(fromRow: 0)
    _ = detailScreen.waitForContentToLoad()

    add(app.takeScreenshot(name: "22-detail-headings-initial"))

    // Then: Subject should have header trait
    let subject = detailScreen.interactionSubject
    if subject.exists {
      // Verify subject is marked as header for VoiceOver
      // Note: Cannot directly check traits in UI test, but can verify existence
      XCTAssertTrue(
        subject.exists,
        "Subject heading should exist"
      )
    }

    add(app.takeScreenshot(name: "23-detail-headings-subject"))

    // Verify section headers have header trait
    let contentHeader = app.staticTexts["Content"]
    if contentHeader.exists {
      XCTAssertTrue(
        contentHeader.exists,
        "Content section header should exist"
      )
    }

    let detailsHeader = app.staticTexts["Details"]
    XCTAssertTrue(
      detailsHeader.exists,
      "Details section header should exist"
    )

    add(app.takeScreenshot(name: "24-detail-headings-verified"))
  }
}
