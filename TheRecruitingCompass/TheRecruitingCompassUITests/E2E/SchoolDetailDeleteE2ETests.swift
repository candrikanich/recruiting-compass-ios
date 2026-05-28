import XCTest

final class SchoolDetailDeleteE2ETests: XCTestCase {
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

  // MARK: - Delete Tests

  @MainActor
  func testDeleteSchoolWithConfirmation() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // Setup: Create test school via API
    // let schoolName = "Test School to Delete"
    // let schoolId = createSchoolViaAPI(name: schoolName)

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: schoolName)
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // add(app.takeScreenshot(name: "29-before-delete"))

    // 2. Scroll to bottom
    // screen.scrollToBottom()

    // 3. Tap "Delete School" button
    // screen.deleteSchoolButton.tap()

    // 4. Verify confirmation alert appears
    // XCTAssertTrue(screen.deleteConfirmationAlert.waitForExistence(timeout: 2),
    //               "Delete confirmation alert should appear")

    // add(app.takeScreenshot(name: "30-delete-confirmation"))

    // 5. Verify alert message mentions "cannot be undone"
    // let alertMessage = screen.deleteConfirmationAlert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cannot be undone'")).firstMatch
    // XCTAssertTrue(alertMessage.exists,
    //               "Alert should warn that action cannot be undone")

    // 6. Tap "Delete" button in alert
    // screen.confirmDelete()

    // 7. Wait for navigation back to Schools List
    // let schoolsListTitle = app.navigationBars["Schools"]
    // XCTAssertTrue(schoolsListTitle.waitForExistence(timeout: 10),
    //               "Should navigate back to Schools List after delete")

    // add(app.takeScreenshot(name: "31-back-to-list-after-delete"))

    // 8. Verify school no longer in list
    // let deletedSchoolCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", schoolName)).firstMatch
    // XCTAssertFalse(deletedSchoolCard.exists,
    //                "Deleted school should not be in the list")

    // 9. Attempt to navigate to school via deep link (should fail)
    // navigateToSchoolViaDeepLink(schoolId: schoolId)

    // 10. Verify error state
    // XCTAssertTrue(screen.errorMessage.waitForExistence(timeout: 5),
    //               "Should show error when trying to load deleted school")

    // add(app.takeScreenshot(name: "32-deleted-school-error"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testCancelDeleteKeepsSchool() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // Setup: School to test cancel delete
    // let schoolName = "Test School for Cancel"
    // createSchoolViaAPI(name: schoolName)

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: schoolName)
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to bottom
    // screen.scrollToBottom()

    // add(app.takeScreenshot(name: "33-before-cancel-delete"))

    // 3. Tap "Delete School" button
    // screen.deleteSchoolButton.tap()

    // 4. Verify confirmation alert appears
    // XCTAssertTrue(screen.deleteConfirmationAlert.waitForExistence(timeout: 2),
    //               "Delete confirmation alert should appear")

    // add(app.takeScreenshot(name: "34-delete-confirmation-cancel"))

    // 5. Tap "Cancel" button in alert
    // screen.cancelDelete()

    // 6. Verify alert dismisses
    // app.waitForElementToDisappear(screen.deleteConfirmationAlert, timeout: 2)

    // 7. Verify still on School Detail screen
    // XCTAssertTrue(screen.navigationTitle.exists,
    //               "Should still be on School Detail after cancel")

    // add(app.takeScreenshot(name: "35-still-on-detail-after-cancel"))

    // 8. Verify school data unchanged
    // let schoolNameLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", schoolName)).firstMatch
    // XCTAssertTrue(schoolNameLabel.exists,
    //               "School name should still be displayed")

    // 9. Navigate back to list
    // screen.tapBackButton()

    // 10. Verify school still in list
    // let schoolCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", schoolName)).firstMatch
    // XCTAssertTrue(schoolCard.waitForExistence(timeout: 5),
    //               "School should still be in the list")

    // add(app.takeScreenshot(name: "36-school-still-in-list"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }
}
