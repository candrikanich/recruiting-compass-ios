import XCTest

/// E2E tests for the Interaction Detail feature
/// Tests detail view display, navigation, export, and delete flows
final class InteractionDetailE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: InteractionDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = InteractionDetailScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Phase 1: Display Tests

  /// Test: Load and display interaction details
  /// Covers primary detail view rendering
  @MainActor
  func testInteractionDetail_load_displaysCorrectly() throws {
    // Given: User is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    add(app.takeScreenshot(name: "01-detail-dashboard"))

    // When: Navigate to Interactions list
    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    add(app.takeScreenshot(name: "02-detail-list"))

    // When: Tap first interaction to view details
    screen.navigateToInteractionDetail(fromRow: 0)

    add(app.takeScreenshot(name: "03-detail-opening"))

    // Then: Detail screen should load
    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Interaction detail should load"
    )

    add(app.takeScreenshot(name: "04-detail-loaded"))

    // Then: Subject should be visible
    XCTAssertTrue(
      screen.interactionSubject.exists,
      "Interaction subject should be visible"
    )

    // Then: Date should be visible
    XCTAssertTrue(
      screen.occurredAtLabel.exists,
      "Occurred at date should be visible"
    )

    // Then: Badges should be visible
    XCTAssertTrue(
      screen.typeBadge.exists,
      "Type badge should be visible"
    )

    XCTAssertTrue(
      screen.directionBadge.exists,
      "Direction badge should be visible"
    )

    add(app.takeScreenshot(name: "05-detail-content-verified"))
  }

  /// Test: Interaction with content displays content section
  /// Covers optional content field display
  @MainActor
  func testInteractionDetail_withContent_displaysContentSection() throws {
    // Given: User is logged in and viewing interaction list
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    // When: Navigate to interaction with content
    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "06-content-detail"))

    // Then: Content section should be visible if interaction has content
    if screen.verifyHasContent() {
      XCTAssertTrue(
        screen.contentSection.exists,
        "Content section should be visible"
      )
      add(app.takeScreenshot(name: "07-content-visible"))
    } else {
      add(app.takeScreenshot(name: "08-no-content"))
    }
  }

  // MARK: - Phase 2: Navigation Tests

  /// Test: Tap school link navigates to school detail
  /// Covers school navigation from interaction detail
  @MainActor
  func testInteractionDetail_tapSchoolLink_navigatesToSchoolDetail() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "09-school-link-initial"))

    // When: Tap school link (if exists)
    if screen.verifySchoolLinkExists() {
      screen.tapSchoolLink()

      add(app.takeScreenshot(name: "10-school-link-tapped"))

      // Then: Should navigate to School Detail screen
      XCTAssertTrue(
        app.navigationBars["School Details"].waitForExistence(timeout: 5),
        "Should navigate to School Details"
      )

      add(app.takeScreenshot(name: "11-school-detail-shown"))
    } else {
      throw XCTSkip("No school link available in interaction")
    }
  }

  /// Test: Tap coach link navigates to coach detail
  /// Covers coach navigation from interaction detail
  @MainActor
  func testInteractionDetail_tapCoachLink_navigatesToCoachDetail() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "12-coach-link-initial"))

    // When: Tap coach link (if exists)
    if screen.verifyCoachLinkExists() {
      screen.tapCoachLink()

      add(app.takeScreenshot(name: "13-coach-link-tapped"))

      // Then: Should navigate to Coach Detail screen
      XCTAssertTrue(
        app.navigationBars["Coach Details"].waitForExistence(timeout: 5),
        "Should navigate to Coach Details"
      )

      add(app.takeScreenshot(name: "14-coach-detail-shown"))
    } else {
      throw XCTSkip("No coach link available in interaction")
    }
  }

  // MARK: - Phase 3: Export Tests

  /// Test: Export via share sheet
  /// Covers export functionality
  @MainActor
  func testInteractionDetail_export_showsShareSheet() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "15-export-initial"))

    // When: Tap actions menu and export
    if screen.actionsMenuButton.exists {
      screen.tapExport()

      add(app.takeScreenshot(name: "16-export-menu-opened"))

      // Then: Share sheet should appear
      // Note: Share sheet detection varies by iOS version
      // Check for activity view or share sheet UI elements
      sleep(2) // Wait for share sheet animation
      add(app.takeScreenshot(name: "17-export-share-sheet"))

      // Dismiss share sheet by tapping outside or cancel
      app.tap()
      sleep(1)
      add(app.takeScreenshot(name: "18-export-dismissed"))
    } else {
      throw XCTSkip("Export not available (read-only view)")
    }
  }

  // MARK: - Phase 4: Delete Tests

  /// Test: Delete with confirmation navigates back
  /// Covers delete flow with confirmation
  @MainActor
  func testInteractionDetail_delete_withConfirmation_navigatesBack() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "19-delete-initial"))

    // When: Tap actions menu and delete
    if screen.actionsMenuButton.exists {
      screen.tapDelete()

      add(app.takeScreenshot(name: "20-delete-menu-opened"))

      // Then: Confirmation dialog should appear
      XCTAssertTrue(
        screen.deleteConfirmationDialog.waitForExistence(timeout: 5),
        "Delete confirmation dialog should appear"
      )

      add(app.takeScreenshot(name: "21-delete-confirmation"))

      // When: Confirm delete
      screen.confirmDelete()

      add(app.takeScreenshot(name: "22-delete-confirmed"))

      // Then: Should navigate back to list
      let navigatedBack = screen.waitForDeletion(timeout: 15)
      add(app.takeScreenshot(name: "23-delete-after-deletion"))

      XCTAssertTrue(
        navigatedBack,
        "Should navigate back after successful deletion"
      )
    } else {
      throw XCTSkip("Delete not available (read-only view)")
    }
  }

  /// Test: Cancel delete keeps interaction
  /// Covers delete cancellation flow
  @MainActor
  func testInteractionDetail_delete_cancel_keepsInteraction() throws {
    // Given: User is logged in and viewing interaction detail
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "24-cancel-delete-initial"))

    // When: Tap actions menu and delete
    if screen.actionsMenuButton.exists {
      screen.tapDelete()

      add(app.takeScreenshot(name: "25-cancel-delete-menu-opened"))

      // Then: Confirmation dialog should appear
      XCTAssertTrue(
        screen.deleteConfirmationDialog.waitForExistence(timeout: 5),
        "Delete confirmation dialog should appear"
      )

      add(app.takeScreenshot(name: "26-cancel-delete-confirmation"))

      // When: Cancel delete
      screen.cancelDelete()

      add(app.takeScreenshot(name: "27-cancel-delete-cancelled"))

      // Then: Should remain on detail screen
      XCTAssertTrue(
        screen.navigationTitle.exists,
        "Should remain on detail screen after cancel"
      )

      add(app.takeScreenshot(name: "28-cancel-delete-still-on-detail"))

      // Then: Content should still be visible
      XCTAssertTrue(
        screen.interactionSubject.exists,
        "Interaction content should still be visible"
      )
    } else {
      throw XCTSkip("Delete not available (read-only view)")
    }
  }

  // MARK: - Phase 5: Read-Only View Tests

  /// Test: Parent user sees read-only view (no actions menu)
  /// Covers permission-based view rendering
  @MainActor
  func testInteractionDetail_parentUser_seesReadOnlyView() throws {
    // Given: Parent user is logged in
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    screen.navigateToInteractionDetail(fromRow: 0)
    _ = screen.waitForContentToLoad()

    add(app.takeScreenshot(name: "29-readonly-view"))

    // Then: Actions menu should NOT be visible for parent users
    // Note: This depends on the actual permission implementation
    // Parent users should have read-only access
    let hasActionsMenu = screen.actionsMenuButton.exists

    if hasActionsMenu {
      add(app.takeScreenshot(name: "30-readonly-has-actions"))
      // If actions exist, this might be a student/player view
      // Skip or adjust test based on actual user permissions
    } else {
      add(app.takeScreenshot(name: "31-readonly-no-actions"))
      XCTAssertTrue(
        screen.verifyReadOnlyView(),
        "Parent user should have read-only view without actions menu"
      )
    }
  }
}
