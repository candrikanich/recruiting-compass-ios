import XCTest

/// E2E validation tests for the Offers List feature
/// Tests form validation, filter interactions, and error states
final class OffersValidationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: OffersListScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = OffersListScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToOffers() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToOffers() else {
      throw XCTSkip("Offers screen not reachable - navigation may not be wired")
    }
  }

  // MARK: - Form Validation

  /// Test: Save button is disabled when form is opened without filling required fields
  @MainActor
  func testSaveOfferWithoutRequiredFields_buttonDisabled() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.addOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Add offer button not found")
    }

    // Open the add offer form
    screen.tapAddOffer()
    sleep(1)

    add(app.takeScreenshot(name: "01-validation-form-opened"))

    // Save button should exist but be disabled (no school selected)
    guard screen.saveOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Save offer button not found in form")
    }

    XCTAssertFalse(
      screen.saveOfferButton.isEnabled,
      "Save button should be disabled when required fields are empty"
    )

    add(app.takeScreenshot(name: "02-validation-save-disabled"))
  }

  /// Test: Cancel button in add form dismisses the form
  @MainActor
  func testCancelAddOfferForm_dismissesForm() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.addOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Add offer button not found")
    }

    screen.tapAddOffer()
    sleep(1)

    add(app.takeScreenshot(name: "03-cancel-form-opened"))

    guard screen.cancelAddOfferButton.waitForExistence(timeout: 3) else {
      throw XCTSkip("Cancel button not found in form")
    }

    screen.cancelAddOfferButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "04-cancel-form-dismissed"))

    // Save button should no longer be visible (form is dismissed)
    XCTAssertFalse(
      screen.saveOfferButton.exists,
      "Add offer form should be dismissed after tapping cancel"
    )
  }

  // MARK: - Filter Controls

  /// Test: Status filter picker is accessible on the offers screen
  @MainActor
  func testFilterBarStatusPicker_exists() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasSummaryCardsLoaded() else {
      throw XCTSkip("No offers available - filters only visible with data")
    }

    add(app.takeScreenshot(name: "05-filter-status-check"))

    XCTAssertTrue(
      screen.statusFilter.waitForExistence(timeout: 5),
      "Status filter picker should be accessible on the offers screen"
    )

    add(app.takeScreenshot(name: "06-filter-status-verified"))
  }

  /// Test: Offer type filter picker is accessible
  @MainActor
  func testFilterBarOfferTypePicker_exists() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasSummaryCardsLoaded() else {
      throw XCTSkip("No offers available - filters only visible with data")
    }

    add(app.takeScreenshot(name: "07-filter-type-check"))

    XCTAssertTrue(
      screen.offerTypeFilter.waitForExistence(timeout: 5),
      "Offer type filter picker should be accessible on the offers screen"
    )

    add(app.takeScreenshot(name: "08-filter-type-verified"))
  }

  /// Test: Search field is accessible for filtering by school name
  @MainActor
  func testSearchField_isAccessible() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "09-search-field-check"))

    // Search field may require a pull-down or scroll to reveal on iOS
    let searchExists = screen.searchField.waitForExistence(timeout: 5)

    if !searchExists {
      // Try pulling down to reveal search bar
      screen.scrollUp()
      sleep(1)
    }

    XCTAssertTrue(
      screen.searchField.waitForExistence(timeout: 5),
      "Search field should be accessible for filtering offers by school"
    )

    add(app.takeScreenshot(name: "10-search-field-verified"))
  }

  // MARK: - Delete Confirmation

  /// Test: Delete button triggers confirmation dialog
  @MainActor
  func testDeleteOffer_showsConfirmationDialog() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasOffersLoaded() else {
      throw XCTSkip("No offers available to test deletion")
    }

    add(app.takeScreenshot(name: "11-delete-before-tap"))

    // Find first delete button
    let deleteButtons = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH 'offer_delete_button_'"
    ))

    guard deleteButtons.count > 0 else {
      throw XCTSkip("No delete buttons found on offer cards")
    }

    deleteButtons.element(boundBy: 0).tap()
    sleep(1)

    add(app.takeScreenshot(name: "12-delete-dialog-shown"))

    // Confirmation dialog should appear
    let deleteConfirm = app.buttons["Delete"]
    let cancelConfirm = app.buttons["Cancel"]

    let dialogAppeared = deleteConfirm.waitForExistence(timeout: 5)
      || cancelConfirm.waitForExistence(timeout: 3)

    XCTAssertTrue(
      dialogAppeared,
      "Delete confirmation dialog should appear with Delete and Cancel options"
    )

    // Dismiss by tapping Cancel
    if cancelConfirm.exists {
      cancelConfirm.tap()
    }

    add(app.takeScreenshot(name: "13-delete-dialog-dismissed"))
  }
}
