import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionFilterBarAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeFilterBar(
    filters: InteractionFilters = InteractionFilters(),
    showLoggedByFilter: Bool = false,
    linkedAthletes: [FamilyMember] = [],
    currentUserId: String? = nil
  ) -> InteractionFilterBar {
    InteractionFilterBar(
      filters: .constant(filters),
      showLoggedByFilter: showLoggedByFilter,
      linkedAthletes: linkedAthletes,
      currentUserId: currentUserId
    )
  }

  // MARK: - Type Filter

  func testTypeFilter_HasCorrectAccessibilityLabel_NoSelection() {
    let bar = makeFilterBar()
    XCTAssertEqual(bar.typeFilterAccessibilityLabel, "Filter by type")
  }

  func testTypeFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.type = .email
    let bar = makeFilterBar(filters: filters)
    XCTAssertEqual(bar.typeFilterAccessibilityLabel, "Filter by type: Email selected")
  }

  func testTypeFilter_HasCorrectAccessibilityHint() {
    let bar = makeFilterBar()
    XCTAssertEqual(bar.typeFilterAccessibilityHint, "Opens menu to filter by interaction type")
  }

  // MARK: - Direction Filter

  func testDirectionFilter_HasCorrectAccessibilityLabel_NoSelection() {
    let bar = makeFilterBar()
    XCTAssertEqual(bar.directionFilterAccessibilityLabel, "Filter by direction")
  }

  func testDirectionFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.direction = .outbound
    let bar = makeFilterBar(filters: filters)
    XCTAssertEqual(bar.directionFilterAccessibilityLabel, "Filter by direction: Outbound selected")
  }

  // MARK: - Sentiment Filter

  func testSentimentFilter_HasCorrectAccessibilityLabel_NoSelection() {
    let bar = makeFilterBar()
    XCTAssertEqual(bar.sentimentFilterAccessibilityLabel, "Filter by sentiment")
  }

  func testSentimentFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.sentiment = .veryPositive
    let bar = makeFilterBar(filters: filters)
    XCTAssertEqual(
      bar.sentimentFilterAccessibilityLabel,
      "Filter by sentiment: Very Positive selected"
    )
  }

  // MARK: - Time Period Filter

  func testTimePeriodFilter_HasCorrectAccessibilityLabel_NoSelection() {
    let bar = makeFilterBar()
    XCTAssertEqual(bar.timePeriodFilterAccessibilityLabel, "Filter by time period")
  }

  func testTimePeriodFilter_HasCorrectAccessibilityLabel_WithSelection() {
    var filters = InteractionFilters()
    filters.timePeriod = .last7Days
    let bar = makeFilterBar(filters: filters)
    XCTAssertEqual(
      bar.timePeriodFilterAccessibilityLabel,
      "Filter by time period: Last 7 days selected"
    )
  }

  // MARK: - Logged By Filter (Parents Only)

  // The logged-by menu is only rendered when `showLoggedByFilter` is true; that
  // conditional rendering is not introspectable from a unit test (SwiftUI does
  // not expose its view tree to UIHostingController here) and is covered by the
  // E2E/VoiceOver audit. The label logic itself is verified below.

  func testLoggedByFilter_HasCorrectAccessibilityLabel_NoSelection() {
    let bar = makeFilterBar(showLoggedByFilter: true, currentUserId: "user1")
    XCTAssertEqual(bar.loggedByFilterAccessibilityLabel, "Filter by logged by")
  }

  func testLoggedByFilter_HasCorrectAccessibilityLabel_MeSelected() {
    var filters = InteractionFilters()
    filters.loggedBy = "user1"
    let bar = makeFilterBar(filters: filters, showLoggedByFilter: true, currentUserId: "user1")
    XCTAssertEqual(bar.loggedByFilterAccessibilityLabel, "Filter by logged by: Me selected")
  }
}
