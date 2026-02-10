import XCTest

final class SchoolDetailScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["School Details"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons.firstMatch
  }

  // MARK: - Header Elements

  var schoolNameLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'University' OR label CONTAINS 'College'")).firstMatch
  }

  var favoriteButton: XCUIElement {
    app.buttons["favorite-button"]
  }

  // MARK: - Status Elements

  var statusPickerButton: XCUIElement {
    app.buttons["status-picker-button"]
  }

  func statusOption(_ status: String) -> XCUIElement {
    app.buttons[status]
  }

  var statusHistorySection: XCUIElement {
    app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Status history'")).firstMatch
  }

  // MARK: - Notes Elements (Public)

  var notesEditButton: XCUIElement {
    app.buttons["notes-edit-button"]
  }

  var notesTextEditor: XCUIElement {
    app.textViews["notes-text-editor"]
  }

  var notesSaveButton: XCUIElement {
    app.buttons["notes-save-button"]
  }

  var notesCancelButton: XCUIElement {
    app.buttons["notes-cancel-button"]
  }

  // MARK: - Private Notes Elements

  var privateNotesEditButton: XCUIElement {
    app.buttons["private-notes-edit-button"]
  }

  var privateNotesTextEditor: XCUIElement {
    app.textViews["private-notes-text-editor"]
  }

  var privateNotesSaveButton: XCUIElement {
    app.buttons["private-notes-save-button"]
  }

  var privateNotesCancelButton: XCUIElement {
    app.buttons["private-notes-cancel-button"]
  }

  // MARK: - Pros & Cons Elements

  var proTextField: XCUIElement {
    app.textFields["pro-text-field"]
  }

  var addProButton: XCUIElement {
    app.buttons["add-pro-button"]
  }

  var conTextField: XCUIElement {
    app.textFields["con-text-field"]
  }

  var addConButton: XCUIElement {
    app.buttons["add-con-button"]
  }

  func proItem(at index: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pro'")).element(boundBy: index)
  }

  func conItem(at index: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'con'")).element(boundBy: index)
  }

  // MARK: - Basic Info Elements

  var editBasicInfoButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Edit school information'")).firstMatch
  }

  // MARK: - Phase 3 Elements (Fit Score, College Data, Map)

  var fitScoreSection: XCUIElement {
    app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Fit Score'")).firstMatch
  }

  var lookupCollegeDataButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lookup college data'")).firstMatch
  }

  var mapView: XCUIElement {
    app.maps.matching(NSPredicate(format: "label CONTAINS 'Map showing'")).firstMatch
  }

  // MARK: - Phase 4 Elements (Coaches, Quick Actions)

  var coachesSection: XCUIElement {
    app.otherElements.matching(NSPredicate(format: "label CONTAINS 'Coaches'")).firstMatch
  }

  var seeAllCoachesButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'See All'")).firstMatch
  }

  var logInteractionButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log Interaction'")).firstMatch
  }

  var sendEmailButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send Email'")).firstMatch
  }

  var editPhilosophyButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Edit' AND label CONTAINS 'Philosophy'")).firstMatch
  }

  // MARK: - Delete Elements

  var deleteSchoolButton: XCUIElement {
    app.buttons["delete-school-button"]
  }

  // MARK: - Alert Elements

  var deleteConfirmationAlert: XCUIElement {
    app.alerts["Delete School?"]
  }

  var alertDeleteButton: XCUIElement {
    app.alerts.buttons["Delete"]
  }

  var alertCancelButton: XCUIElement {
    app.alerts.buttons["Cancel"]
  }

  var alertOKButton: XCUIElement {
    app.alerts.buttons["OK"]
  }

  // MARK: - Loading & Error States

  var loadingIndicator: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading school'")).firstMatch
  }

  var errorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Error' OR label CONTAINS 'Unable'")).firstMatch
  }

  // MARK: - Helper Methods

  func waitForSchoolToLoad(timeout: TimeInterval = 10) -> Bool {
    return navigationTitle.waitForExistence(timeout: timeout) &&
           !loadingIndicator.exists
  }

  func pullToRefresh() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      let finish = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      start.press(forDuration: 0, thenDragTo: finish)
    }
  }

  func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 10) {
    var swipeCount = 0
    while !element.isHittable && swipeCount < maxSwipes {
      app.swipeUp()
      swipeCount += 1
    }
  }

  func scrollToBottom(swipes: Int = 5) {
    for _ in 0..<swipes {
      app.swipeUp()
    }
  }

  func tapFavoriteButton() {
    favoriteButton.tap()
  }

  func selectStatus(_ status: String) {
    statusPickerButton.tap()
    statusOption(status).tap()
  }

  func editNotes(_ text: String) {
    scrollToElement(notesEditButton)
    notesEditButton.tap()
    notesTextEditor.tap()
    notesTextEditor.typeText(text)
  }

  func saveNotes() {
    notesSaveButton.tap()
  }

  func cancelNotesEditing() {
    notesCancelButton.tap()
  }

  func editPrivateNotes(_ text: String) {
    scrollToElement(privateNotesEditButton)
    privateNotesEditButton.tap()
    privateNotesTextEditor.tap()
    privateNotesTextEditor.typeText(text)
  }

  func savePrivateNotes() {
    privateNotesSaveButton.tap()
  }

  func cancelPrivateNotesEditing() {
    privateNotesCancelButton.tap()
  }

  func addPro(_ text: String) {
    scrollToElement(proTextField)
    proTextField.tap()
    proTextField.typeText(text)
    addProButton.tap()
  }

  func addCon(_ text: String) {
    scrollToElement(conTextField)
    conTextField.tap()
    conTextField.typeText(text)
    addConButton.tap()
  }

  func deleteSchool() {
    scrollToBottom()
    deleteSchoolButton.tap()
  }

  func confirmDelete() {
    alertDeleteButton.tap()
  }

  func cancelDelete() {
    alertCancelButton.tap()
  }

  // MARK: - Navigation Helpers

  func navigateToSchoolDetailFromList(schoolName: String) {
    // Assumes we're on Schools List
    let schoolCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", schoolName)).firstMatch
    schoolCard.tap()
    _ = waitForSchoolToLoad()
  }

  func tapBackButton() {
    backButton.tap()
  }
}
