import XCTest

/// E2E tests for Offer Detail editing functionality
/// Tests: edit mode toggle, cancel editing, save changes, form field visibility
final class OfferDetailEditingE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: OfferDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = OfferDetailScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToOfferDetail() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToOffersFromDashboard() else {
      throw XCTSkip("Offers screen not reachable")
    }

    guard screen.navigateToOfferDetailFromList() else {
      throw XCTSkip("No offers available to navigate to detail")
    }
  }

  // MARK: - Edit Mode Tests

  /// Tapping the edit button should show the edit form with Save/Cancel buttons
  @MainActor
  func testEditButtonShowsEditForm() throws {
    try loginAndNavigateToOfferDetail()

    // Verify edit button exists before tapping
    screen.scrollToElement(screen.editButton)
    XCTAssertTrue(
      screen.editButton.waitForExistence(timeout: 5),
      "Edit button should be visible on offer detail"
    )

    add(app.takeScreenshot(name: "offer-edit-01-before-edit"))

    // Tap edit button
    screen.tapEdit()
    sleep(1)

    add(app.takeScreenshot(name: "offer-edit-02-edit-form-shown"))

    // Save and Cancel buttons should appear (inside OfferEditForm)
    XCTAssertTrue(
      screen.saveButton.waitForExistence(timeout: 5),
      "Save button should appear in edit mode"
    )

    XCTAssertTrue(
      screen.cancelButton.exists,
      "Cancel button should appear in edit mode"
    )

    // Edit form title should be visible
    XCTAssertTrue(
      screen.editFormTitle.exists,
      "Edit Offer title should be visible"
    )

    // Edit and Delete buttons should be hidden during editing
    XCTAssertFalse(
      screen.editButton.exists,
      "Edit button should be hidden during editing"
    )

    XCTAssertFalse(
      screen.deleteButton.exists,
      "Delete button should be hidden during editing"
    )

    add(app.takeScreenshot(name: "offer-edit-03-edit-form-verified"))
  }

  /// Tapping Cancel in edit mode should dismiss the form and restore view mode
  @MainActor
  func testCancelDismissesEditForm() throws {
    try loginAndNavigateToOfferDetail()

    // Enter edit mode
    screen.scrollToElement(screen.editButton)
    screen.tapEdit()

    XCTAssertTrue(
      screen.saveButton.waitForExistence(timeout: 5),
      "Should be in edit mode"
    )

    add(app.takeScreenshot(name: "offer-edit-04-before-cancel"))

    // Tap Cancel
    screen.tapCancel()
    sleep(1)

    add(app.takeScreenshot(name: "offer-edit-05-after-cancel"))

    // Save button should disappear
    XCTAssertFalse(
      screen.saveButton.exists,
      "Save button should be hidden after canceling edit"
    )

    // Cancel button should disappear
    XCTAssertFalse(
      screen.cancelButton.exists,
      "Cancel button should be hidden after canceling edit"
    )

    // Edit button should reappear
    screen.scrollToElement(screen.editButton)
    XCTAssertTrue(
      screen.editButton.waitForExistence(timeout: 3),
      "Edit button should reappear after canceling"
    )

    // Delete button should also reappear
    XCTAssertTrue(
      screen.deleteButton.exists,
      "Delete button should reappear after canceling"
    )

    add(app.takeScreenshot(name: "offer-edit-06-cancel-verified"))
  }

  /// Verify that the edit form shows the required pickers for offer type and status
  @MainActor
  func testEditFormHasRequiredFields() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.editButton)
    screen.tapEdit()

    XCTAssertTrue(
      screen.saveButton.waitForExistence(timeout: 5),
      "Should be in edit mode"
    )

    add(app.takeScreenshot(name: "offer-edit-07-form-fields-check"))

    // Offer Type picker should be accessible
    let offerTypeLabel = app.staticTexts["Offer Type"]
    screen.scrollToElement(offerTypeLabel)
    XCTAssertTrue(
      offerTypeLabel.exists,
      "Offer Type label should be visible in edit form"
    )

    // Status picker should be accessible
    let statusLabel = app.staticTexts["Status"]
    screen.scrollToElement(statusLabel)
    XCTAssertTrue(
      statusLabel.exists,
      "Status label should be visible in edit form"
    )

    // Amount field should be accessible
    let amountLabel = app.staticTexts["Scholarship Amount ($)"]
    screen.scrollToElement(amountLabel)
    XCTAssertTrue(
      amountLabel.exists,
      "Scholarship Amount label should be visible in edit form"
    )

    // Percentage field should be accessible
    let percentageLabel = app.staticTexts["Scholarship Percentage (%)"]
    screen.scrollToElement(percentageLabel)
    XCTAssertTrue(
      percentageLabel.exists,
      "Scholarship Percentage label should be visible in edit form"
    )

    add(app.takeScreenshot(name: "offer-edit-08-form-fields-verified"))
  }

  /// Verify that toggling edit mode on and off preserves original data
  @MainActor
  func testEditCancelPreservesOriginalData() throws {
    try loginAndNavigateToOfferDetail()

    // Capture the original status badge text
    let originalStatusText = screen.statusBadge.label

    // Enter edit mode
    screen.scrollToElement(screen.editButton)
    screen.tapEdit()

    XCTAssertTrue(
      screen.saveButton.waitForExistence(timeout: 5),
      "Should be in edit mode"
    )

    add(app.takeScreenshot(name: "offer-edit-09-before-cancel-preserve"))

    // Cancel without making changes
    screen.tapCancel()
    sleep(1)

    // Status badge should still show the same value
    XCTAssertTrue(
      screen.statusBadge.waitForExistence(timeout: 3),
      "Status badge should still be visible"
    )

    XCTAssertEqual(
      screen.statusBadge.label, originalStatusText,
      "Status should be unchanged after canceling edit"
    )

    add(app.takeScreenshot(name: "offer-edit-10-preserved-verified"))
  }
}
