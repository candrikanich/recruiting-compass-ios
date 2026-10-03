import XCTest

/// Smoke-gate journeys for Add School (scripts/ci/e2e-smoke-suite.txt): a parent can open
/// the form from the Schools tab, save a school by name, and leave without saving.
/// Autocomplete, duplicate detection and field validation live in their own classes —
/// autocomplete calls the web API, which CI points at prod, so it can't gate here.
final class AddSchoolE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: AddSchoolScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = AddSchoolScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  @MainActor
  private func loginAndOpenAddSchool() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    screen.navigateToAddSchoolFromDashboard()
    add(app.takeScreenshot(name: "add-school-form"))
  }

  /// Submit stays disabled until a name is entered; saving opens the new school's detail.
  @MainActor
  func testAddSchool_byName_opensSchoolDetail() throws {
    try loginAndOpenAddSchool()

    screen.scrollToElement(screen.addSchoolButton)
    XCTAssertTrue(screen.addSchoolButton.exists, "Add School submit button should be on the form")
    XCTAssertFalse(screen.addSchoolButton.isEnabled, "Submit should be disabled while the name is empty")

    scrollUpToElement(screen.nameTextField)
    let schoolName = "Smoke Test University \(Int(Date().timeIntervalSince1970))"
    screen.nameTextField.tap()
    // Return ends editing, so the keyboard no longer covers the submit button.
    screen.nameTextField.typeText(schoolName + "\n")
    add(app.takeScreenshot(name: "add-school-name-entered"))

    screen.scrollToElement(screen.addSchoolButton)
    XCTAssertTrue(screen.addSchoolButton.isEnabled, "Submit should be enabled once a name is entered")
    screen.addSchoolButton.tap()

    XCTAssertTrue(
      app.navigationBars["School Details"].waitForExistence(timeout: 20),
      "Saving should open the new school's detail screen"
    )
    let nameOnDetail = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", schoolName)).firstMatch
    XCTAssertTrue(nameOnDetail.waitForExistence(timeout: 10), "Detail screen should show \"\(schoolName)\"")
    add(app.takeScreenshot(name: "add-school-detail"))
  }

  /// Leaving the form without saving returns to the Schools list.
  @MainActor
  func testAddSchool_backWithoutSaving_returnsToSchoolsList() throws {
    try loginAndOpenAddSchool()

    screen.nameTextField.tap()
    screen.nameTextField.typeText("Unsaved School\n")

    XCTAssertTrue(screen.backButton.waitForExistence(timeout: 5), "Back button should be in the toolbar")
    screen.tapBackButton()

    XCTAssertTrue(
      app.navigationBars["Schools"].waitForExistence(timeout: 10),
      "Back should return to the Schools list"
    )
    XCTAssertFalse(screen.navigationTitle.exists, "Add School form should be dismissed")
    add(app.takeScreenshot(name: "add-school-back-to-list"))
  }

  private func scrollUpToElement(_ element: XCUIElement, maxSwipes: Int = 10) {
    var swipes = 0
    while !element.isHittable && swipes < maxSwipes {
      app.swipeDown()
      swipes += 1
    }
  }
}
