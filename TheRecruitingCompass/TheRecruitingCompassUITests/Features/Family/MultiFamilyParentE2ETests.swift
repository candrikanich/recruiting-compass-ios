import XCTest

/// A parent who belongs to two families (#604). Needs the local Supabase stack seeded from web
/// `tests/e2e/seed` (web#1758: `parent-join`, `parent-leave`, `parent-multi`, family code `FAM-JOIN01`) and the web
/// dev server for the family API: set `TEST_RUNNER_E2E_SUPABASE_URL` and `TEST_RUNNER_E2E_API_BASE_URL`.
/// Join and leave change the seeded memberships, so re-run `npm run db:seed:test` in the web repo between runs.
/// A missing stack fails the run: a skipped test proves nothing.
final class MultiFamilyParentE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var tabs: MainTabNavigator!

  private let password = "TestPass123!"

  override func setUpWithError() throws {
    continueAfterFailure = false
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
    XCTAssertTrue(app.staticTexts["Dashboard"].exists || tabs.goTo(.dashboard))
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
    let cleared = NSPredicate(format: "value != 'FAM-JOIN01'")
    expectation(for: cleared, evaluatedWith: codeField)
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
    let options = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Family' AND label != 'Family' AND NOT (label CONTAINS ',')")
    )
    let seen = app.buttons.allElementsBoundByIndex.map(\.label)
    XCTAssertGreaterThanOrEqual(options.count, 2, "Both families listed: \(seen)")
    add(app.takeScreenshot(name: "switcher-after-join"))
  }

  // MARK: - Gap 3: plan and write access follow the selected family

  @MainActor
  func testSettingsPlanFollowsTheSelectedFamily() throws {
    try signIn("parent-multi@test.com")
    XCTAssertTrue(app.buttons["family_switcher"].waitForExistence(timeout: 20))
    let planBefore = try readPlanLabel()
    let switchedTo = try switchToTheOtherFamily()
    XCTAssertTrue(app.buttons["family_switcher"].waitForExistence(timeout: 20), "after switching to \(switchedTo)")
    let planAfter = try readPlanLabel()
    let plans = [planBefore, planAfter]
    XCTAssertTrue(
      plans.contains { $0.contains("Active — renews") }
        && plans.contains { $0.contains("Read-only — subscription needed") },
      "Seeded: one family active, the other read-only. Saw \(plans) after switching to \(switchedTo)"
    )
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
    XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 20))
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

  private func readPlanLabel() throws -> String {
    XCTAssertTrue(tabs.goToSettings())
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Active' OR label CONTAINS 'Read-only'"))
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 20), "Settings shows the plan row")
    return row.label
  }

  private func switchToTheOtherFamily() throws -> String {
    XCTAssertTrue(tabs.goTo(.dashboard))
    let switcher = app.buttons["family_switcher"]
    XCTAssertTrue(switcher.waitForExistence(timeout: 10))
    let current = switcher.staticTexts.firstMatch.label
    switcher.tap()
    // Both menu items can carry the same label (two families of a player named alike); the selected one is current.
    let labels = app.buttons.allElementsBoundByIndex.map(\.label)
    let items = app.buttons.matching(NSPredicate(format: "label == %@", current)).allElementsBoundByIndex
    guard let option = items.first(where: { !$0.isSelected }), items.count >= 2 else {
      XCTFail("The other family is listed; buttons: \(labels)")
      return current
    }
    let name = option.label
    option.tap()
    return name
  }
}
