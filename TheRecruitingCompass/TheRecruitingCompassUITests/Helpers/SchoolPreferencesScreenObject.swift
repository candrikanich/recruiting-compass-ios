import XCTest

/// Page Object Model for School Preferences page
final class SchoolPreferencesScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["School Preferences"]
  }

  var saveButton: XCUIElement {
    app.buttons["Save"]
  }

  var editButton: XCUIElement {
    app.buttons["Edit"]
  }

  var doneButton: XCUIElement {
    app.buttons["Done"]
  }

  // MARK: - Quick Templates

  func templateCard(_ name: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
  }

  var d1PowerConferenceTemplate: XCUIElement {
    templateCard("D1 Power Conference")
  }

  var academicExcellenceTemplate: XCUIElement {
    templateCard("Academic Excellence")
  }

  var closeToHomeTemplate: XCUIElement {
    templateCard("Close to Home")
  }

  var bestFitTemplate: XCUIElement {
    templateCard("Best Fit")
  }

  // MARK: - Template Warning Alert

  var templateWarningAlert: XCUIElement {
    app.alerts["Replace Existing Preferences?"]
  }

  var replaceButton: XCUIElement {
    templateWarningAlert.buttons["Replace"]
  }

  var cancelButton: XCUIElement {
    templateWarningAlert.buttons["Cancel"]
  }

  // MARK: - Preferences List

  var emptyPreferencesMessage: XCUIElement {
    app.staticTexts["No preferences set. Apply a template or add your own."]
  }

  func preferenceRow(_ index: Int) -> XCUIElement {
    app.tables.cells.element(boundBy: index)
  }

  func deleteButton(forPreference index: Int) -> XCUIElement {
    preferenceRow(index).buttons.matching(identifier: "Delete").firstMatch
  }

  // MARK: - Add Preference

  var addCustomPreferenceButton: XCUIElement {
    app.buttons["Add Custom Preference"]
  }

  // MARK: - States

  var loadingIndicator: XCUIElement {
    app.staticTexts["Loading preferences..."]
  }

  var errorAlert: XCUIElement {
    app.alerts["Error"]
  }

  var successMessage: XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved'")).firstMatch
  }

  // MARK: - Helper Methods

  func waitForScreenToLoad() -> Bool {
    return navigationTitle.waitForExistence(timeout: 10)
  }

  func applyTemplate(_ templateName: String) {
    let template = templateCard(templateName)
    if template.waitForExistence(timeout: 5) {
      template.tap()
    }
  }

  func confirmTemplateReplacement() {
    if templateWarningAlert.waitForExistence(timeout: 5) {
      replaceButton.tap()
    }
  }

  func cancelTemplateReplacement() {
    if templateWarningAlert.waitForExistence(timeout: 5) {
      cancelButton.tap()
    }
  }

  func tapAddCustomPreference() {
    if addCustomPreferenceButton.exists {
      addCustomPreferenceButton.tap()
    }
  }

  func getPreferenceCount() -> Int {
    return app.tables.cells.count
  }

  func dragPreference(from sourceIndex: Int, to destinationIndex: Int) {
    let sourceCell = preferenceRow(sourceIndex)
    let destinationCell = preferenceRow(destinationIndex)

    if sourceCell.exists && destinationCell.exists {
      sourceCell.press(forDuration: 1.0, thenDragTo: destinationCell)
    }
  }

  func tapSave() {
    if saveButton.exists && saveButton.isEnabled {
      saveButton.tap()
    }
  }

  func waitForSaveToComplete(timeout: TimeInterval = 10) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
    let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
    return result == .completed
  }
}
