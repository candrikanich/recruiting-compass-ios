import XCTest

/// A parent who belongs to two families (#604). Needs the local Supabase stack seeded from web
/// `tests/e2e/seed` (web#1758: `parent-join`, `parent-leave`, `parent-multi`, family code `FAM-JOIN01`) and the web
/// dev server for the family API: set `TEST_RUNNER_E2E_SUPABASE_URL` and `TEST_RUNNER_E2E_API_BASE_URL`.
/// Join and leave change the seeded memberships, so re-run `npm run db:seed:test` in the web repo between runs.
/// A missing stack or API URL fails the run: a skipped test proves nothing.
final class MultiFamilyParentE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var tabs: MainTabNavigator!

  private let password = "TestPass123!"

  // Seeded labels and plan texts (web `tests/e2e/seed/multi-family-parent.ts`, `family-lifecycle.ts`).
  /// The renewal day shifts with the simulator's time zone (seeded at 2090-01-15 UTC), so only the year is pinned.
  private let seatedPlanPrefix = "Active — renews"
  private let seatedPlanYear = "2090"
  private let unseatedPlan = "Read-only — subscription needed"
  private let joinHomeFamily = "Join's Family"
  private let joinableFamily = "Joinable's Family"
  private let joinableSchool = "[multi-family-seed] Joinable Family School"

  private enum SeededFamily: String {
    case seated = "Family A School"
    case unseated = "Family B School"
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    try E2ETestEnvironment.requireAPIBaseURL()
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()
    tabs = MainTabNavigator(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    tabs = nil
  }

  // MARK: - Gap 1: join a second family by Family Code

  @MainActor
  func testJoiningASecondFamilyByCodeShowsTheSwitcherWithoutARefresh() throws {
    try signIn("parent-join@test.com")
    let switcher = app.buttons["family_switcher"]
    XCTAssertFalse(switcher.waitForExistence(timeout: 5), "One family: no switcher yet")

    try openFamilyManagement()
    let codeField = app.textFields["Enter Family Code"]
    XCTAssertTrue(codeField.waitForExistence(timeout: 10))
    codeField.tap()
    codeField.typeText("FAM-JOIN01")
    let join = app.buttons["Join family button"]
    XCTAssertTrue(join.isEnabled)
    join.tap()
    // The form clears its input once the join went through.
    expectation(for: NSPredicate(format: "value != 'FAM-JOIN01'"), evaluatedWith: codeField)
    waitForExpectations(timeout: 30)
    // No pull-to-refresh and no relaunch: only a tab change back to the Dashboard.
    for _ in 0..<3 where !app.tabBars.buttons["Dashboard"].isHittable {
      app.navigationBars.buttons.firstMatch.tap()
    }
    XCTAssertTrue(tabs.goTo(.dashboard))
    XCTAssertTrue(
      switcher.waitForExistence(timeout: 30),
      "The switcher must appear as soon as the parent is in two families"
    )

    switcher.tap()
    XCTAssertTrue(familyMenuItem(joinHomeFamily).waitForExistence(timeout: 5), "Join Home is listed")
    let joinable = familyMenuItem(joinableFamily)
    XCTAssertTrue(joinable.waitForExistence(timeout: 5), "The joined family is listed")
    joinable.tap()

    XCTAssertTrue(tabs.goTo(.schools))
    XCTAssertTrue(
      row(containing: joinableSchool).waitForExistence(timeout: 30),
      "The joined family's seeded school is listed after switching to it"
    )
  }

  // MARK: - Gap 3: plan and write access follow the selected family

  @MainActor
  func testSettingsPlanFollowsTheSelectedFamily() throws {
    try signIn("parent-multi@test.com")
    XCTAssertTrue(app.buttons["family_switcher"].waitForExistence(timeout: 20))
    let first = try selectedSeededFamily()
    try assertPlan(of: first)

    try switchToTheOtherFamily()
    let second = try selectedSeededFamily()
    XCTAssertNotEqual(first, second, "The switch moved to the other family")
    try assertPlan(of: second)
  }

  @MainActor
  func testAddingASchoolInTheReadOnlyFamilyIsRefusedAndNothingIsAdded() throws {
    try signIn("parent-multi@test.com")
    XCTAssertTrue(app.buttons["family_switcher"].waitForExistence(timeout: 20))
    if try selectedSeededFamily() != .unseated { try switchToTheOtherFamily() }
    XCTAssertEqual(try selectedSeededFamily(), .unseated, "Working in the read-only family")

    let addSchool = AddSchoolScreenObject(app: app)
    XCTAssertTrue(addSchool.navigateToAddSchoolFromDashboard())
    let name = "Refused Write \(Int(Date().timeIntervalSince1970))"
    addSchool.nameTextField.tap()
    addSchool.nameTextField.typeText(name + "\n")
    addSchool.scrollToElement(addSchool.addSchoolButton)
    addSchool.addSchoolButton.tap()

    XCTAssertTrue(addSchool.errorAlert.waitForExistence(timeout: 30), "The refused write is shown to the user")
    XCTAssertTrue(
      app.alerts.staticTexts["Failed to create school. Please try again."].exists,
      "The alert names the failed action"
    )
    XCTAssertFalse(app.navigationBars["School Details"].exists, "A refused write opens no school")
    app.alerts.buttons.firstMatch.tap()
    addSchool.tapBackButton()
    XCTAssertTrue(app.navigationBars["Schools"].waitForExistence(timeout: 10))
    XCTAssertTrue(row(containing: SeededFamily.unseated.rawValue).waitForExistence(timeout: 30))
    XCTAssertFalse(row(containing: name).exists, "No row appears for the refused school")
  }

  // MARK: - Gap 4: leave one of two families

  @MainActor
  func testLeavingOneOfTwoFamiliesKeepsTheOtherAndDropsTheSwitcher() throws {
    try signIn("parent-leave@test.com")
    let switcher = app.buttons["family_switcher"]
    XCTAssertTrue(switcher.waitForExistence(timeout: 20), "Two families: switcher shown")

    try openFamilyManagement()
    let leave = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Leave '")).firstMatch
    XCTAssertTrue(leave.waitForExistence(timeout: 15))
    for _ in 0..<4 where !leave.isHittable { app.swipeUp() }
    leave.tap()
    let confirm = app.buttons["Leave Family"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.tap()

    XCTAssertTrue(tabs.goTo(.dashboard))
    // The Dashboard rebuilds onto the remaining family; give it time to render before asserting the switcher is gone,
    // or an empty loading state would pass for "no switcher".
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS 'checklist' OR label CONTAINS 'Junior Year'"))
        .firstMatch.waitForExistence(timeout: 30),
      "The Dashboard shows the remaining family's content"
    )
    sleep(5)
    XCTAssertFalse(switcher.exists, "One family left: the switcher disappears")
    add(app.takeScreenshot(name: "dashboard-after-leave"))
  }

  // MARK: - Helpers

  private func signIn(_ email: String) throws {
    app.loginAsParent(email: email, password: password)
    guard app.waitForLogin(timeout: 30) else {
      add(app.takeScreenshot(name: "login-failed"))
      XCTFail("Login failed: the local Supabase stack with the web#1758 seed must be running")
      throw XCTSkip("login failed")
    }
  }

  private func openFamilyManagement() throws {
    XCTAssertTrue(tabs.goToSettings(), "Settings should open from the More tab")
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Family Management'")).firstMatch
    for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
    row.tap()
    XCTAssertTrue(app.navigationBars["Family Management"].waitForExistence(timeout: 10))
  }

  /// Which of parent-multi's two families is showing, read from the seeded school the Schools tab lists.
  private func selectedSeededFamily() throws -> SeededFamily {
    XCTAssertTrue(tabs.goTo(.schools))
    let seated = row(containing: SeededFamily.seated.rawValue)
    let unseated = row(containing: SeededFamily.unseated.rawValue)
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      if seated.exists != unseated.exists { return seated.exists ? .seated : .unseated }
      _ = seated.waitForExistence(timeout: 1)
    }
    XCTFail("Exactly one of the seeded families' schools should be listed")
    throw XCTSkip("no seeded school listed")
  }

  /// Settings must show the plan of the family the Schools tab says is selected, never the other family's.
  private func assertPlan(of family: SeededFamily) throws {
    XCTAssertTrue(tabs.goToSettings())
    let seated = NSPredicate(
      format: "label CONTAINS %@ AND label CONTAINS %@", seatedPlanPrefix, seatedPlanYear
    )
    let unseated = NSPredicate(format: "label CONTAINS %@", unseatedPlan)
    let (expected, other) = family == .seated ? (seated, unseated) : (unseated, seated)
    XCTAssertTrue(
      app.buttons.matching(expected).firstMatch.waitForExistence(timeout: 30),
      "Settings shows the \(family) family's own plan"
    )
    XCTAssertFalse(app.buttons.matching(other).firstMatch.exists, "Settings must not show the other family's plan")
  }

  private func familyMenuItem(_ label: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  private func row(containing text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  /// Both of parent-multi's menu items carry the label "Test's Family", so the unselected one is the other family.
  private func switchToTheOtherFamily() throws {
    XCTAssertTrue(tabs.goTo(.dashboard))
    let switcher = app.buttons["family_switcher"]
    XCTAssertTrue(switcher.waitForExistence(timeout: 10))
    let current = switcher.staticTexts.firstMatch.label
    switcher.tap()
    let items = app.buttons.matching(NSPredicate(format: "label == %@", current)).allElementsBoundByIndex
    guard items.count == 2, let option = items.first(where: { !$0.isSelected }) else {
      XCTFail("Two menu items labelled \(current), one selected; saw \(items.map(\.label))")
      return
    }
    option.tap()
    XCTAssertTrue(switcher.waitForExistence(timeout: 20))
  }
}
