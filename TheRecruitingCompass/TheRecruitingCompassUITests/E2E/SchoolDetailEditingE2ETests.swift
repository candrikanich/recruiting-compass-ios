import XCTest

final class SchoolDetailEditingE2ETests: XCTestCase {
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

  // MARK: - Notes Editing Tests

  @MainActor
  func testEditPublicNotes() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to Notes section
    // screen.scrollToElement(screen.notesEditButton)

    // add(app.takeScreenshot(name: "13-notes-view-mode"))

    // 3. Tap "Edit" button
    // screen.notesEditButton.tap()

    // 4. Verify text editor appears
    // XCTAssertTrue(screen.notesTextEditor.waitForExistence(timeout: 2),
    //               "Notes text editor should appear")
    // XCTAssertTrue(screen.notesSaveButton.exists,
    //               "Save button should be visible")
    // XCTAssertTrue(screen.notesCancelButton.exists,
    //               "Cancel button should be visible")

    // add(app.takeScreenshot(name: "14-notes-edit-mode"))

    // 5. Type new note text
    // let noteText = "Great campus visit on 2/5. Impressed with facilities."
    // screen.editNotes(noteText)

    // 6. Tap "Save"
    // screen.saveNotes()

    // 7. Wait for save to complete
    // app.waitForElementToDisappear(screen.notesSaveButton, timeout: 5)

    // 8. Verify editing mode exits
    // XCTAssertFalse(screen.notesTextEditor.exists,
    //                "Text editor should be hidden after save")
    // XCTAssertTrue(screen.notesEditButton.exists,
    //               "Edit button should reappear after save")

    // 9. Verify new note text displays
    // let noteDisplay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", noteText)).firstMatch
    // XCTAssertTrue(noteDisplay.exists,
    //               "New note text should be displayed")

    // add(app.takeScreenshot(name: "15-notes-saved"))

    // 10. Pull to refresh
    // screen.pullToRefresh()
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 11. Verify note persists
    // XCTAssertTrue(noteDisplay.exists,
    //               "Note should persist after refresh")

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testCancelNotesDiscardsDraft() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // Setup: School with existing notes
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // let originalNote = "Original note text"
    // Assume school has this note already

    // 1. Scroll to Notes section
    // screen.scrollToElement(screen.notesEditButton)

    // 2. Verify original note text
    // let originalNoteDisplay = app.staticTexts[originalNote]
    // XCTAssertTrue(originalNoteDisplay.exists,
    //               "Original note should be visible")

    // 3. Tap "Edit"
    // screen.notesEditButton.tap()

    // 4. Type draft note content
    // screen.notesTextEditor.tap()
    // screen.notesTextEditor.typeText("Draft note content that will be discarded")

    // add(app.takeScreenshot(name: "16-notes-draft-content"))

    // 5. Tap "Cancel"
    // screen.cancelNotesEditing()

    // 6. Verify editing mode exits
    // XCTAssertFalse(screen.notesTextEditor.exists,
    //                "Text editor should be hidden after cancel")

    // 7. Verify original note text unchanged
    // XCTAssertTrue(originalNoteDisplay.exists,
    //               "Original note text should be unchanged")

    // add(app.takeScreenshot(name: "17-notes-draft-discarded"))

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  // MARK: - Pros & Cons Tests

  @MainActor
  func testAddProToList() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to Pros & Cons section
    // screen.scrollToElement(screen.proTextField)

    // add(app.takeScreenshot(name: "22-pros-cons-empty"))

    // 3. Type pro text in Pro field
    // let proText = "Excellent coaching staff"
    // screen.addPro(proText)

    // 4. Verify pro appears in list
    // let proItem = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", proText)).firstMatch
    // XCTAssertTrue(proItem.waitForExistence(timeout: 2),
    //               "Pro should appear in list")

    // 5. Verify input field clears
    // XCTAssertEqual(screen.proTextField.value as? String, "",
    //                "Pro input field should be cleared")

    // add(app.takeScreenshot(name: "23-pro-added"))

    // 6. Pull to refresh
    // screen.pullToRefresh()
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 7. Verify pro persists
    // XCTAssertTrue(proItem.exists,
    //               "Pro should persist after refresh")

    // PLACEHOLDER: Mark as skip until School Detail can be loaded
    throw XCTSkip("Requires School Detail loading integration")
  }

  @MainActor
  func testRemoveConFromList() throws {
    // TODO: Requires School Detail with existing cons to be loaded
    // For now, it's a placeholder showing the expected flow

    // Setup: School with 3 cons
    // let cons = ["Con 1", "Con 2", "Con 3"]
    // createSchoolViaAPI(name: "Test University", cons: cons)

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to Pros & Cons section
    // screen.scrollToElement(screen.conTextField)

    // 3. Verify 3 cons exist
    // let conItems = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Con'"))
    // XCTAssertEqual(conItems.count, 3,
    //                "Should have 3 cons initially")

    // add(app.takeScreenshot(name: "24-cons-before-delete"))

    // 4. Swipe left on second con
    // let secondCon = screen.conItem(at: 1)
    // secondCon.swipeLeft()

    // 5. Tap "Delete" button
    // let deleteButton = app.buttons["Delete"]
    // deleteButton.tap()

    // 6. Verify con removed from list
    // XCTAssertEqual(conItems.count, 2,
    //                "Should have 2 cons after deletion")

    // add(app.takeScreenshot(name: "25-con-deleted"))

    // 7. Pull to refresh
    // screen.pullToRefresh()
    // app.waitForElementToDisappear(screen.loadingIndicator, timeout: 10)

    // 8. Verify con still deleted
    // XCTAssertEqual(conItems.count, 2,
    //                "Con should remain deleted after refresh")

    // PLACEHOLDER: Mark as skip until test data can be created
    throw XCTSkip("Requires test data creation via API")
  }

  // MARK: - Basic Info Tests

  @MainActor
  func testEditBasicInfoSheet() throws {
    // TODO: Requires School Detail to be loaded
    // For now, it's a placeholder showing the expected flow

    // 1. Navigate to School Detail
    // screen.navigateToSchoolDetailFromList(schoolName: "Test University")
    // XCTAssertTrue(screen.waitForSchoolToLoad(timeout: 10),
    //               "School should load")

    // 2. Scroll to Basic Info section
    // screen.scrollToElement(screen.editBasicInfoButton)

    // add(app.takeScreenshot(name: "26-basic-info-before"))

    // 3. Tap "Edit" button
    // screen.editBasicInfoButton.tap()

    // 4. Verify sheet presents
    // let sheet = app.sheets.firstMatch
    // XCTAssertTrue(sheet.waitForExistence(timeout: 2),
    //               "Basic Info sheet should present")

    // add(app.takeScreenshot(name: "27-basic-info-sheet"))

    // 5. Update Athletic Conference field
    // let conferenceField = app.textFields["Athletic Conference"]
    // conferenceField.tap()
    // conferenceField.clearAndTypeText("Big Ten")

    // 6. Update School Size field
    // let sizeField = app.textFields["School Size"]
    // sizeField.tap()
    // sizeField.clearAndTypeText("Large")

    // 7. Tap "Save"
    // let saveButton = app.buttons["Save"]
    // saveButton.tap()

    // 8. Verify sheet dismisses
    // app.waitForElementToDisappear(sheet, timeout: 5)

    // add(app.takeScreenshot(name: "28-basic-info-saved"))

    // 9. Verify basic info updates in detail view
    // screen.scrollToElement(screen.editBasicInfoButton)
    // let conferenceDisplay = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Big Ten'")).firstMatch
    // XCTAssertTrue(conferenceDisplay.exists,
    //               "Conference should be updated to Big Ten")

    // PLACEHOLDER: Mark as skip until SchoolBasicInfoSheet is accessible
    throw XCTSkip("Requires SchoolBasicInfoSheet integration")
  }
}
