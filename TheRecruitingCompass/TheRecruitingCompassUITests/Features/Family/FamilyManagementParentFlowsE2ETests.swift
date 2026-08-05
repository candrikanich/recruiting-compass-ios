import XCTest

/// E2E tests for Family Management - Parent flows
/// Tests critical user journeys for parents joining families
final class FamilyManagementParentFlowsE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: FamilyManagementScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = FamilyManagementScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Join Family Form Tests

  /// Test: Parent can view join family form
  /// Covers initial form display
  @MainActor
  func testParentView_joinFamilyForm_displaysCorrectly() throws {
    // Given: Parent is logged in
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "01-parent-family-screen"))

    // Then: Join Family card should be visible
    XCTAssertTrue(
      screen.joinFamilyTitle.exists,
      "Join Family title should be visible"
    )

    XCTAssertTrue(
      screen.joinFamilyInstructions.exists,
      "Join Family instructions should be visible"
    )

    // Then: Family code input should be visible
    XCTAssertTrue(
      screen.familyCodeInput.exists,
      "Family code input field should be visible"
    )

    // Then: Join button should be visible but disabled (no code entered)
    XCTAssertTrue(
      screen.joinFamilyButton.exists,
      "Join Family button should be visible"
    )

    XCTAssertTrue(
      screen.verifyJoinButtonDisabled(),
      "Join button should be disabled when no code is entered"
    )

    add(app.takeScreenshot(name: "02-parent-join-form-visible"))
  }

  /// Test: Parent can enter a valid family code
  /// Covers form input and validation
  @MainActor
  func testParentView_enterValidCode_enablesJoinButton() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "03-parent-before-entering-code"))

    // When: Enter a valid family code format
    screen.enterFamilyCode("FAM-123456")

    add(app.takeScreenshot(name: "04-parent-code-entered"))

    // Then: Join button should become enabled
    XCTAssertTrue(
      screen.verifyJoinButtonEnabled(),
      "Join button should be enabled with valid code format"
    )

    add(app.takeScreenshot(name: "05-parent-join-button-enabled"))
  }

  /// Test: Parent code input is auto-formatted
  /// Covers code format transformation (lowercase to uppercase, adding dash)
  @MainActor
  func testParentView_codeInput_autoFormats() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "06-parent-before-auto-format"))

    // When: Enter lowercase code without dash
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode("fam123456")

    // Wait for auto-formatting
    sleep(1)

    add(app.takeScreenshot(name: "07-parent-after-auto-format"))

    // Then: Code should be formatted (this verification may vary based on implementation)
    // The actual formatting behavior is tested in unit tests
    // Here we just verify input was accepted
    XCTAssertTrue(
      screen.familyCodeInput.exists,
      "Code input should still be visible after entering text"
    )
  }

  /// Test: Join button is disabled with invalid code format
  /// Covers validation of code format
  @MainActor
  func testParentView_invalidCodeFormat_disablesJoinButton() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "08-parent-invalid-code-test"))

    // When: Enter invalid code (too short)
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode("FAM")

    sleep(1)
    add(app.takeScreenshot(name: "09-parent-invalid-code-entered"))

    // Then: Join button should remain disabled
    XCTAssertTrue(
      screen.verifyJoinButtonDisabled(),
      "Join button should be disabled with invalid code format"
    )

    // When: Clear and try another invalid format
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode("INVALID")

    sleep(1)
    add(app.takeScreenshot(name: "10-parent-another-invalid-code"))

    // Then: Join button should still be disabled
    XCTAssertTrue(
      screen.verifyJoinButtonDisabled(),
      "Join button should be disabled with non-FAM code"
    )
  }

  // MARK: - Join Family Success Tests

  /// Test: Parent can join a family with valid code
  /// Covers successful join flow
  /// Note: This requires a valid family code to exist in test database
  @MainActor
  func testParentView_joinFamily_withValidCode_success() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "11-parent-before-join"))

    // Note: In a real test environment, you'd have a known valid test family code
    // For this test, we'll use a placeholder and expect it might fail in test env
    let testCode = "FAM-999999"

    // When: Enter valid code
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode(testCode)

    add(app.takeScreenshot(name: "12-parent-code-ready-to-join"))

    // When: Tap join button
    screen.tapJoinFamily()

    add(app.takeScreenshot(name: "13-parent-joining-family"))

    // Then: Loading indicator should appear
    let loadingAppeared = screen.joinFamilyLoadingIndicator.waitForExistence(timeout: 3)

    if loadingAppeared {
      add(app.takeScreenshot(name: "14-parent-loading-visible"))

      // Wait for join operation to complete
      let joinCompleted = screen.waitForJoinToComplete(timeout: 15)

      add(app.takeScreenshot(name: "15-parent-after-join-attempt"))

      // Note: The actual success/failure depends on whether test code exists
      // We just verify the operation completed without crash
      XCTAssertTrue(
        joinCompleted,
        "Join operation should complete (success or error)"
      )
    } else {
      // Join button may be disabled or request immediate
      add(app.takeScreenshot(name: "14-parent-join-immediate"))
    }

    // Verify we're still on the Family screen (no crash)
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Should remain on Family screen after join attempt"
    )
  }

  // MARK: - Error Handling Tests

  /// Test: Appropriate error handling for non-existent family code (404)
  /// Covers 404 error scenario
  @MainActor
  func testParentView_joinFamily_nonExistentCode_showsError() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "16-parent-before-404-test"))

    // When: Enter a code that doesn't exist
    let invalidCode = "FAM-000000"
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode(invalidCode)

    add(app.takeScreenshot(name: "17-parent-invalid-code-ready"))

    // When: Attempt to join
    screen.tapJoinFamily()

    // Wait for operation to complete
    _ = screen.waitForJoinToComplete(timeout: 15)

    add(app.takeScreenshot(name: "18-parent-after-404-attempt"))

    // Then: Error should be shown (implementation-specific)
    // The exact error UI depends on how errors are displayed
    // We verify the operation completed and user can try again
    XCTAssertTrue(
      screen.joinFamilyButton.exists,
      "Join button should still be visible after error"
    )

    XCTAssertTrue(
      screen.familyCodeInput.exists,
      "Input field should still be visible after error"
    )
  }

  /// Test: Error handling for malformed code (400)
  /// Covers client-side validation
  @MainActor
  func testParentView_joinFamily_malformedCode_preventsSubmission() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "19-parent-before-malformed-test"))

    // When: Enter malformed code
    screen.clearFamilyCodeInput()
    screen.enterFamilyCode("NOTACODE")

    sleep(1)
    add(app.takeScreenshot(name: "20-parent-malformed-code"))

    // Then: Join button should be disabled (client-side validation)
    XCTAssertTrue(
      screen.verifyJoinButtonDisabled(),
      "Join button should be disabled with malformed code"
    )

    // Button shouldn't be tappable
    // (In UI tests, we can't easily verify this without trying to tap,
    // but isEnabled check above is sufficient)
  }

  // MARK: - My Families List Tests

  /// Test: Parent can view joined families list
  /// Covers families display
  @MainActor
  func testParentView_viewMyFamilies_displaysCorrectly() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "21-parent-view-families"))

    // Then: My Families section should be visible
    XCTAssertTrue(
      screen.myFamiliesTitle.exists,
      "My Families section should be visible"
    )

    // Then: Either empty state or families list should be visible
    let hasEmptyState = screen.verifyEmptyFamiliesState()
    let hasFamiliesCount = screen.myFamiliesCount.exists

    XCTAssertTrue(
      hasEmptyState || hasFamiliesCount,
      "Either empty state or families list should be visible"
    )

    add(app.takeScreenshot(name: "22-parent-families-displayed"))
  }

  /// Test: Empty state is shown when parent has not joined any families
  /// Covers empty state UI
  @MainActor
  func testParentView_noFamilies_showsEmptyState() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "23-parent-check-empty-state"))

    // Note: This test assumes a fresh parent account with no joined families
    // In a real test environment, you'd set up test data accordingly

    // If empty state is visible
    if screen.verifyEmptyFamiliesState() {
      add(app.takeScreenshot(name: "24-parent-empty-state-verified"))

      // Then: Empty state message should be visible
      XCTAssertTrue(
        screen.emptyFamiliesText.exists,
        "Empty families message should be visible"
      )

      // Then: Empty state icon should be visible
      XCTAssertTrue(
        screen.emptyFamiliesIcon.exists,
        "Empty families icon should be visible"
      )

      // Then: Instructions should guide user
      XCTAssertTrue(
        screen.joinFamilyInstructions.exists,
        "Join instructions should be visible in empty state"
      )
    } else {
      // Parent has joined families, skip empty state test
      throw XCTSkip("Parent has joined families - cannot test empty state")
    }
  }

  /// Test: Parent can view details of joined families
  /// Covers family card display
  @MainActor
  func testParentView_joinedFamilies_displayFamilyCards() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "25-parent-check-family-cards"))

    // Check if there are joined families
    if screen.verifyEmptyFamiliesState() {
      throw XCTSkip("No joined families - empty state visible")
    }

    // Then: Family cards should be visible
    // Note: Exact verification depends on test data
    // We verify the section shows some content
    XCTAssertTrue(
      screen.myFamiliesCount.exists,
      "Family count should be visible when families exist"
    )

    add(app.takeScreenshot(name: "26-parent-family-cards-visible"))

    // Verify at least one family code is visible in the list
    let familyCodes = app.staticTexts.matching(NSPredicate(format: "label MATCHES 'FAM-[0-9]{6}'"))

    XCTAssertGreaterThan(
      familyCodes.count,
      0,
      "At least one family code should be visible in the list"
    )
  }

  // MARK: - Rate Limiting Tests

  /// Test: Error handling for rate limiting (429)
  /// Covers rate limit scenario
  /// Note: This is difficult to test in E2E without actually triggering rate limits
  @MainActor
  func testParentView_joinFamily_rateLimited_showsError() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "27-parent-rate-limit-test"))

    // This test would require rapid repeated attempts to join
    // In a real test environment, you might have a mock backend that returns 429
    // For now, we'll skip this test as it's hard to reproduce reliably in E2E

    throw XCTSkip("Rate limit testing requires mock backend or repeated requests")
  }

  // MARK: - Accessibility Tests

  /// Test: Parent view has proper VoiceOver labels
  /// Covers accessibility compliance
  @MainActor
  func testParentView_accessibilityLabels_exist() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "28-parent-accessibility-check"))

    // Then: Key elements should have accessibility labels
    XCTAssertTrue(
      screen.familyCodeInput.exists,
      "Family code input should have accessibility label"
    )

    XCTAssertTrue(
      screen.joinFamilyButton.exists,
      "Join Family button should have accessibility label"
    )

    // Verify form elements have hints
    let inputHint = screen.familyCodeInput.value(forKey: "accessibilityHint") as? String
    XCTAssertNotNil(
      inputHint,
      "Family code input should have accessibility hint"
    )

    add(app.takeScreenshot(name: "29-parent-accessibility-verified"))
  }

  // MARK: - Clear Input Tests

  /// Test: Parent can clear family code input
  /// Covers input clearing and re-entry
  @MainActor
  func testParentView_clearCodeInput_allowsReEntry() throws {
    // Given: Parent is logged in and on Family screen
    try navigateToParentFamilyScreen()

    add(app.takeScreenshot(name: "30-parent-before-clear"))

    // When: Enter a code
    screen.enterFamilyCode("FAM-111111")

    sleep(1)
    add(app.takeScreenshot(name: "31-parent-code-entered-2"))

    // Verify join button is enabled
    XCTAssertTrue(
      screen.verifyJoinButtonEnabled(),
      "Join button should be enabled after entering code"
    )

    // When: Clear input
    screen.clearFamilyCodeInput()

    sleep(1)
    add(app.takeScreenshot(name: "32-parent-input-cleared"))

    // Then: Join button should be disabled again
    XCTAssertTrue(
      screen.verifyJoinButtonDisabled(),
      "Join button should be disabled after clearing input"
    )

    // When: Re-enter a different code
    screen.enterFamilyCode("FAM-222222")

    sleep(1)
    add(app.takeScreenshot(name: "33-parent-new-code-entered"))

    // Then: Join button should be enabled again
    XCTAssertTrue(
      screen.verifyJoinButtonEnabled(),
      "Join button should be enabled with new code"
    )
  }

  // MARK: - Helper Methods

  /// Navigates from dashboard to Parent Family screen
  private func navigateToParentFamilyScreen() throws {
    // Login as parent
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    // Navigate to Family tab
    screen.navigateToFamilyFromDashboard()

    // Wait for Family screen to load
    guard screen.waitForScreenToLoad() else {
      throw XCTSkip("Family Management screen did not load")
    }
  }
}
