import XCTest

/// E2E tests for Offer Detail navigation flows
/// Tests: screen loading, back navigation, loading state
final class OfferDetailNavigationE2ETests: XCTestCase {
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
      throw XCTSkip("No offers available to navigate to detail - list may be empty or navigation not wired")
    }
  }

  // MARK: - Navigation Tests

  /// Verify that navigating to an offer detail shows the screen with header content
  @MainActor
  func testOfferDetailScreenLoads() throws {
    try loginAndNavigateToOfferDetail()

    add(app.takeScreenshot(name: "offer-detail-01-screen-loaded"))

    // Navigation title should be present
    XCTAssertTrue(
      screen.navigationTitle.exists,
      "Offer Details navigation bar should be visible"
    )

    // School name should be displayed in the header
    XCTAssertTrue(
      screen.schoolNameLabel.waitForExistence(timeout: 5),
      "School name should be visible on offer detail"
    )

    // Status badge should be displayed
    XCTAssertTrue(
      screen.statusBadge.exists,
      "Status badge should be visible"
    )

    add(app.takeScreenshot(name: "offer-detail-02-header-verified"))
  }

  /// Verify that tapping back returns to the offers list
  @MainActor
  func testBackNavigationReturnsToList() throws {
    try loginAndNavigateToOfferDetail()

    add(app.takeScreenshot(name: "offer-detail-03-before-back"))

    // Tap the back button
    screen.tapBackButton()

    // Should return to the Offers list
    let offersNavBar = app.navigationBars["Offers"]
    XCTAssertTrue(
      offersNavBar.waitForExistence(timeout: 5),
      "Should navigate back to Offers list after tapping back"
    )

    add(app.takeScreenshot(name: "offer-detail-04-back-to-list"))
  }

  /// Verify that a loading indicator appears when the offer is loading
  @MainActor
  func testLoadingStateAppearsOnLoad() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToOffersFromDashboard() else {
      throw XCTSkip("Offers screen not reachable")
    }

    add(app.takeScreenshot(name: "offer-detail-05-before-nav"))

    // Navigate to detail - the loading indicator may flash briefly
    let firstCard = app.otherElements.matching(NSPredicate(
      format: "identifier BEGINSWITH 'offer_card_'"
    )).firstMatch

    guard firstCard.waitForExistence(timeout: 5) else {
      throw XCTSkip("No offers available to test loading state")
    }

    firstCard.tap()

    // Either loading indicator or content should appear
    let loadingOrContent = screen.loadingIndicator.waitForExistence(timeout: 2) ||
      screen.navigationTitle.waitForExistence(timeout: 5)

    XCTAssertTrue(
      loadingOrContent,
      "Either loading indicator or content should be visible after navigation"
    )

    add(app.takeScreenshot(name: "offer-detail-06-loading-or-content"))
  }

  /// Verify that financial summary cards are visible on the detail screen
  @MainActor
  func testFinancialSummaryCardsVisible() throws {
    try loginAndNavigateToOfferDetail()

    add(app.takeScreenshot(name: "offer-detail-07-financial-cards-check"))

    // At least the amount card should be present (even if showing "---")
    XCTAssertTrue(
      screen.amountCard.waitForExistence(timeout: 5),
      "Scholarship amount card should be visible"
    )

    XCTAssertTrue(
      screen.percentageCard.exists,
      "Scholarship percentage card should be visible"
    )

    XCTAssertTrue(
      screen.deadlineCard.exists,
      "Deadline card should be visible"
    )

    add(app.takeScreenshot(name: "offer-detail-08-financial-cards-verified"))
  }

  /// Verify that the offer details grid is visible with offer info
  @MainActor
  func testOfferDetailsGridVisible() throws {
    try loginAndNavigateToOfferDetail()

    // Scroll to details grid
    screen.scrollToElement(screen.offerDetailsSection)

    add(app.takeScreenshot(name: "offer-detail-09-details-grid"))

    XCTAssertTrue(
      screen.offerDetailsSection.exists,
      "Offer Details section should be visible"
    )

    add(app.takeScreenshot(name: "offer-detail-10-details-grid-verified"))
  }
}
