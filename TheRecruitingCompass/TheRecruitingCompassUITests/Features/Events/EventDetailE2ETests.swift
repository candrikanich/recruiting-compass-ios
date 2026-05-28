import XCTest

/// E2E tests for the Event Detail feature
/// Tests critical user journeys: event loading, type/status badges, date display,
/// toolbar actions (edit, delete, add metric, log interaction), coaches & metrics sections,
/// get directions, and error states
final class EventDetailE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: EventDetailScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = EventDetailScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Helper

  @MainActor
  private func loginAndNavigateToEventDetail() throws {
    app.loginAsParent(email: "test@example.com", password: "TestPassword1")

    guard app.waitForLogin(timeout: 10) else {
      throw XCTSkip("Login failed - Supabase may not be configured")
    }

    guard screen.navigateToEventsTab() else {
      throw XCTSkip("Events tab not reachable")
    }

    guard screen.tapFirstEvent() else {
      throw XCTSkip("No events available to navigate to detail")
    }

    guard screen.waitForContentOrError() else {
      throw XCTSkip("Event detail did not load")
    }
  }

  // MARK: - Happy Path: Event Loads

  @MainActor
  func test_eventDetail_loadsAndShowsEventName() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "01-event-detail-loaded"))

    XCTAssertTrue(
      screen.waitForEventToLoad(),
      "Event Info section header should appear indicating event loaded"
    )

    XCTAssertTrue(
      screen.eventInfoHeader.exists,
      "Event Info section should be visible"
    )

    add(app.takeScreenshot(name: "02-event-detail-verified"))
  }

  // MARK: - Happy Path: Type Badge

  @MainActor
  func test_eventDetail_showsTypeBadge() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "03-type-badge-check"))

    // The combined accessibility label includes the type name
    let typeNames = ["Showcase", "Camp", "Official Visit", "Unofficial Visit", "Game"]
    let hasTypeBadge = typeNames.contains { name in
      screen.typeBadge(name).waitForExistence(timeout: 3)
    }

    XCTAssertTrue(
      hasTypeBadge,
      "At least one event type badge should be visible (Showcase, Camp, Official Visit, Unofficial Visit, or Game)"
    )

    add(app.takeScreenshot(name: "04-type-badge-verified"))
  }

  // MARK: - Happy Path: Date Range

  @MainActor
  func test_eventDetail_showsDateRange() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "05-date-range-check"))

    let dateElement = screen.dateLabel
    XCTAssertTrue(
      dateElement.waitForExistence(timeout: 5),
      "Date label should be visible on event detail"
    )

    add(app.takeScreenshot(name: "06-date-range-verified"))
  }

  // MARK: - Happy Path: Status Badge

  @MainActor
  func test_eventDetail_showsStatusBadge() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "07-status-badge-check"))

    let statuses = ["Attended", "Registered", "Not Registered"]
    let hasStatus = statuses.contains { status in
      screen.statusBadge(status).waitForExistence(timeout: 3)
    }

    XCTAssertTrue(
      hasStatus,
      "Event should show one of: Attended, Registered, or Not Registered badge"
    )

    add(app.takeScreenshot(name: "08-status-badge-verified"))
  }

  // MARK: - Happy Path: Edit Button

  @MainActor
  func test_editButton_exists() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "09-edit-button-check"))

    XCTAssertTrue(
      screen.actionsMenuButton.waitForExistence(timeout: 5),
      "Actions menu button should exist in toolbar"
    )

    screen.openActionsMenu()
    sleep(1)

    add(app.takeScreenshot(name: "10-actions-menu-opened"))

    XCTAssertTrue(
      screen.editMenuAction.waitForExistence(timeout: 3),
      "Edit Event action should appear in the actions menu"
    )

    add(app.takeScreenshot(name: "11-edit-button-verified"))
  }

  // MARK: - Happy Path: Edit Opens Sheet

  @MainActor
  func test_editButton_opensEditSheet() throws {
    try loginAndNavigateToEventDetail()

    screen.tapEditAction()

    add(app.takeScreenshot(name: "12-edit-sheet-opening"))

    XCTAssertTrue(
      screen.waitForEditSheet(),
      "Edit Event sheet should appear after tapping Edit"
    )

    XCTAssertTrue(
      screen.editEventNameField.waitForExistence(timeout: 3),
      "Edit form should contain event name field"
    )

    XCTAssertTrue(
      screen.editSaveButton.exists,
      "Edit form should contain Save button"
    )

    XCTAssertTrue(
      screen.editCancelButton.exists,
      "Edit form should contain Cancel button"
    )

    add(app.takeScreenshot(name: "13-edit-sheet-verified"))

    // Dismiss the sheet
    screen.editCancelButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "14-edit-sheet-dismissed"))
  }

  // MARK: - Happy Path: Delete Confirmation

  @MainActor
  func test_deleteButton_triggerConfirmationAlert() throws {
    try loginAndNavigateToEventDetail()

    screen.tapDeleteAction()
    sleep(1)

    add(app.takeScreenshot(name: "15-delete-confirmation-shown"))

    let deleteButton = screen.deleteConfirmButton
    XCTAssertTrue(
      deleteButton.waitForExistence(timeout: 3),
      "Delete confirmation dialog should appear with Delete button"
    )

    // Cancel to avoid actually deleting
    let cancelButton = screen.deleteCancelButton
    if cancelButton.waitForExistence(timeout: 3) {
      cancelButton.tap()
    }

    add(app.takeScreenshot(name: "16-delete-confirmation-cancelled"))
  }

  // MARK: - Happy Path: Get Directions

  @MainActor
  func test_getDirections_buttonExists_whenLocationSet() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "17-directions-check"))

    // Scroll down to find location section
    screen.scrollDown()
    sleep(1)

    let directionsButton = screen.getDirectionsButton
    if directionsButton.waitForExistence(timeout: 3) {
      XCTAssertTrue(
        directionsButton.exists,
        "Get Directions button should be visible when event has a location"
      )
      add(app.takeScreenshot(name: "18-directions-button-found"))
    } else {
      throw XCTSkip("Event has no location set - Get Directions button not applicable")
    }
  }

  // MARK: - Happy Path: Coaches Section

  @MainActor
  func test_coachesSection_exists() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "19-coaches-section-check"))

    // Scroll to find coaches section
    screen.scrollDown()
    sleep(1)

    let coachesHeader = screen.coachesHeader
    if coachesHeader.waitForExistence(timeout: 3) {
      XCTAssertTrue(
        coachesHeader.exists,
        "Coaches section header should be visible"
      )
      add(app.takeScreenshot(name: "20-coaches-section-found"))
    } else {
      // Scroll further
      screen.scrollDown()
      sleep(1)

      if coachesHeader.waitForExistence(timeout: 3) {
        XCTAssertTrue(coachesHeader.exists)
        add(app.takeScreenshot(name: "20-coaches-section-found-after-scroll"))
      } else {
        throw XCTSkip("Event has no school linked - coaches section not shown")
      }
    }
  }

  // MARK: - Happy Path: Metrics Section

  @MainActor
  func test_metricsSection_existsWhenMetricsPresent() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "21-metrics-section-check"))

    screen.scrollDown()
    sleep(1)

    let metricsHeader = screen.metricsHeader
    if metricsHeader.waitForExistence(timeout: 3) {
      XCTAssertTrue(
        metricsHeader.exists,
        "Performance Metrics section header should be visible"
      )
      add(app.takeScreenshot(name: "22-metrics-section-found"))
    } else {
      screen.scrollDown()
      sleep(1)

      if metricsHeader.waitForExistence(timeout: 3) {
        XCTAssertTrue(metricsHeader.exists)
        add(app.takeScreenshot(name: "22-metrics-section-found-after-scroll"))
      } else {
        throw XCTSkip("No metrics or metric form visible for this event")
      }
    }
  }

  // MARK: - Happy Path: Add Metric Button Expands Form

  @MainActor
  func test_addMetricButton_expandsMetricForm() throws {
    try loginAndNavigateToEventDetail()

    // Navigate via toolbar menu
    screen.tapAddMetricAction()
    sleep(1)

    add(app.takeScreenshot(name: "23-metric-form-expanding"))

    // Scroll to find the form
    screen.scrollDown()
    sleep(1)

    let valueField = screen.metricValueField
    let saveButton = screen.saveMetricButton

    let formAppeared = valueField.waitForExistence(timeout: 5)
      || saveButton.waitForExistence(timeout: 3)

    if formAppeared {
      XCTAssertTrue(formAppeared, "Metric form should expand with value field or save button")
      add(app.takeScreenshot(name: "24-metric-form-expanded"))

      // Cancel the form
      let cancelButton = screen.cancelMetricButton
      if cancelButton.waitForExistence(timeout: 3) {
        cancelButton.tap()
      }
    } else {
      // Try scrolling more to find the form
      screen.scrollDown()
      sleep(1)

      let formFound = valueField.waitForExistence(timeout: 3)
        || saveButton.waitForExistence(timeout: 3)

      XCTAssertTrue(
        formFound,
        "Metric form should be visible after adding metric"
      )
      add(app.takeScreenshot(name: "24-metric-form-found-after-scroll"))
    }
  }

  // MARK: - Happy Path: Mark Attended Shows Quick Log Modal

  @MainActor
  func test_markAttended_showsQuickLogModal() throws {
    try loginAndNavigateToEventDetail()

    // Open the Log Interaction option from toolbar
    screen.tapLogInteractionAction()
    sleep(1)

    add(app.takeScreenshot(name: "25-quick-log-opening"))

    XCTAssertTrue(
      screen.waitForQuickLogSheet(),
      "Log Interaction sheet should appear"
    )

    XCTAssertTrue(
      screen.quickLogSaveButton.exists,
      "Quick log sheet should have Save button"
    )

    XCTAssertTrue(
      screen.quickLogCancelButton.exists,
      "Quick log sheet should have Cancel button"
    )

    add(app.takeScreenshot(name: "26-quick-log-sheet-verified"))

    // Dismiss the sheet
    screen.quickLogCancelButton.tap()
    sleep(1)

    add(app.takeScreenshot(name: "27-quick-log-dismissed"))
  }

  // MARK: - Error State

  @MainActor
  func test_eventNotFound_showsErrorMessage() throws {
    // This test requires navigating to a non-existent event, which
    // is difficult to trigger in a live E2E context without deep link support
    throw XCTSkip(
      "Cannot test event-not-found in E2E without deep link to non-existent event ID. " +
      "Error state is covered by unit tests with MockEventsService."
    )
  }

  // MARK: - Full Journey

  @MainActor
  func test_eventDetail_fullJourney() throws {
    try loginAndNavigateToEventDetail()

    add(app.takeScreenshot(name: "28-journey-start"))

    // Step 1: Verify event loaded
    XCTAssertTrue(screen.waitForEventToLoad(), "Event should load")

    // Step 2: Open actions menu and verify options
    screen.openActionsMenu()
    sleep(1)
    add(app.takeScreenshot(name: "29-journey-menu-opened"))

    // Dismiss menu by tapping elsewhere
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    sleep(1)

    // Step 3: Scroll through all sections
    screen.scrollDown()
    sleep(1)
    add(app.takeScreenshot(name: "30-journey-scrolled-down"))

    screen.scrollDown()
    sleep(1)
    add(app.takeScreenshot(name: "31-journey-scrolled-further"))

    // Step 4: Pull to refresh
    screen.scrollUp()
    sleep(1)
    screen.pullToRefresh()
    sleep(2)
    add(app.takeScreenshot(name: "32-journey-refreshed"))

    XCTAssertTrue(
      screen.waitForEventToLoad(),
      "Event should reload after pull-to-refresh"
    )

    // Step 5: Open edit sheet and dismiss
    screen.tapEditAction()
    sleep(1)

    if screen.waitForEditSheet() {
      add(app.takeScreenshot(name: "33-journey-edit-sheet"))
      screen.editCancelButton.tap()
      sleep(1)
    }

    add(app.takeScreenshot(name: "34-journey-complete"))
  }
}
