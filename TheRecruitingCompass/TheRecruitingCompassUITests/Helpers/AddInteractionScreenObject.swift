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
    app.navigationBars["Log Interaction"]
  }

  var cancelButton: XCUIElement {
    app.navigationBars.buttons["Cancel and return to school details"]
  }

  // MARK: - Form Fields

  // Form pickers use the menu style, which XCUITest reports as Button or PopUpButton
  // depending on the Xcode version — match either.
  var schoolPicker: XCUIElement {
    menuPicker("School picker")
  }

  var coachPicker: XCUIElement {
    menuPicker("Coach picker")
  }

  var interactionTypePicker: XCUIElement {
    menuPicker("Interaction type picker")
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
    menuPicker("Sentiment picker")
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
    app.buttons["Log Interaction"]
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

  /// Dashboard -> Interactions tab -> "+" -> Log Interaction. Fails the test at the step
  /// that didn't happen instead of continuing on the wrong screen.
  @discardableResult
  func navigateToAddInteractionFromDashboard(file: StaticString = #filePath, line: UInt = #line) -> Bool {
    guard MainTabNavigator(app: app).goTo(.interactions),
          interactionsListNavigationBar.waitForExistence(timeout: 10) else {
      XCTFail("Interactions list did not open from the tab bar", file: file, line: line)
      return false
    }

    let addButton = app.navigationBars.buttons["Log new interaction"]
    guard addButton.waitForExistence(timeout: 10) else {
      XCTFail("\"Log new interaction\" toolbar button not found", file: file, line: line)
      return false
    }
    addButton.tap()

    // The form shows a loading row until schools are fetched; the school picker marks it ready.
    guard waitForScreenToLoad(), schoolPicker.waitForExistence(timeout: 15) else {
      XCTFail("Log Interaction form did not open and load", file: file, line: line)
      return false
    }
    return true
  }

  /// Parents see "Interactions"; athletes see "My Interactions".
  var interactionsListNavigationBar: XCUIElement {
    app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH 'Interactions'")).firstMatch
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func selectSchool(_ schoolName: String, file: StaticString = #filePath, line: UInt = #line) {
    selectMenuOption(schoolName, in: schoolPicker, file: file, line: line)
  }

  func selectCoach(_ coachName: String, file: StaticString = #filePath, line: UInt = #line) {
    selectMenuOption(coachName, in: coachPicker, file: file, line: line)
  }

  func selectInteractionType(_ typeName: String, file: StaticString = #filePath, line: UInt = #line) {
    selectMenuOption(typeName, in: interactionTypePicker, file: file, line: line)
  }

  /// Direction is a segmented control whose segments carry a title plus a subtitle.
  func selectDirection(_ direction: String, file: StaticString = #filePath, line: UInt = #line) {
    let segment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", direction)).firstMatch
    guard segment.waitForExistence(timeout: 5) else {
      XCTFail("Direction segment \"\(direction)\" not found", file: file, line: line)
      return
    }
    segment.tap()
  }

  func selectSentiment(_ sentimentName: String, file: StaticString = #filePath, line: UInt = #line) {
    selectMenuOption(sentimentName, in: sentimentPicker, file: file, line: line)
  }

  /// Scrolls the form until `element` can be tapped (the submit button sits below the fold).
  func scrollToElement(_ element: XCUIElement, up: Bool = false, maxSwipes: Int = 8) {
    var swipes = 0
    while !element.isHittable && swipes < maxSwipes {
      if up { app.swipeDown() } else { app.swipeUp() }
      swipes += 1
    }
  }

  private func menuPicker(_ label: String) -> XCUIElement {
    let types = [XCUIElement.ElementType.button, .popUpButton].map { NSNumber(value: $0.rawValue) }
    return app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@ AND elementType IN %@", label, types))
      .firstMatch
  }

  private func selectMenuOption(
    _ option: String,
    in picker: XCUIElement,
    file: StaticString,
    line: UInt
  ) {
    guard picker.waitForExistence(timeout: 10) else {
      XCTFail("Picker \(picker) not found", file: file, line: line)
      return
    }
    picker.tap()
    let item = app.buttons[option].firstMatch
    guard item.waitForExistence(timeout: 5) else {
      XCTFail("Menu option \"\(option)\" did not appear after opening \(picker)", file: file, line: line)
      return
    }
    item.tap()
    _ = item.waitForNonExistence(timeout: 3)
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
    selectCoach("Other coach (not listed)")
  }

  func selectAddNewCoach() {
    selectCoach("+ Add new coach")
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
