import XCTest

final class SchoolDetailStatusManagementE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SchoolDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = SchoolDetailScreenObject(app: app)

    // TODO: Add helper to login and navigate to School Detail
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Status Management Tests

  @MainActor
  func testUpdateStatusFromInterestedToVisited() throws {
    // TODO: Requires School Detail with status "Interested" to be loaded
    // For now, it's a placeholder showing the expected flow

    // Setup: School with status "Interested"
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")

    // 1. Verify initial status is "Interested"
    // XCTAssertTrue(screen.statusPickerButton.label.contains("Interested"),
    //               "Initial status should be Interested")

    // add(app.takeScreenshot(name: "06-status-interested"))

    // 2. Tap status picker
    // screen.statusPickerButton.tap()

    // 3. Select "Visited"
    // screen.selectStatus("Visited")

    // 4. Wait for update to complete
    // sleep(1) // Brief wait for optimistic update

    // 5. Verify status chip updates to "Visited"
    // XCTAssertTrue(screen.statusPickerButton.label.contains("Visited"),
    //               "Status should update to Visited")

    // add(app.takeScreenshot(name: "07-status-visited"))

    // 6. Verify status history shows new entry
    // screen.scrollToElement(screen.statusHistorySection)
    // XCTAssertTrue(screen.statusHistorySection.exists,
    //               "Status history section should be visible")

    // 7. Pull to refresh
    // screen.pullToRefresh()
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 8. Verify status persists
    // XCTAssertTrue(screen.statusPickerButton.label.contains("Visited"),
    //               "Status should persist after refresh")

    // add(app.takeScreenshot(name: "08-status-persisted"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testToggleFavoriteStarOptimisticUpdate() throws {
    // TODO: Requires School Detail to be loaded (not favorite initially)
    // For now, it's a placeholder showing the expected flow

    // Setup: School that is not favorited
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 1. Verify initial state (not favorited)
    // let initialLabel = screen.favoriteButton.label
    // XCTAssertTrue(initialLabel.contains("Favorite"),
    //               "Should show 'Favorite' (not favorited)")

    // add(app.takeScreenshot(name: "09-not-favorited"))

    // 2. Tap favorite star
    // screen.tapFavoriteButton()

    // 3. Verify star fills immediately (optimistic update)
    // sleep(0.5) // Brief wait for UI update
    // let updatedLabel = screen.favoriteButton.label
    // XCTAssertTrue(updatedLabel.contains("Unfavorite"),
    //               "Should show 'Unfavorite' (favorited)")

    // add(app.takeScreenshot(name: "10-favorited"))

    // 4. Pull to refresh
    // screen.pullToRefresh()
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 5. Verify favorite state persists
    // XCTAssertTrue(screen.favoriteButton.label.contains("Unfavorite"),
    //               "Favorite should persist after refresh")

    // 6. Tap star again to unfavorite
    // screen.tapFavoriteButton()
    // sleep(0.5)

    // 7. Verify star empties
    // XCTAssertTrue(screen.favoriteButton.label.contains("Favorite"),
    //               "Should show 'Favorite' (not favorited)")

    // add(app.takeScreenshot(name: "11-unfavorited"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testStatusHistoryShowsAllChanges() throws {
    // TODO: Requires School Detail with multiple status changes to be loaded
    // Ideally created via API with known status history
    // For now, it's a placeholder showing the expected flow

    // Setup: Create school with multiple status changes via API
    // let schoolId = createSchoolViaAPI(
    //   name: "Test University",
    //   statusHistory: [
    //     ("Interested", "2025-01-01"),
    //     ("Contacted", "2025-01-15"),
    //     ("Visited", "2025-02-01")
    //   ]
    // )

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to Status History section
    // screen.scrollToElement(screen.statusHistorySection)

    // add(app.takeScreenshot(name: "12-status-history"))

    // 3. Verify all status changes visible
    // XCTAssertTrue(screen.statusHistorySection.exists,
    //               "Status history section should be visible")

    // 4. Verify timeline ordered by date (newest first)
    // let historyItems = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Visited' OR label CONTAINS 'Contacted' OR label CONTAINS 'Interested'"))
    // XCTAssertGreaterThanOrEqual(historyItems.count, 3,
    //                             "Should show at least 3 status changes")

    // 5. Verify user attribution shown
    // let attributionLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'by'")).firstMatch
    // XCTAssertTrue(attributionLabel.exists,
    //               "Should show user attribution for status changes")

    // PLACEHOLDER: Mark as skip until test data can be created
    throw XCTSkip("Requires test data creation via API")
  }
}
