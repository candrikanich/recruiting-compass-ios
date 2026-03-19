import XCTest

/// Page Object Model for the Add Interaction screen
/// Provides helper methods for UI test interactions
final class AddInteractionScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars.element(matching: .navigationBar, identifier: "Add Interaction")
  }

  var cancelButton: XCUIElement {
    app.navigationBars.buttons["Cancel"]
  }

  // MARK: - Form Fields

  var schoolPicker: XCUIElement {
    app.buttons["School picker"]
  }

  var coachPicker: XCUIElement {
    app.buttons["Coach picker"]
  }

  var interactionTypePicker: XCUIElement {
    app.buttons["Interaction type picker"]
  }

  var directionPicker: XCUIElement {
    app.pickers["Direction picker"]
  }

  var dateTimePicker: XCUIElement {
    app.datePickers["Date and time picker"]
  }

  var subjectField: XCUIElement {
    app.textFields["Subject field"]
  }

  var contentEditor: XCUIElement {
    app.textViews["Content field"]
  }

  var sentimentPicker: XCUIElement {
    app.pickers["Sentiment picker"]
  }

  // MARK: - Interest Calibration

  var interestCalibrationSection: XCUIElement {
    app.staticTexts["Interest Calibration"]
  }

  func interestCalibrationToggle(forQuestion index: Int) -> XCUIElement {
    // Toggles are ordered, access by index
    app.switches.element(boundBy: index)
  }

  var interestLevelResult: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'High' OR label CONTAINS 'Moderate' OR label CONTAINS 'Low'")).firstMatch
  }

  // MARK: - Submit Button

  var submitButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log'")).firstMatch
  }

  // MARK: - Sheets

  var addCoachSheet: XCUIElement {
    app.navigationBars["Add New Coach"]
  }

  var otherCoachSheet: XCUIElement {
    app.navigationBars["Other Coach"]
  }

  var firstNameField: XCUIElement {
    app.textFields["First name field"]
  }

  var lastNameField: XCUIElement {
    app.textFields["Last name field"]
  }

  var coachRolePicker: XCUIElement {
    app.pickers["Coach role picker"]
  }

  var saveCoachButton: XCUIElement {
    app.buttons["Save Coach"]
  }

  var coachNameField: XCUIElement {
    app.textFields["Coach name field"]
  }

  var continueButton: XCUIElement {
    app.buttons["Continue"]
  }

  // MARK: - Character Count Labels

  var subjectCharCount: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/500'")).firstMatch
  }

  var contentCharCount: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/10,000'")).firstMatch
  }

  // MARK: - Error Messages

  var errorAlert: XCUIElement {
    app.alerts["Error"]
  }

  var errorMessage: XCUIElement {
    errorAlert.staticTexts.element(boundBy: 1)
  }

  // MARK: - Helper Methods

  func navigateToAddInteractionFromDashboard() {
    // Navigate to Interactions tab
    let interactionsTab = app.tabBars.buttons["Interactions"]
    if interactionsTab.waitForExistence(timeout: 5) {
      interactionsTab.tap()
    }

    // Tap + button to add interaction
    let addButton = app.navigationBars.buttons["Add new interaction"]
    if addButton.waitForExistence(timeout: 5) {
      addButton.tap()
    }
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func selectSchool(_ schoolName: String) {
    schoolPicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: schoolName)
  }

  func selectCoach(_ coachName: String) {
    coachPicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: coachName)
  }

  func selectInteractionType(_ typeName: String) {
    interactionTypePicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: typeName)
  }

  func selectDirection(_ direction: String) {
    // Direction uses segmented control
    let segment = app.buttons[direction]
    if segment.exists {
      segment.tap()
    }
  }

  func selectSentiment(_ sentimentName: String) {
    sentimentPicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: sentimentName)
  }

  func fillSubject(_ text: String) {
    subjectField.tap()
    subjectField.typeText(text)
  }

  func fillContent(_ text: String) {
    contentEditor.tap()
    contentEditor.typeText(text)
  }

  func selectOtherCoach() {
    coachPicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: "Other coach (not listed)")
  }

  func selectAddNewCoach() {
    coachPicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: "+ Add new coach")
  }

  func fillNewCoachForm(firstName: String, lastName: String, role: String) {
    firstNameField.tap()
    firstNameField.typeText(firstName)

    lastNameField.tap()
    lastNameField.typeText(lastName)

    coachRolePicker.tap()
    app.pickerWheels.element.adjust(toPickerWheelValue: role)

    saveCoachButton.tap()
  }

  func fillOtherCoachName(_ name: String) {
    coachNameField.tap()
    coachNameField.typeText(name)
    continueButton.tap()
  }

  func answerInterestCalibrationQuestion(at index: Int, answer: Bool) {
    let toggle = interestCalibrationToggle(forQuestion: index)
    if toggle.exists {
      let currentValue = (toggle.value as? String) == "1"
      if currentValue != answer {
        toggle.tap()
      }
    }
  }

  func submitForm() {
    submitButton.tap()
  }

  func tapCancel() {
    cancelButton.tap()
  }

  func dismissKeyboard() {
    app.tap()
  }

  func waitForSubmissionToComplete(timeout: TimeInterval = 15) -> Bool {
    // Wait for navigation away from Add Interaction screen
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: navigationTitle)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }

  func verifySubmitButtonEnabled() -> Bool {
    submitButton.isEnabled
  }

  func verifyInterestCalibrationVisible() -> Bool {
    interestCalibrationSection.exists
  }

  func verifyInterestCalibrationNotVisible() -> Bool {
    !interestCalibrationSection.exists
  }
}
