import XCTest

final class SchoolDetailNavigationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SchoolDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = SchoolDetailScreenObject(app: app)

    // TODO: Add helper to login and navigate to Schools tab
    // For now, assumes we can navigate to a school detail
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Navigation Tests

  @MainActor
  func testNavigateToSchoolDetailFromList() throws {
    // TODO: This test requires integration with Schools List
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to Schools tab
    // app.tabBars.buttons["Schools"].tap()

    // 2. Tap on a school card
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")

    // 3. Verify School Detail screen appears
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School Detail should load successfully")

    // 4. Verify navigation title
    // XCTAssertTrue(screen.navigationTitle.exists,
    //               "Navigation title 'School Details' should be visible")

    // 5. Verify favorite button visible
    // XCTAssertTrue(screen.favoriteButton.exists,
    //               "Favorite button should be visible")

    // 6. Verify status picker visible
    // XCTAssertTrue(screen.statusPickerButton.exists,
    //               "Status picker button should be visible")

    // add(app.takeScreenshot(name: "01-school-detail-loaded"))

    // PLACEHOLDER: Mark as skip until Schools List navigation is implemented
    throw XCTSkip("Requires Schools List navigation integration")
  }

  @MainActor
  func testPullToRefreshReloadsSchool() throws {
    // TODO: This test requires school detail to be loaded first
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")

    // 2. Wait for initial load
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load initially")

    // add(app.takeScreenshot(name: "02-before-refresh"))

    // 3. Pull down to refresh
    // screen.pullToRefresh()

    // 4. Verify loading indicator appears (brief)
    // XCTAssertTrue(screen.loadingIndicator.waitForExistence(timeout: 2),
    //               "Loading indicator should appear during refresh")

    // 5. Wait for loading to complete
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 6. Verify data refreshes (still on detail view)
    // XCTAssertTrue(screen.navigationTitle.exists,
    //               "Should still be on School Detail after refresh")

    // 7. Verify no error state
    // XCTAssertFalse(screen.errorMessage.exists,
    //                "Should not show error after successful refresh")

    // add(app.takeScreenshot(name: "03-after-refresh"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testBackButtonNavigatesToSchoolsList() throws {
    // TODO: This test requires Schools List navigation to be implemented
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")

    // 2. Verify on School Detail
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "Should be on School Detail")

    // add(app.takeScreenshot(name: "04-on-school-detail"))

    // 3. Tap back button
    // screen.tapBackButton()

    // 4. Verify navigation back to Schools List
    // let schoolsListTitle = app.navigationBars["Schools"]
    // XCTAssertTrue(schoolsListTitle.waitForExistence(timeout: 5),
    //               "Should navigate back to Schools List")

    // 5. Verify school still in list
    // let schoolCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Test University'")).firstMatch
    // XCTAssertTrue(schoolCard.exists,
    //               "School should still be in the list")

    // add(app.takeScreenshot(name: "05-back-to-schools-list"))

    // PLACEHOLDER: Mark as skip until Schools List exists
    throw XCTSkip("Requires Schools List view to exist")
  }
}
