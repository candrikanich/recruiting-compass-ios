import XCTest

/// Page Object for the Tasks List screen (Phase 5 Tasks/Timeline).
final class TasksListScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  var tasksListView: XCUIElement {
    app.otherElements["tasks_list_view"]
  }

  var navigationTitle: XCUIElement {
    app.navigationBars["Tasks"]
  }

  var emptyStateMessage: XCUIElement {
    app.staticTexts["No tasks available for this grade level"]
  }

  var statusFilter: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Filter by status'")).firstMatch
  }

  var urgencyFilter: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Filter by urgency'")).firstMatch
  }

  func progressCard(containing completed: Int, total: Int) -> XCUIElement {
    app.otherElements.matching(NSPredicate(
      format: "label CONTAINS 'Completed \(completed) of \(total) tasks'"
    )).firstMatch
  }

  func navigateToTasks() -> Bool {
    let tasksTab = app.tabBars.buttons["Tasks"]
    if tasksTab.waitForExistence(timeout: 5) {
      tasksTab.tap()
      return waitForScreenToLoad()
    }
    return false
  }

  func waitForScreenToLoad() -> Bool {
    navigationTitle.waitForExistence(timeout: 10) || tasksListView.waitForExistence(timeout: 10)
  }

  func waitForContentToLoad() -> Bool {
    emptyStateMessage.waitForExistence(timeout: 15) || progressCard(containing: 0, total: 1).waitForExistence(timeout: 5)
  }
}
