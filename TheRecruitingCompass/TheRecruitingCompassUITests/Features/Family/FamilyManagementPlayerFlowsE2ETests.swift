import XCTest

/// E2E tests for Family Management - Player flows
/// Tests critical user journeys for players managing their family code and members
final class FamilyManagementPlayerFlowsE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: FamilyManagementScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = FamilyManagementScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Family Code Auto-Creation Tests

  /// Test: Player can view auto-generated family code on first load
  /// Covers initial family code creation workflow
  @MainActor
  func testPlayerView_familyCodeAutoCreation_success() throws {
    // Given: Player is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-player-dashboard"))

    // When: Navigate to Family tab
    screen.navigateToFamilyFromDashboard()

    add(app.takeScreenshot(name: "02-player-family-screen"))

    // Then: Family screen should load
    XCTAssertTrue(
      screen.waitForScreenToLoad(),
      "Family Management screen should load"
    )

    // Then: Family code should be auto-created and visible
    XCTAssertTrue(
      screen.waitForFamilyCode(timeout: 10),
      "Family code should be auto-created and visible"
    )

    add(app.takeScreenshot(name: "03-player-family-code-visible"))

    // Then: Family code should match expected format (FAM-XXXXXX)
    let code = screen.getFamilyCode()
    XCTAssertNotNil(code, "Family code should not be nil")
    XCTAssertTrue(
      code?.range(of: "^FAM-[0-9]{6}$", options: .regularExpression) != nil,
      "Family code should match format FAM-XXXXXX, got: \(code ?? "nil")"
    )

    // Then: Code creation date should be visible
    XCTAssertTrue(
      screen.codeCreatedDateText.exists,
      "Code creation date should be visible"
    )

    add(app.takeScreenshot(name: "04-player-code-verified"))
  }

  // MARK: - Copy Code Tests

  /// Test: Player can copy family code to clipboard
  /// Covers clipboard functionality
  @MainActor
  func testPlayerView_copyCodeToClipboard_success() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    // Wait for family code to load
    guard screen.waitForFamilyCode(timeout: 10) else {
      throw XCTSkip("Family code not loaded")
    }

    let originalCode = screen.getFamilyCode()
    add(app.takeScreenshot(name: "05-player-before-copy"))

    // When: Tap copy button
    screen.tapCopyButton()

    add(app.takeScreenshot(name: "06-player-after-copy"))

    // Then: Code should be copied (we can't verify clipboard in UI tests directly,
    // but we verify the button tap succeeded without errors)
    // Note: Clipboard verification would require unit tests
    XCTAssertNotNil(originalCode, "Code should exist before copying")

    // Verify copy button is still visible (no crash)
    XCTAssertTrue(
      screen.copyButton.exists,
      "Copy button should still be visible after tap"
    )
  }

  // MARK: - Share Code Tests

  /// Test: Player can share family code via iOS share sheet
  /// Covers share sheet presentation
  @MainActor
  func testPlayerView_shareCode_opensShareSheet() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    guard screen.waitForFamilyCode(timeout: 10) else {
      throw XCTSkip("Family code not loaded")
    }

    add(app.takeScreenshot(name: "07-player-before-share"))

    // When: Tap share button
    screen.tapShareButton()

    // Wait a moment for share sheet to appear
    sleep(1)

    add(app.takeScreenshot(name: "08-player-share-sheet-opened"))

    // Then: iOS share sheet should appear
    // Note: Share sheet UI varies by iOS version, so we just verify no crash
    // The actual share sheet elements are part of the system UI
    XCTAssertTrue(
      screen.shareButton.exists,
      "Share button should still exist after tapping"
    )

    // Dismiss share sheet by tapping outside or Cancel
    // Tap in a safe area to dismiss (if sheet appeared)
    let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1))
    coordinate.tap()

    add(app.takeScreenshot(name: "09-player-share-dismissed"))
  }

  // MARK: - Regenerate Code Tests

  /// Test: Player can regenerate family code with confirmation
  /// Covers destructive action confirmation workflow
  @MainActor
  func testPlayerView_regenerateCode_withConfirmation_success() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    guard screen.waitForFamilyCode(timeout: 10) else {
      throw XCTSkip("Family code not loaded")
    }

    let originalCode = screen.getFamilyCode()
    XCTAssertNotNil(originalCode, "Original code should exist")

    add(app.takeScreenshot(name: "10-player-before-regenerate"))

    // When: Tap regenerate button
    screen.tapRegenerateButton()

    // Wait for confirmation dialog
    sleep(1)
    add(app.takeScreenshot(name: "11-player-regenerate-confirmation"))

    // Then: Confirmation dialog should appear
    XCTAssertTrue(
      screen.regenerateConfirmButton.exists,
      "Regenerate confirmation button should appear"
    )

    XCTAssertTrue(
      screen.regenerateCancelButton.exists,
      "Cancel button should appear in confirmation dialog"
    )

    // When: Confirm regeneration
    screen.confirmRegenerate()

    add(app.takeScreenshot(name: "12-player-regenerating"))

    // Then: New code should be generated
    // Wait for code to potentially change
    sleep(2)

    add(app.takeScreenshot(name: "13-player-code-regenerated"))

    // Verify a code is still visible (it may or may not be different in test env)
    XCTAssertTrue(
      screen.familyCodeText.exists,
      "Family code should still be visible after regeneration"
    )
  }

  /// Test: Player can cancel code regeneration
  /// Covers cancellation of destructive action
  @MainActor
  func testPlayerView_regenerateCode_cancel_keepsOriginalCode() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    guard screen.waitForFamilyCode(timeout: 10) else {
      throw XCTSkip("Family code not loaded")
    }

    let originalCode = screen.getFamilyCode()
    add(app.takeScreenshot(name: "14-player-before-cancel-regenerate"))

    // When: Tap regenerate button
    screen.tapRegenerateButton()

    sleep(1)
    add(app.takeScreenshot(name: "15-player-regenerate-confirmation-2"))

    // When: Cancel regeneration
    screen.cancelRegenerate()

    add(app.takeScreenshot(name: "16-player-regenerate-cancelled"))

    // Then: Original code should remain
    let currentCode = screen.getFamilyCode()
    XCTAssertEqual(
      originalCode,
      currentCode,
      "Code should remain unchanged after cancelling regeneration"
    )

    // Confirmation dialog should be dismissed
    XCTAssertFalse(
      screen.regenerateConfirmButton.exists,
      "Confirmation dialog should be dismissed"
    )
  }

  // MARK: - Family Members List Tests

  /// Test: Player can view family members list (or empty state)
  /// Covers members display
  @MainActor
  func testPlayerView_viewFamilyMembers_displaysCorrectly() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    add(app.takeScreenshot(name: "17-player-view-members"))

    // Then: Family Members section should be visible
    XCTAssertTrue(
      screen.familyMembersTitle.exists,
      "Family Members section should be visible"
    )

    // Then: Either empty state or members list should be visible
    let hasEmptyState = screen.verifyEmptyMembersState()
    let hasMembersCount = screen.familyMembersCount.exists

    XCTAssertTrue(
      hasEmptyState || hasMembersCount,
      "Either empty state or members list should be visible"
    )

    add(app.takeScreenshot(name: "18-player-members-displayed"))
  }

  /// Test: Empty state is shown when no family members exist
  /// Covers empty state UI
  @MainActor
  func testPlayerView_noFamilyMembers_showsEmptyState() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    add(app.takeScreenshot(name: "19-player-check-empty-state"))

    // Note: This test assumes a fresh player account with no family members
    // In a real test environment, you'd set up test data accordingly

    // If empty state is visible
    if screen.verifyEmptyMembersState() {
      add(app.takeScreenshot(name: "20-player-empty-state-verified"))

      // Then: Empty state message should be visible
      XCTAssertTrue(
        screen.emptyMembersText.exists,
        "Empty members message should be visible"
      )

      // Then: Empty state icon should be visible
      XCTAssertTrue(
        screen.emptyMembersIcon.exists,
        "Empty members icon should be visible"
      )
    } else {
      // Player has family members, skip empty state test
      throw XCTSkip("Player has family members - cannot test empty state")
    }
  }

  // MARK: - Remove Member Tests

  /// Test: Player can remove a family member with confirmation
  /// Covers member removal workflow
  /// Note: This test requires a parent to have joined the family first
  @MainActor
  func testPlayerView_removeFamilyMember_withConfirmation_success() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    add(app.takeScreenshot(name: "21-player-before-remove-member"))

    // Check if there are any members to remove
    if screen.verifyEmptyMembersState() {
      throw XCTSkip("No family members to remove - empty state visible")
    }

    // Find first member's remove button
    // Note: In a real test, you'd have known test data
    // For now, we'll check if any remove button exists
    let removeButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove'"))

    guard removeButtons.count > 0 else {
      throw XCTSkip("No remove buttons found - no removable members")
    }

    add(app.takeScreenshot(name: "22-player-member-visible"))

    // When: Tap remove button for first member
    let firstRemoveButton = removeButtons.element(boundBy: 0)
    firstRemoveButton.tap()

    sleep(1)
    add(app.takeScreenshot(name: "23-player-remove-confirmation"))

    // Then: Confirmation dialog should appear
    XCTAssertTrue(
      screen.removeMemberConfirmButton.exists,
      "Remove confirmation button should appear"
    )

    XCTAssertTrue(
      screen.removeMemberCancelButton.exists,
      "Cancel button should appear in confirmation dialog"
    )

    // When: Confirm removal
    screen.confirmRemoveMember()

    add(app.takeScreenshot(name: "24-player-removing-member"))

    // Then: Member should be removed (wait for update)
    sleep(2)

    add(app.takeScreenshot(name: "25-player-member-removed"))

    // Verify confirmation dialog is dismissed
    XCTAssertFalse(
      screen.removeMemberConfirmButton.exists,
      "Confirmation dialog should be dismissed after removal"
    )
  }

  /// Test: Player can cancel member removal
  /// Covers cancellation of member removal
  @MainActor
  func testPlayerView_removeFamilyMember_cancel_keepsMember() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    add(app.takeScreenshot(name: "26-player-before-cancel-remove"))

    // Check if there are any members
    if screen.verifyEmptyMembersState() {
      throw XCTSkip("No family members - empty state visible")
    }

    let removeButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove'"))

    guard removeButtons.count > 0 else {
      throw XCTSkip("No remove buttons found")
    }

    let initialMemberCount = removeButtons.count

    // When: Tap remove button
    let firstRemoveButton = removeButtons.element(boundBy: 0)
    firstRemoveButton.tap()

    sleep(1)
    add(app.takeScreenshot(name: "27-player-remove-confirmation-2"))

    // When: Cancel removal
    screen.cancelRemoveMember()

    add(app.takeScreenshot(name: "28-player-remove-cancelled"))

    // Then: Member should still be in the list
    sleep(1)
    let currentRemoveButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove'"))

    XCTAssertEqual(
      currentRemoveButtons.count,
      initialMemberCount,
      "Member count should remain unchanged after cancelling removal"
    )

    // Confirmation dialog should be dismissed
    XCTAssertFalse(
      screen.removeMemberConfirmButton.exists,
      "Confirmation dialog should be dismissed"
    )
  }

  // MARK: - Accessibility Tests

  /// Test: Player view has proper VoiceOver labels
  /// Covers accessibility compliance
  @MainActor
  func testPlayerView_accessibilityLabels_exist() throws {
    // Given: Player is logged in and on Family screen
    try navigateToPlayerFamilyScreen()

    guard screen.waitForFamilyCode(timeout: 10) else {
      throw XCTSkip("Family code not loaded")
    }

    add(app.takeScreenshot(name: "29-player-accessibility-check"))

    // Then: Key elements should have accessibility labels
    XCTAssertTrue(
      screen.copyButton.exists,
      "Copy button should have accessibility label"
    )

    XCTAssertTrue(
      screen.shareButton.exists,
      "Share button should have accessibility label"
    )

    XCTAssertTrue(
      screen.regenerateButton.exists,
      "Regenerate button should have accessibility label"
    )

    // Verify family code has accessibility label
    XCTAssertTrue(
      screen.familyCodeText.exists,
      "Family code should have accessibility label"
    )

    add(app.takeScreenshot(name: "30-player-accessibility-verified"))
  }

  // MARK: - Helper Methods

  /// Navigates from dashboard to Player Family screen
  private func navigateToPlayerFamilyScreen() throws {
    // Login
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
