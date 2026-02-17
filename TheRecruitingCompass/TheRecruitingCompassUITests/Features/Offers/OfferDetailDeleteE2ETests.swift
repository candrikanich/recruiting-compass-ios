import XCTest

/// E2E tests for Offer Detail delete functionality
/// Tests: delete confirmation alert, cancel delete, confirm delete navigation
final class OfferDetailDeleteE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: OfferDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
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

  // MARK: - Delete Tests

  /// Tapping Delete should show a confirmation alert with "Delete Offer?" title
  @MainActor
  func testDeleteButtonShowsConfirmation() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.deleteButton)
    XCTAssertTrue(
      screen.deleteButton.waitForExistence(timeout: 5),
      "Delete button should be visible"
    )

    add(app.takeScreenshot(name: "offer-delete-01-before-tap"))

    // Tap the delete button
    screen.tapDelete()

    // Confirmation alert should appear
    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 3),
      "Delete confirmation alert should appear"
    )

    // Alert should have a Delete action button
    XCTAssertTrue(
      screen.alertDeleteButton.exists,
      "Alert should have a Delete button"
    )

    // Alert should have a Cancel action button
    XCTAssertTrue(
      screen.alertCancelButton.exists,
      "Alert should have a Cancel button"
    )

    // Alert message should warn about permanent deletion
    let alertMessage = app.alerts.staticTexts.matching(NSPredicate(
      format: "label CONTAINS 'cannot be undone'"
    )).firstMatch
    XCTAssertTrue(
      alertMessage.exists,
      "Alert should warn that the action cannot be undone"
    )

    add(app.takeScreenshot(name: "offer-delete-02-confirmation-shown"))
  }

  /// Tapping Cancel on the delete confirmation should dismiss the alert and stay on detail
  @MainActor
  func testCancelDeleteKeepsOffer() throws {
    try loginAndNavigateToOfferDetail()

    // Capture school name before attempting delete
    let schoolNameExists = screen.schoolNameLabel.waitForExistence(timeout: 5)
    XCTAssertTrue(schoolNameExists, "School name should be visible")

    screen.scrollToElement(screen.deleteButton)
    screen.tapDelete()

    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 3),
      "Delete alert should appear"
    )

    add(app.takeScreenshot(name: "offer-delete-03-before-cancel"))

    // Cancel the delete
    screen.cancelDelete()

    // Alert should dismiss
    app.waitForElementToDisappear(screen.deleteConfirmationAlert, timeout: 3)

    add(app.takeScreenshot(name: "offer-delete-04-after-cancel"))

    // Should still be on the Offer Detail screen
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Should still be on Offer Details screen after canceling delete"
    )

    // School name should still be visible
    XCTAssertTrue(
      screen.schoolNameLabel.exists,
      "School name should still be displayed after canceling delete"
    )

    // Edit and Delete buttons should still be available
    screen.scrollToElement(screen.editButton)
    XCTAssertTrue(
      screen.editButton.exists,
      "Edit button should still be available after canceling delete"
    )

    XCTAssertTrue(
      screen.deleteButton.exists,
      "Delete button should still be available after canceling delete"
    )

    add(app.takeScreenshot(name: "offer-delete-05-cancel-verified"))
  }

  /// Confirming delete should remove the offer and navigate back to the offers list
  @MainActor
  func testConfirmDeleteNavigatesBack() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.deleteButton)
    screen.tapDelete()

    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 3),
      "Delete alert should appear"
    )

    add(app.takeScreenshot(name: "offer-delete-06-before-confirm"))

    // Confirm the delete
    screen.confirmDelete()

    // Should navigate back to the Offers list
    let offersNavBar = app.navigationBars["Offers"]
    XCTAssertTrue(
      offersNavBar.waitForExistence(timeout: 10),
      "Should navigate back to Offers list after confirming delete"
    )

    add(app.takeScreenshot(name: "offer-delete-07-navigated-back"))
  }

  /// Verify the delete button is accessible with proper hit target
  @MainActor
  func testDeleteButtonAccessibility() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.deleteButton)

    XCTAssertTrue(
      screen.deleteButton.waitForExistence(timeout: 5),
      "Delete button should exist"
    )

    add(app.takeScreenshot(name: "offer-delete-08-a11y-check"))

    // Delete button should have reasonable tap target
    XCTAssertGreaterThanOrEqual(
      screen.deleteButton.frame.height, 40,
      "Delete button should have adequate tap target height"
    )

    add(app.takeScreenshot(name: "offer-delete-09-a11y-verified"))
  }
}
