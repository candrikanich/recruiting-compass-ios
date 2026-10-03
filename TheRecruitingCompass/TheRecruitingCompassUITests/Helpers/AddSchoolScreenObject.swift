import XCTest

final class AddSchoolScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation Elements

  var navigationTitle: XCUIElement {
    app.navigationBars["Add School"]
  }

  var backButton: XCUIElement {
    app.navigationBars.buttons["Back to schools list"]
  }

  var cancelButton: XCUIElement {
    app.buttons["Cancel adding school"]
  }

  // MARK: - Toggle Elements

  var autocompleteToggle: XCUIElement {
    app.switches["Search college database"]
  }

  // MARK: - Autocomplete Elements

  var autocompleteSearchField: XCUIElement {
    app.textFields["College search"]
  }

  var autocompleteDropdown: XCUIElement {
    app.otherElements["autocomplete-dropdown"]
  }

  func autocompleteResult(at index: Int) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'autocomplete-result'")).element(boundBy: index)
  }

  var noResultsMessage: XCUIElement {
    app.staticTexts["No colleges found"]
  }

  var searchingIndicator: XCUIElement {
    app.staticTexts["Searching..."]
  }

  // MARK: - Selected College Card Elements

  var selectedCollegeCard: XCUIElement {
    app.otherElements["selected-college-card"]
  }

  var selectedCollegeName: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Selected:'")).firstMatch
  }

  var clearSelectionButton: XCUIElement {
    app.buttons["Clear"]
  }

  var enrichmentLoadingIndicator: XCUIElement {
    app.staticTexts["Fetching college data..."]
  }

  var enrichmentSuccessMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'College data and map coordinates loaded'")).firstMatch
  }

  // MARK: - Form Field Elements

  // FormFieldWrapper merges its title into one "Other" element ("School Name, required",
  // "City", ...); the input inside it carries no label of its own.
  var nameTextField: XCUIElement {
    fieldInput("School Name, required")
  }

  /// The form no longer has a single Location field; City replaced it.
  var locationTextField: XCUIElement {
    fieldInput("City")
  }

  var divisionPicker: XCUIElement {
    app.pickers["Division"]
  }

  var conferenceTextField: XCUIElement {
    fieldInput("Conference")
  }

  var websiteTextField: XCUIElement {
    fieldInput("Website")
  }

  var twitterHandleTextField: XCUIElement {
    fieldInput("Twitter Handle")
  }

  var instagramHandleTextField: XCUIElement {
    fieldInput("Instagram Handle")
  }

  var notesTextView: XCUIElement {
    app.otherElements["Notes"].textViews.firstMatch
  }

  private func fieldInput(_ fieldTitle: String) -> XCUIElement {
    app.otherElements[fieldTitle].textFields.firstMatch
  }

  var statusPicker: XCUIElement {
    app.pickers["Status"]
  }

  // MARK: - Auto-Filled Badge Elements

  func autoFilledBadge(for field: String) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(field)' AND label CONTAINS 'auto-filled'")).firstMatch
  }

  // MARK: - College Scorecard Section Elements

  var scorecardSection: XCUIElement {
    app.otherElements["college-scorecard-section"]
  }

  var studentSizeLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Student Size'")).firstMatch
  }

  var admissionRateLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Admission Rate'")).firstMatch
  }

  var tuitionInStateLabel: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Tuition (In-State)'")).firstMatch
  }

  // MARK: - Action Button Elements

  var addSchoolButton: XCUIElement {
    app.buttons["Add School"]
  }

  var addingButton: XCUIElement {
    app.buttons["Adding..."]
  }

  // MARK: - Validation Error Elements

  func fieldError(for field: String) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(field)' AND (label CONTAINS 'required' OR label CONTAINS 'invalid' OR label CONTAINS 'must')")).firstMatch
  }

  var errorSummaryBanner: XCUIElement {
    app.otherElements["error-summary-banner"]
  }

  // MARK: - Duplicate Dialog Elements

  var duplicateDialog: XCUIElement {
    app.alerts["Duplicate School Detected"]
  }

  var duplicateDialogMessage: XCUIElement {
    app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS 'already exists'")).firstMatch
  }

  var duplicateMatchTypeBadge: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Match' OR label CONTAINS 'Name Match' OR label CONTAINS 'Website Domain' OR label CONTAINS 'NCAA ID'")).firstMatch
  }

  var duplicateDialogCancelButton: XCUIElement {
    app.alerts.buttons["Cancel"]
  }

  var duplicateDialogProceedButton: XCUIElement {
    app.alerts.buttons["Proceed Anyway"]
  }

  // MARK: - Loading & Error State Elements

  var loadingIndicator: XCUIElement {
    app.activityIndicators.firstMatch
  }

  var errorAlert: XCUIElement {
    app.alerts.firstMatch
  }

  var errorMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Error' OR label CONTAINS 'Failed' OR label CONTAINS 'Unable'")).firstMatch
  }

  // MARK: - Helper Methods - Navigation

  /// Dashboard -> Schools tab -> "+" -> Add School. Fails the test at the step that
  /// didn't happen instead of continuing on the wrong screen.
  @discardableResult
  func navigateToAddSchoolFromDashboard(file: StaticString = #filePath, line: UInt = #line) -> Bool {
    guard MainTabNavigator(app: app).goTo(.schools),
          app.navigationBars["Schools"].waitForExistence(timeout: 10) else {
      XCTFail("Schools list did not open from the tab bar", file: file, line: line)
      return false
    }

    let addButton = app.navigationBars.buttons["Add new school"]
    guard addButton.waitForExistence(timeout: 10) else {
      XCTFail("\"Add new school\" toolbar button not found on Schools list", file: file, line: line)
      return false
    }
    addButton.tap()

    guard waitForScreenToLoad() else {
      XCTFail("Add School screen did not open after tapping \"Add new school\"", file: file, line: line)
      return false
    }
    return true
  }

  func waitForScreenToLoad(timeout: TimeInterval = 10) -> Bool {
    return navigationTitle.waitForExistence(timeout: timeout)
  }

  func tapBackButton() {
    backButton.tap()
  }

  func tapCancelButton() {
    cancelButton.tap()
  }

  // MARK: - Helper Methods - Autocomplete Mode

  func toggleAutocomplete(enabled: Bool) {
    if autocompleteToggle.value as? String == (enabled ? "0" : "1") {
      autocompleteToggle.tap()
    }
  }

  func searchCollege(query: String) {
    autocompleteSearchField.tap()
    autocompleteSearchField.typeText(query)
  }

  func selectAutocompleteResult(at index: Int = 0) {
    let result = autocompleteResult(at: index)
    if result.waitForExistence(timeout: 5) {
      result.tap()
    }
  }

  func clearSelection() {
    if clearSelectionButton.exists {
      clearSelectionButton.tap()
    }
  }

  func waitForEnrichmentToComplete(timeout: TimeInterval = 10) -> Bool {
    // Wait for loading indicator to appear
    _ = enrichmentLoadingIndicator.waitForExistence(timeout: 2)

    // Wait for loading to disappear
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: enrichmentLoadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

    return result == .completed
  }

  // MARK: - Helper Methods - Manual Entry

  func fillSchoolName(_ name: String) {
    nameTextField.tap()
    nameTextField.typeText(name)
  }

  func fillLocation(_ location: String) {
    locationTextField.tap()
    locationTextField.typeText(location)
  }

  func selectDivision(_ division: String) {
    divisionPicker.tap()
    if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
      app.pickerWheels.firstMatch.adjust(toPickerWheelValue: division)
      if app.toolbars.buttons["Done"].exists {
        app.toolbars.buttons["Done"].tap()
      } else {
        app.tap()
      }
    }
  }

  func fillConference(_ conference: String) {
    conferenceTextField.tap()
    conferenceTextField.typeText(conference)
  }

  func fillWebsite(_ url: String) {
    websiteTextField.tap()
    websiteTextField.typeText(url)
  }

  func fillTwitterHandle(_ handle: String) {
    scrollToElement(twitterHandleTextField)
    twitterHandleTextField.tap()
    twitterHandleTextField.typeText(handle)
  }

  func fillInstagramHandle(_ handle: String) {
    scrollToElement(instagramHandleTextField)
    instagramHandleTextField.tap()
    instagramHandleTextField.typeText(handle)
  }

  func fillNotes(_ notes: String) {
    scrollToElement(notesTextView)
    notesTextView.tap()
    notesTextView.typeText(notes)
  }

  func selectStatus(_ status: String) {
    scrollToElement(statusPicker)
    statusPicker.tap()
    if app.pickerWheels.firstMatch.waitForExistence(timeout: 2) {
      app.pickerWheels.firstMatch.adjust(toPickerWheelValue: status)
      if app.toolbars.buttons["Done"].exists {
        app.toolbars.buttons["Done"].tap()
      } else {
        app.tap()
      }
    }
  }

  // MARK: - Helper Methods - Form Submission

  func submitForm() {
    scrollToElement(addSchoolButton)
    addSchoolButton.tap()
  }

  func waitForSubmissionToComplete(timeout: TimeInterval = 10) -> Bool {
    // Wait for "Adding..." button to appear and disappear
    if addingButton.waitForExistence(timeout: 2) {
      let predicate = NSPredicate(format: "exists == false")
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addingButton)
      let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
      return result == .completed
    }
    return true
  }

  // MARK: - Helper Methods - Duplicate Dialog

  func waitForDuplicateDialog(timeout: TimeInterval = 5) -> Bool {
    return duplicateDialog.waitForExistence(timeout: timeout)
  }

  func cancelDuplicateDialog() {
    duplicateDialogCancelButton.tap()
  }

  func proceedWithDuplicate() {
    duplicateDialogProceedButton.tap()
  }

  // MARK: - Helper Methods - Validation

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

  // MARK: - Helper Methods - Assertions

  func verifyAutoFilledBadgesExist(for fields: [String]) -> Bool {
    for field in fields {
      if !autoFilledBadge(for: field).exists {
        return false
      }
    }
    return true
  }

  func verifyFieldHasValue(_ field: XCUIElement, expectedValue: String? = nil) -> Bool {
    guard field.exists else { return false }

    if let expected = expectedValue {
      if let value = field.value as? String {
        return value.contains(expected)
      }
      return false
    }

    return true
  }

  func verifyScorecardSectionVisible() -> Bool {
    return scorecardSection.exists && scorecardSection.isHittable
  }
}
