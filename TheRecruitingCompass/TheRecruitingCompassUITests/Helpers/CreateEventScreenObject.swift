import XCTest

final class CreateEventScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Add New Event"]
  }

  var cancelButton: XCUIElement {
    app.buttons["cancel-button"]
  }

  // MARK: - Form Container

  var formContainer: XCUIElement {
    app.otherElements["create-event-form"]
  }

  // MARK: - Event Info Section

  var eventTypePicker: XCUIElement {
    app.otherElements["event-type-picker"]
  }

  var eventNameField: XCUIElement {
    app.textFields["event-name-field"]
  }

  var schoolPicker: XCUIElement {
    app.otherElements["school-picker"]
  }

  // MARK: - Date & Time Section

  var startDatePicker: XCUIElement {
    app.otherElements["start-date-picker"]
  }

  var endDatePicker: XCUIElement {
    app.otherElements["end-date-picker"]
  }

  var startTimePicker: XCUIElement {
    app.otherElements["start-time-picker"]
  }

  var endTimePicker: XCUIElement {
    app.otherElements["end-time-picker"]
  }

  // MARK: - Location Section

  var addressField: XCUIElement {
    app.textFields["Street Address"]
  }

  var cityField: XCUIElement {
    app.textFields["City"]
  }

  var stateField: XCUIElement {
    app.textFields["State"]
  }

  var getDirectionsButton: XCUIElement {
    app.buttons["get-directions-button"]
  }

  // MARK: - Action Buttons

  var createEventButton: XCUIElement {
    app.buttons["create-event-button"]
  }

  var creatingButton: XCUIElement {
    app.buttons["Creating..."]
  }

  // MARK: - Validation Elements

  var validationErrorBanner: XCUIElement {
    app.otherElements["validation-error-banner"]
  }

  func validationError(containing text: String) -> XCUIElement {
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[cd] %@", text)
    ).firstMatch
  }

  // MARK: - Modal Elements

  var otherSchoolModal: XCUIElement {
    app.otherElements["other-school-modal"]
  }

  var addSchoolModal: XCUIElement {
    app.otherElements["add-school-modal"]
  }

  var saveSchoolButton: XCUIElement {
    app.buttons["save-school-button"]
  }

  // MARK: - Discard Changes Dialog

  var discardChangesDialog: XCUIElement {
    app.alerts["Discard changes?"]
  }

  var discardButton: XCUIElement {
    app.alerts.buttons["Discard"]
  }

  var keepEditingButton: XCUIElement {
    app.alerts.buttons["Keep Editing"]
  }

  // MARK: - Error Alert

  var errorAlert: XCUIElement {
    app.alerts.firstMatch
  }

  // MARK: - Helper Methods - Navigation

  func navigateToCreateEvent() {
    let dashboard = app.navigationBars["Dashboard"]
    _ = dashboard.waitForExistence(timeout: 10)

    if app.tabBars.buttons["Events"].exists {
      app.tabBars.buttons["Events"].tap()
    }

    let eventsList = app.navigationBars["Events"]
    _ = eventsList.waitForExistence(timeout: 5)

    let addButton = app.navigationBars.buttons["Add new event"]
    if addButton.waitForExistence(timeout: 5) {
      addButton.tap()
    }

    _ = navigationTitle.waitForExistence(timeout: 5)
  }

  func waitForScreenToLoad(timeout: TimeInterval = 10) -> Bool {
    return navigationTitle.waitForExistence(timeout: timeout)
  }

  // MARK: - Helper Methods - Form Input

  func selectEventType(_ type: String) {
    eventTypePicker.tap()
    if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
      app.pickerWheels.firstMatch.adjust(toPickerWheelValue: type)
      if app.toolbars.buttons["Done"].exists {
        app.toolbars.buttons["Done"].tap()
      } else {
        app.tap()
      }
    }
  }

  func fillEventName(_ name: String) {
    eventNameField.tap()
    eventNameField.typeText(name)
  }

  func selectSchoolOption(_ option: String) {
    schoolPicker.tap()
    if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
      app.pickerWheels.firstMatch.adjust(toPickerWheelValue: option)
      if app.toolbars.buttons["Done"].exists {
        app.toolbars.buttons["Done"].tap()
      } else {
        app.tap()
      }
    }
  }

  func fillAddress(_ address: String) {
    scrollToElement(addressField)
    addressField.tap()
    addressField.typeText(address)
  }

  func fillCity(_ city: String) {
    scrollToElement(cityField)
    cityField.tap()
    cityField.typeText(city)
  }

  func fillState(_ state: String) {
    scrollToElement(stateField)
    stateField.tap()
    stateField.typeText(state)
  }

  // MARK: - Helper Methods - Submission

  func submitForm() {
    scrollToElement(createEventButton)
    createEventButton.tap()
  }

  func waitForSubmissionToComplete(timeout: TimeInterval = 10) -> Bool {
    if creatingButton.waitForExistence(timeout: 2) {
      let predicate = NSPredicate(format: "exists == false")
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: creatingButton)
      let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
      return result == .completed
    }
    return true
  }

  // MARK: - Helper Methods - Keyboard & Scroll

  func dismissKeyboard() {
    if app.keyboards.firstMatch.exists {
      app.tap()
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
}
