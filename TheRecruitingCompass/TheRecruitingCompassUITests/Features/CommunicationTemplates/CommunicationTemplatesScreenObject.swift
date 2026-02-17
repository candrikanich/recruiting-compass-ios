import XCTest

/// Page Object for the Communication Templates screen.
final class CommunicationTemplatesScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Navigation

  var navigationTitle: XCUIElement {
    app.navigationBars["Communication Templates"]
  }

  var settingsTab: XCUIElement {
    app.tabBars.buttons["Settings"]
  }

  var communicationTemplatesLink: XCUIElement {
    app.staticTexts["Communication Templates"]
  }

  // MARK: - Tabs

  var myTemplatesTab: XCUIElement {
    app.buttons["communicationTemplates.myTemplatesTab"]
  }

  var createTab: XCUIElement {
    app.buttons["communicationTemplates.createTab"]
  }

  // MARK: - List

  var templatesList: XCUIElement {
    app.scrollViews["communicationTemplates.list"]
  }

  // MARK: - Filter Pills

  var filterAll: XCUIElement {
    app.buttons["typeFilter.all"]
  }

  var filterEmail: XCUIElement {
    app.buttons["typeFilter.email"]
  }

  var filterText: XCUIElement {
    app.buttons["typeFilter.text"]
  }

  var filterTwitter: XCUIElement {
    app.buttons["typeFilter.twitter"]
  }

  // MARK: - Editor

  var editorView: XCUIElement {
    app.scrollViews["templateEditorView"]
  }

  var nameField: XCUIElement {
    app.textFields["templateEditor.nameField"]
  }

  var typePicker: XCUIElement {
    app.segmentedControls["templateEditor.typePicker"]
  }

  var bodyEditor: XCUIElement {
    app.textViews["templateEditor.bodyEditor"]
  }

  var saveButton: XCUIElement {
    app.buttons["templateEditor.saveButton"]
  }

  var cancelButton: XCUIElement {
    app.buttons["templateEditor.cancelButton"]
  }

  var deleteButton: XCUIElement {
    app.buttons["templateEditor.deleteButton"]
  }

  // MARK: - Empty State

  var emptyStateElement: XCUIElement {
    app.staticTexts["No templates yet"]
  }

  var createTemplateAction: XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "label CONTAINS 'Create Template' OR label CONTAINS 'Create your first template'"
    )).firstMatch
  }

  // MARK: - Delete Confirmation

  var deleteConfirmationAlert: XCUIElement {
    app.alerts["Delete Template"]
  }

  var deleteConfirmButton: XCUIElement {
    app.alerts.buttons["Delete"]
  }

  var deleteCancelButton: XCUIElement {
    app.alerts.buttons["Cancel"]
  }

  // MARK: - Template Cards

  var allTemplateCards: XCUIElementQuery {
    app.otherElements.matching(NSPredicate(
      format: "identifier BEGINSWITH 'templateCard.'"
    ))
  }

  func editButtonForTemplate(named name: String) -> XCUIElement {
    app.buttons["Edit \(name)"]
  }

  // MARK: - Navigation Actions

  func navigateToTemplates() -> Bool {
    guard settingsTab.waitForExistence(timeout: 5) else { return false }
    settingsTab.tap()

    guard communicationTemplatesLink.waitForExistence(timeout: 5) else { return false }
    communicationTemplatesLink.tap()

    return waitForScreenToLoad()
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    let hasCards = allTemplateCards.firstMatch.waitForExistence(timeout: 10)
    if hasCards { return true }

    let hasEmpty = emptyStateElement.waitForExistence(timeout: 5)
    if hasEmpty { return true }

    return filterAll.waitForExistence(timeout: 3)
  }

  // MARK: - Scroll Helpers

  func scrollDown() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeUp()
    }
  }

  func scrollUp() {
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
      scrollView.swipeDown()
    }
  }
}
