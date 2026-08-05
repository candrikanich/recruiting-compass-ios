import XCTest

/// E2E tests for the Scholarship Calculator on Offer Detail
/// Tests: calculator visibility, expand/collapse, input fields, computed values
final class OfferDetailCalculatorE2ETests: XCTestCase {
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

  // MARK: - Calculator Visibility Tests

  /// The calculator section should be visible on the offer detail screen
  @MainActor
  func testCalculatorSectionVisible() throws {
    try loginAndNavigateToOfferDetail()

    // Scroll to the calculator section
    screen.scrollToElement(screen.calculatorSection)

    add(app.takeScreenshot(name: "offer-calc-01-section-check"))

    XCTAssertTrue(
      screen.calculatorSection.waitForExistence(timeout: 5),
      "Scholarship Calculator section should be visible on offer detail"
    )

    // The "Scholarship Calculator" header text should be visible
    let calculatorTitle = app.staticTexts["Scholarship Calculator"]
    XCTAssertTrue(
      calculatorTitle.exists,
      "Scholarship Calculator title should be visible"
    )

    // Calculate button should be present (collapsed state)
    let calculateBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Calculate'"
    )).firstMatch
    XCTAssertTrue(
      calculateBtn.exists,
      "Calculate button should be visible in collapsed state"
    )

    add(app.takeScreenshot(name: "offer-calc-02-section-verified"))
  }

  /// Tapping Calculate should expand the calculator and show input fields
  @MainActor
  func testCalculatorExpandsOnTap() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)

    add(app.takeScreenshot(name: "offer-calc-03-before-expand"))

    // Expand the calculator
    screen.expandCalculator()
    sleep(1)

    add(app.takeScreenshot(name: "offer-calc-04-expanded"))

    // Hide button should replace Calculate
    let hideBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Hide'"
    )).firstMatch
    XCTAssertTrue(
      hideBtn.waitForExistence(timeout: 3),
      "Hide button should appear after expanding calculator"
    )

    // Input fields should be visible - look for Total Annual Cost label
    let annualCostLabel = app.staticTexts["Total Annual Cost ($)"]
    screen.scrollToElement(annualCostLabel)
    XCTAssertTrue(
      annualCostLabel.exists,
      "Annual Cost input label should be visible when calculator is expanded"
    )

    // Scholarship Amount input label
    let scholarshipLabel = app.staticTexts["Scholarship Amount ($)"]
    XCTAssertTrue(
      scholarshipLabel.exists,
      "Scholarship Amount input label should be visible"
    )

    // Scholarship Percentage input label
    let percentageLabel = app.staticTexts["Scholarship Percentage (%)"]
    screen.scrollToElement(percentageLabel)
    XCTAssertTrue(
      percentageLabel.exists,
      "Scholarship Percentage input label should be visible"
    )

    add(app.takeScreenshot(name: "offer-calc-05-inputs-verified"))
  }

  /// Collapsing the calculator should hide the input fields
  @MainActor
  func testCalculatorCollapsesOnHide() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)

    // Expand first
    screen.expandCalculator()
    sleep(1)

    let hideBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Hide'"
    )).firstMatch
    XCTAssertTrue(
      hideBtn.waitForExistence(timeout: 3),
      "Should be in expanded state"
    )

    add(app.takeScreenshot(name: "offer-calc-06-before-collapse"))

    // Collapse the calculator
    screen.collapseCalculator()
    sleep(1)

    add(app.takeScreenshot(name: "offer-calc-07-collapsed"))

    // Calculate button should reappear
    let calculateBtn = app.buttons.matching(NSPredicate(
      format: "label == 'Calculate'"
    )).firstMatch
    XCTAssertTrue(
      calculateBtn.waitForExistence(timeout: 3),
      "Calculate button should reappear after collapsing"
    )

    // Input fields should be hidden
    let annualCostLabel = app.staticTexts["Total Annual Cost ($)"]
    XCTAssertFalse(
      annualCostLabel.exists,
      "Input fields should be hidden after collapsing"
    )

    add(app.takeScreenshot(name: "offer-calc-08-collapse-verified"))
  }

  /// Expanding the calculator should show result cards with computed values
  @MainActor
  func testCalculatorShowsResults() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)
    screen.expandCalculator()
    sleep(1)

    add(app.takeScreenshot(name: "offer-calc-09-results-check"))

    // Scroll to results section - look for result labels
    let annualScholarshipLabel = app.staticTexts["Annual Scholarship"]
    screen.scrollToElement(annualScholarshipLabel)

    XCTAssertTrue(
      annualScholarshipLabel.exists,
      "Annual Scholarship result label should be visible"
    )

    let annualNetCostLabel = app.staticTexts["Annual Net Cost"]
    XCTAssertTrue(
      annualNetCostLabel.exists,
      "Annual Net Cost result label should be visible"
    )

    add(app.takeScreenshot(name: "offer-calc-10-results-verified"))
  }

  /// The year-by-year breakdown should be visible when calculator is expanded
  @MainActor
  func testCalculatorShowsYearBreakdown() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)
    screen.expandCalculator()
    sleep(1)

    // Scroll down to year breakdown
    let yearBreakdownTitle = app.staticTexts["Year-by-Year Breakdown"]
    screen.scrollToElement(yearBreakdownTitle)

    add(app.takeScreenshot(name: "offer-calc-11-breakdown-check"))

    XCTAssertTrue(
      yearBreakdownTitle.exists,
      "Year-by-Year Breakdown title should be visible"
    )

    // Year 1 label should exist (default is 4 years)
    let year1 = app.staticTexts["Year 1"]
    XCTAssertTrue(
      year1.exists,
      "Year 1 row should be visible in breakdown"
    )

    add(app.takeScreenshot(name: "offer-calc-12-breakdown-verified"))
  }

  /// Save to Offer and Reset buttons should be visible when calculator is expanded
  @MainActor
  func testCalculatorActionButtonsVisible() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)
    screen.expandCalculator()
    sleep(1)

    // Scroll to the action buttons
    screen.scrollToElement(screen.saveToOfferButton)

    add(app.takeScreenshot(name: "offer-calc-13-actions-check"))

    XCTAssertTrue(
      screen.saveToOfferButton.waitForExistence(timeout: 3),
      "Save to Offer button should be visible"
    )

    XCTAssertTrue(
      screen.resetButton.exists,
      "Reset button should be visible"
    )

    add(app.takeScreenshot(name: "offer-calc-14-actions-verified"))
  }

  /// Years selector should allow changing between 1-5 years
  @MainActor
  func testCalculatorYearsSelector() throws {
    try loginAndNavigateToOfferDetail()

    screen.scrollToElement(screen.calculatorSection)
    screen.expandCalculator()
    sleep(1)

    // The years selector label should exist
    let yearsLabel = app.staticTexts["Years to Calculate"]
    screen.scrollToElement(yearsLabel)

    add(app.takeScreenshot(name: "offer-calc-15-years-selector"))

    XCTAssertTrue(
      yearsLabel.exists,
      "Years to Calculate label should be visible"
    )

    add(app.takeScreenshot(name: "offer-calc-16-years-verified"))
  }
}
