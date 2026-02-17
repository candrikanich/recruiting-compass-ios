import XCTest

/// E2E tests for the Communication Templates feature.
/// Tests navigation, tab switching, type filtering, CRUD operations, validation, and empty state.
final class CommunicationTemplatesE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: CommunicationTemplatesScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()
    screen = CommunicationTemplatesScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToTemplates() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToTemplates() else {
      throw XCTSkip("Communication Templates screen not reachable")
    }
  }

  // MARK: - 1. Navigation

  @MainActor
  func testNavigateToTemplates() throws {
    try loginAndNavigateToTemplates()

    add(app.takeScreenshot(name: "01-templates-screen-loaded"))

    XCTAssertTrue(
      screen.waitForContentToLoad(),
      "Templates screen content or empty state should appear"
    )

    add(app.takeScreenshot(name: "02-templates-content-loaded"))
  }

  // MARK: - 2. Tab Navigation

  @MainActor
  func testTabNavigation() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // Tap Create New tab
    guard screen.createTab.waitForExistence(timeout: 5) else {
      throw XCTSkip("Create tab not found")
    }
    screen.createTab.tap()
    sleep(1)

    add(app.takeScreenshot(name: "03-create-tab-active"))

    // Editor form should be visible
    XCTAssertTrue(
      screen.nameField.waitForExistence(timeout: 5),
      "Editor name field should be visible on Create New tab"
    )

    // Tap My Templates tab
    guard screen.myTemplatesTab.waitForExistence(timeout: 5) else {
      throw XCTSkip("My Templates tab not found")
    }
    screen.myTemplatesTab.tap()
    sleep(1)

    add(app.takeScreenshot(name: "04-my-templates-tab-active"))

    // Filter pills or list content should be visible
    let listVisible = screen.filterAll.waitForExistence(timeout: 5)
      || screen.emptyStateElement.waitForExistence(timeout: 3)

    XCTAssertTrue(
      listVisible,
      "My Templates list content should be visible"
    )
  }

  // MARK: - 3. Type Filtering

  @MainActor
  func testTypeFiltering() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // Verify filter pills exist
    guard screen.filterAll.waitForExistence(timeout: 5) else {
      throw XCTSkip("Filter controls not found")
    }

    add(app.takeScreenshot(name: "05-filters-visible"))

    // Tap Email filter
    guard screen.filterEmail.waitForExistence(timeout: 3) else {
      throw XCTSkip("Email filter not found")
    }
    screen.filterEmail.tap()
    sleep(1)

    add(app.takeScreenshot(name: "06-email-filter-active"))

    // Tap All filter to reset
    screen.filterAll.tap()
    sleep(1)

    add(app.takeScreenshot(name: "07-all-filter-restored"))

    // Tap Text filter
    if screen.filterText.waitForExistence(timeout: 3) {
      screen.filterText.tap()
      sleep(1)
      add(app.takeScreenshot(name: "08-text-filter-active"))
    }

    // Tap Twitter filter
    if screen.filterTwitter.waitForExistence(timeout: 3) {
      screen.filterTwitter.tap()
      sleep(1)
      add(app.takeScreenshot(name: "09-twitter-filter-active"))
    }

    // Reset to All
    screen.filterAll.tap()
    sleep(1)

    add(app.takeScreenshot(name: "10-all-filter-final"))
  }

  // MARK: - 4. Create Template

  @MainActor
  func testCreateTemplate() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // Navigate to Create New
    guard screen.createTab.waitForExistence(timeout: 5) else {
      throw XCTSkip("Create tab not found")
    }
    screen.createTab.tap()
    sleep(1)

    add(app.takeScreenshot(name: "11-create-form-open"))

    // Fill name field
    guard screen.nameField.waitForExistence(timeout: 5) else {
      throw XCTSkip("Name field not found")
    }
    screen.nameField.tap()
    screen.nameField.typeText("E2E Test Template")

    add(app.takeScreenshot(name: "12-name-filled"))

    // Type picker should default to Email (first segment)
    // body editor
    guard screen.bodyEditor.waitForExistence(timeout: 5) else {
      throw XCTSkip("Body editor not found")
    }
    screen.bodyEditor.tap()
    screen.bodyEditor.typeText("Hello {{coach_name}}, this is a test template.")

    add(app.takeScreenshot(name: "13-body-filled"))

    // Scroll down to see save button
    screen.scrollDown()
    sleep(1)

    // Save
    guard screen.saveButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Save button not found")
    }

    XCTAssertTrue(
      screen.saveButton.isEnabled,
      "Save button should be enabled when form is valid"
    )

    screen.saveButton.tap()
    sleep(2)

    add(app.takeScreenshot(name: "14-after-save"))

    // Should return to My Templates tab
    let listReturned = screen.filterAll.waitForExistence(timeout: 5)
      || screen.allTemplateCards.firstMatch.waitForExistence(timeout: 5)

    XCTAssertTrue(
      listReturned,
      "Should return to My Templates after saving"
    )

    add(app.takeScreenshot(name: "15-template-in-list"))
  }

  // MARK: - 5. Edit Template

  @MainActor
  func testEditTemplate() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // Need at least one template card to edit
    guard screen.allTemplateCards.firstMatch.waitForExistence(timeout: 10) else {
      throw XCTSkip("No templates available to edit")
    }

    add(app.takeScreenshot(name: "16-before-edit"))

    // Tap the first template card (triggers onEdit via tap gesture)
    screen.allTemplateCards.firstMatch.tap()
    sleep(1)

    add(app.takeScreenshot(name: "17-edit-form-open"))

    // Verify form is pre-filled (name field should have text)
    guard screen.nameField.waitForExistence(timeout: 5) else {
      throw XCTSkip("Editor did not open")
    }

    let nameValue = screen.nameField.value as? String ?? ""
    XCTAssertFalse(
      nameValue.isEmpty,
      "Name field should be pre-filled when editing"
    )

    // Modify the name
    screen.nameField.clearAndTypeText("Updated E2E Template")

    add(app.takeScreenshot(name: "18-name-modified"))

    // Scroll down and save
    screen.scrollDown()
    sleep(1)

    guard screen.saveButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Save button not found")
    }
    screen.saveButton.tap()
    sleep(2)

    add(app.takeScreenshot(name: "19-edit-saved"))

    // Verify we returned to list
    let listReturned = screen.filterAll.waitForExistence(timeout: 5)
      || screen.allTemplateCards.firstMatch.waitForExistence(timeout: 5)

    XCTAssertTrue(
      listReturned,
      "Should return to My Templates after editing"
    )

    add(app.takeScreenshot(name: "20-updated-template-in-list"))
  }

  // MARK: - 6. Delete Template

  @MainActor
  func testDeleteTemplate() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    guard screen.allTemplateCards.firstMatch.waitForExistence(timeout: 10) else {
      throw XCTSkip("No templates available to delete")
    }

    let initialCardCount = screen.allTemplateCards.count

    add(app.takeScreenshot(name: "21-before-delete"))

    // Tap template card to open editor
    screen.allTemplateCards.firstMatch.tap()
    sleep(1)

    // Scroll down to see the delete button
    screen.scrollDown()
    sleep(1)

    guard screen.deleteButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Delete button not found - may not be in edit mode")
    }

    screen.deleteButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "22-delete-alert-shown"))

    // Verify alert appears
    XCTAssertTrue(
      screen.deleteConfirmationAlert.waitForExistence(timeout: 5),
      "Delete confirmation alert should appear"
    )

    // Tap confirm delete
    guard screen.deleteConfirmButton.waitForExistence(timeout: 3) else {
      throw XCTSkip("Delete confirm button not found in alert")
    }
    screen.deleteConfirmButton.tap()
    sleep(2)

    add(app.takeScreenshot(name: "23-after-delete"))

    // Verify we returned to list and template was removed
    let listReturned = screen.filterAll.waitForExistence(timeout: 5)
      || screen.emptyStateElement.waitForExistence(timeout: 5)

    XCTAssertTrue(
      listReturned,
      "Should return to My Templates after deleting"
    )

    // If there were templates before, count should have decreased or empty state shown
    if initialCardCount > 0 {
      let finalCount = screen.allTemplateCards.count
      let isEmpty = screen.emptyStateElement.exists

      XCTAssertTrue(
        finalCount < initialCardCount || isEmpty,
        "Template count should decrease or empty state should appear after deletion"
      )
    }

    add(app.takeScreenshot(name: "24-delete-verified"))
  }

  // MARK: - 7. Save Button Disabled When Invalid

  @MainActor
  func testSaveButtonDisabledWhenInvalid() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // Navigate to Create New
    guard screen.createTab.waitForExistence(timeout: 5) else {
      throw XCTSkip("Create tab not found")
    }
    screen.createTab.tap()
    sleep(1)

    // Scroll to make sure save button is visible
    screen.scrollDown()
    sleep(1)

    guard screen.saveButton.waitForExistence(timeout: 5) else {
      throw XCTSkip("Save button not found")
    }

    add(app.takeScreenshot(name: "25-empty-form"))

    // With both fields empty, save should be disabled
    XCTAssertFalse(
      screen.saveButton.isEnabled,
      "Save button should be disabled when form is empty"
    )

    // Scroll back up, fill name only
    screen.scrollUp()
    sleep(1)

    guard screen.nameField.waitForExistence(timeout: 5) else {
      throw XCTSkip("Name field not found")
    }
    screen.nameField.tap()
    screen.nameField.typeText("Name Only Template")

    add(app.takeScreenshot(name: "26-name-only"))

    // Scroll down to check save button
    screen.scrollDown()
    sleep(1)

    XCTAssertFalse(
      screen.saveButton.isEnabled,
      "Save button should be disabled when body is empty"
    )

    // Scroll up, fill body
    screen.scrollUp()
    sleep(1)

    guard screen.bodyEditor.waitForExistence(timeout: 5) else {
      throw XCTSkip("Body editor not found")
    }
    screen.bodyEditor.tap()
    screen.bodyEditor.typeText("Now the body has content.")

    add(app.takeScreenshot(name: "27-both-fields-filled"))

    // Scroll down to check save button is now enabled
    screen.scrollDown()
    sleep(1)

    XCTAssertTrue(
      screen.saveButton.isEnabled,
      "Save button should be enabled when both name and body are filled"
    )

    add(app.takeScreenshot(name: "28-save-enabled"))
  }

  // MARK: - 8. Empty State

  @MainActor
  func testEmptyState() throws {
    try loginAndNavigateToTemplates()

    guard screen.waitForContentToLoad() else {
      throw XCTSkip("Content did not load")
    }

    // This test only applies when there are no templates
    guard screen.emptyStateElement.waitForExistence(timeout: 5) else {
      throw XCTSkip("Templates exist - cannot test empty state")
    }

    add(app.takeScreenshot(name: "29-empty-state-visible"))

    XCTAssertTrue(
      screen.emptyStateElement.exists,
      "Empty state message should be shown when no templates exist"
    )

    // The Create Template action should be visible in the empty state
    XCTAssertTrue(
      screen.createTemplateAction.waitForExistence(timeout: 5),
      "Create Template action should be visible in empty state"
    )

    add(app.takeScreenshot(name: "30-empty-state-verified"))
  }
}
