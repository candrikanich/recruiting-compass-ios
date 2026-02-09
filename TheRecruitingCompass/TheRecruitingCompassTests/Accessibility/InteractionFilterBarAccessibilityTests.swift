import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionFilterBarAccessibilityTests: XCTestCase {

  // MARK: - Type Filter

  func testTypeFilter_HasCorrectAccessibilityLabel_NoSelection() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    // Type filter should have descriptive label when no selection
    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by type"))
  }

  func testTypeFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.type = .email

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    // Type filter should announce selected type
    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by type: Email selected"))
  }

  func testTypeFilter_HasCorrectAccessibilityHint() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    // Type filter should have hint explaining menu action
    let hints = findAccessibilityHints(in: view)
    XCTAssertTrue(hints.contains("Opens menu to filter by interaction type"))
  }

  // MARK: - Direction Filter

  func testDirectionFilter_HasCorrectAccessibilityLabel_NoSelection() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by direction"))
  }

  func testDirectionFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.direction = .outbound

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by direction: Outbound selected"))
  }

  // MARK: - Sentiment Filter

  func testSentimentFilter_HasCorrectAccessibilityLabel_NoSelection() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by sentiment"))
  }

  func testSentimentFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.sentiment = .veryPositive

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by sentiment: Very Positive selected"))
  }

  // MARK: - Time Period Filter

  func testTimePeriodFilter_HasCorrectAccessibilityLabel_NoSelection() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by time period"))
  }

  func testTimePeriodFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.timePeriod = .last7Days

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by time period: Last 7 days selected"))
  }

  // MARK: - Logged By Filter (Parents Only)

  func testLoggedByFilter_NotShownForAthletes() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: false,
      linkedAthletes: [],
      currentUserId: nil
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertFalse(labels.contains("Filter by logged by"))
  }

  func testLoggedByFilter_HasCorrectAccessibilityLabel_NoSelection() {
    var filters = InteractionFilters()

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: true,
      linkedAthletes: [],
      currentUserId: "user1"
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by logged by"))
  }

  func testLoggedByFilter_HasCorrectAccessibilityLabel_MeSelected() {
    var filters = InteractionFilters()
    filters.loggedBy = "user1"

    let filterBar = InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: true,
      linkedAthletes: [],
      currentUserId: "user1"
    )

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let labels = findAccessibilityLabels(in: view)
    XCTAssertTrue(labels.contains("Filter by logged by: Me selected"))
  }

  // MARK: - Helper Methods

  private func findAccessibilityLabels(in view: UIView) -> [String] {
    var labels: [String] = []

    if let label = view.accessibilityLabel {
      labels.append(label)
    }

    for subview in view.subviews {
      labels.append(contentsOf: findAccessibilityLabels(in: subview))
    }

    return labels
  }

  private func findAccessibilityHints(in view: UIView) -> [String] {
    var hints: [String] = []

    if let hint = view.accessibilityHint {
      hints.append(hint)
    }

    for subview in view.subviews {
      hints.append(contentsOf: findAccessibilityHints(in: subview))
    }

    return hints
  }
}
