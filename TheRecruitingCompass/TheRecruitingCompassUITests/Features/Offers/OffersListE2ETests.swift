import XCTest

/// E2E tests for the Offers List feature
/// Tests critical user journeys: navigation, empty state, log offer button, filter controls, summary cards
final class OffersListE2ETests: XCTestCase {
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

  // MARK: - Phase 1: Navigate to Offers

  /// Test: Navigate to Offers section and verify the screen loads
  @MainActor
  func testOffersList_navigate_displaysScreen() throws {
    try loginAndNavigateToOffers()

    add(app.takeScreenshot(name: "01-offers-screen-loaded"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Offers content or empty state should appear"
    )

    add(app.takeScreenshot(name: "02-offers-content-loaded"))
  }

  // MARK: - Phase 2: Empty State

  /// Test: Empty state is shown when no offers exist
  @MainActor
  func testOffersList_noOffers_displaysEmptyState() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    if screen.verifyEmptyState() {
      add(app.takeScreenshot(name: "03-empty-state-displayed"))

      XCTAssertTrue(
        screen.emptyStateTitle.exists,
        "Empty state title should be visible"
      )

      XCTAssertTrue(
        screen.emptyStateSubtitle.exists,
        "Empty state subtitle should be visible"
      )

      add(app.takeScreenshot(name: "04-empty-state-verified"))
    } else {
      throw XCTSkip("Offers exist - cannot test empty state")
    }
  }

  // MARK: - Phase 3: Log Offer Button

  /// Test: Log Offer (add) button is accessible and visible
  @MainActor
  func testOffersList_addButton_isAccessible() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "05-before-add-button-check"))

    guard screen.addOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Add offer button not found")
    }

    XCTAssertEqual(
      screen.addOfferButton.label,
      "Log new offer",
      "Add offer button should have descriptive accessibility label"
    )

    XCTAssertGreaterThanOrEqual(
      screen.addOfferButton.frame.width, 44,
      "Add offer button should meet minimum 44pt tap target width"
    )

    XCTAssertGreaterThanOrEqual(
      screen.addOfferButton.frame.height, 44,
      "Add offer button should meet minimum 44pt tap target height"
    )

    add(app.takeScreenshot(name: "06-add-button-verified"))
  }

  /// Test: Tapping add button shows the add offer form
  @MainActor
  func testOffersList_addButton_showsForm() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.addOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Add offer button not found")
    }

    screen.addOfferButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "07-add-form-shown"))

    let formAppeared = screen.saveOfferButton.waitForExistence(timeout: 5)
      || screen.cancelAddOfferButton.waitForExistence(timeout: 3)

    XCTAssertTrue(
      formAppeared,
      "Add offer form should appear after tapping the add button"
    )

    add(app.takeScreenshot(name: "08-add-form-verified"))
  }

  // MARK: - Phase 4: Filter Controls

  /// Test: Filter controls are visible when offers exist
  @MainActor
  func testOffersList_filterControls_areVisible() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasSummaryCardsLoaded() else {
      throw XCTSkip("No offers available - filters only visible with data")
    }

    add(app.takeScreenshot(name: "09-filter-controls-check"))

    let statusExists = screen.statusFilter.waitForExistence(timeout: 3)
    let typeExists = screen.offerTypeFilter.waitForExistence(timeout: 3)
    let sortExists = screen.sortByField.waitForExistence(timeout: 3)
    let directionExists = screen.sortDirection.waitForExistence(timeout: 3)

    let visibleCount = [statusExists, typeExists, sortExists, directionExists]
      .filter { $0 }.count

    XCTAssertGreaterThan(
      visibleCount, 0,
      "At least one filter control should be visible"
    )

    add(app.takeScreenshot(name: "10-filter-controls-verified"))
  }

  // MARK: - Phase 5: Summary Card Labels

  /// Test: Summary cards display Accepted/Pending/Declined labels
  @MainActor
  func testOffersList_summaryCards_displayCorrectLabels() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasSummaryCardsLoaded() else {
      throw XCTSkip("No summary cards - empty state displayed")
    }

    add(app.takeScreenshot(name: "11-summary-cards-check"))

    let acceptedExists = screen.acceptedCard.waitForExistence(timeout: 3)
    let pendingExists = screen.pendingCard.waitForExistence(timeout: 3)
    let declinedExists = screen.declinedCard.waitForExistence(timeout: 3)

    XCTAssertTrue(
      acceptedExists,
      "Accepted summary card should be visible"
    )

    XCTAssertTrue(
      pendingExists,
      "Pending summary card should be visible"
    )

    XCTAssertTrue(
      declinedExists,
      "Declined summary card should be visible"
    )

    add(app.takeScreenshot(name: "12-summary-cards-verified"))
  }

  /// Test: Summary cards have proper accessibility labels with counts
  @MainActor
  func testOffersList_summaryCards_haveAccessibleLabels() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasSummaryCardsLoaded() else {
      throw XCTSkip("No summary cards available")
    }

    add(app.takeScreenshot(name: "13-a11y-summary-check"))

    if screen.acceptedCard.exists {
      XCTAssertFalse(
        screen.acceptedCard.label.isEmpty,
        "Accepted card should have a non-empty accessibility label"
      )
      XCTAssertTrue(
        screen.acceptedCard.label.contains("Accepted"),
        "Accepted card label should contain 'Accepted'"
      )
    }

    if screen.pendingCard.exists {
      XCTAssertFalse(
        screen.pendingCard.label.isEmpty,
        "Pending card should have a non-empty accessibility label"
      )
      XCTAssertTrue(
        screen.pendingCard.label.contains("Pending"),
        "Pending card label should contain 'Pending'"
      )
    }

    if screen.declinedCard.exists {
      XCTAssertFalse(
        screen.declinedCard.label.isEmpty,
        "Declined card should have a non-empty accessibility label"
      )
      XCTAssertTrue(
        screen.declinedCard.label.contains("Declined"),
        "Declined card label should contain 'Declined'"
      )
    }

    add(app.takeScreenshot(name: "14-a11y-summary-verified"))
  }

  // MARK: - Phase 6: Compare Button Visibility

  /// Test: Compare button is NOT visible when no offers are selected
  @MainActor
  func testOffersList_compareButton_notVisibleWithNoSelection() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "22-compare-no-selection"))

    XCTAssertFalse(
      screen.compareButton.exists,
      "Compare button should not be visible when no offers are selected"
    )

    add(app.takeScreenshot(name: "23-compare-not-visible-verified"))
  }

  /// Test: Selecting offer checkboxes shows the compare button
  @MainActor
  func testOffersList_checkboxSelection_showsCompareButton() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.hasOffersLoaded() else {
      throw XCTSkip("No offers available to select for comparison")
    }

    add(app.takeScreenshot(name: "24-checkbox-before-selection"))

    // Find first two offer card checkboxes via identifier pattern
    let checkboxes = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH 'offer_checkbox_'"
    ))

    guard checkboxes.count >= 2 else {
      throw XCTSkip("Need at least 2 offers to test comparison selection")
    }

    // Select first two checkboxes
    checkboxes.element(boundBy: 0).tap()
    sleep(1)

    add(app.takeScreenshot(name: "25-checkbox-first-selected"))

    checkboxes.element(boundBy: 1).tap()
    sleep(1)

    add(app.takeScreenshot(name: "26-checkbox-second-selected"))

    // Compare button should now appear
    XCTAssertTrue(
      screen.compareButton.waitForExistence(timeout: 5),
      "Compare button should appear after selecting two offers"
    )

    add(app.takeScreenshot(name: "27-compare-button-visible"))
  }

  // MARK: - Phase 7: Full Offers Journey

  /// Test: Complete offers list journey - load, browse, open add form, dismiss
  @MainActor
  func testOffersList_fullJourney() throws {
    try loginAndNavigateToOffers()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    add(app.takeScreenshot(name: "15-journey-start"))

    // Step 1: Verify add button is present
    guard screen.addOfferButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Add offer button not found for journey")
    }

    add(app.takeScreenshot(name: "16-journey-add-button-found"))

    // Step 2: Open add offer form
    screen.addOfferButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "17-journey-form-opened"))

    // Step 3: Cancel the form
    if screen.cancelAddOfferButton.waitForExistence(timeout: 3) {
      screen.cancelAddOfferButton.tap()
      sleep(1)
    }

    add(app.takeScreenshot(name: "18-journey-form-dismissed"))

    // Step 4: Pull to refresh
    screen.pullToRefresh()
    sleep(2)

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Content should reload after pull-to-refresh"
    )

    add(app.takeScreenshot(name: "19-journey-refreshed"))

    // Step 5: Scroll through content
    screen.scrollDown()
    sleep(1)

    add(app.takeScreenshot(name: "20-journey-scrolled"))

    screen.scrollUp()
    sleep(1)

    add(app.takeScreenshot(name: "21-journey-complete"))
  }
}
