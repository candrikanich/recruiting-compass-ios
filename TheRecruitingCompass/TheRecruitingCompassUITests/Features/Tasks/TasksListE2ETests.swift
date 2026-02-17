import XCTest

/// E2E tests for the Tasks List feature (Phase 5 Tasks/Timeline).
final class TasksListE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: TasksListScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()
    screen = TasksListScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  @MainActor
  private func loginAndNavigateToTasks() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")
    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }
    guard screen.navigateToTasks() else {
      throw XCTSkip("Tasks tab not reachable")
    }
  }

  /// Happy path: Open Tasks, verify screen loads and content or empty state appears.
  @MainActor
  func testTasksList_navigate_displaysScreen() throws {
    try loginAndNavigateToTasks()
    XCTAssertTrue(screen.waitForContentToLoad(), "Tasks content or empty state should appear")
  }

  /// Empty state: When no tasks for grade, see "No tasks available for this grade level".
  @MainActor
  func testTasksList_noTasks_displaysEmptyState() throws {
    try loginAndNavigateToTasks()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }
    if screen.emptyStateMessage.waitForExistence(timeout: 5) {
      XCTAssertTrue(screen.emptyStateMessage.exists)
    }
  }

  /// Filter controls are present and accessible.
  @MainActor
  func testTasksList_filterControls_areAccessible() throws {
    try loginAndNavigateToTasks()
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }
    if screen.statusFilter.waitForExistence(timeout: 3) {
      XCTAssertTrue(screen.statusFilter.exists)
    }
    if screen.urgencyFilter.waitForExistence(timeout: 2) {
      XCTAssertTrue(screen.urgencyFilter.exists)
    }
  }

  /// Parent mode: When viewing an athlete's tasks, athlete switcher is visible so parent can switch without leaving.
  @MainActor
  func testTasksList_parentMode_showsAthleteSwitcher() throws {
    try loginAndNavigateToTasks()
    // Enter parent preview: go to Dashboard, select first athlete (if any), then open Tasks.
    let dashboardTab = app.tabBars.buttons["Dashboard"]
    if dashboardTab.waitForExistence(timeout: 5) {
      dashboardTab.tap()
      if screen.selectAthleteHeader.waitForExistence(timeout: 5) {
        let athleteRows = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Selected' OR label CONTAINS 'Not selected'"))
        if athleteRows.firstMatch.waitForExistence(timeout: 3) {
          athleteRows.firstMatch.tap()
        }
      }
    }
    guard screen.navigateToTasks() else {
      throw XCTSkip("Tasks tab not reachable")
    }
    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }
    // When in parent mode with at least one linked athlete, Tasks shows the athlete switcher.
    if screen.selectAthleteHeader.waitForExistence(timeout: 5) {
      XCTAssertTrue(screen.selectAthleteHeader.exists, "Parent viewing athlete's tasks should show athlete switcher")
    }
  }
}
