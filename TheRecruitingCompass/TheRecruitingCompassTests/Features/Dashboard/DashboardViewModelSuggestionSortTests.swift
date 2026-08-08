import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewModelSuggestionSortTests: XCTestCase {
  nonisolated deinit {}

  func test_urgencyLevel_sortWeight_ordersHighFirst() {
    XCTAssertLessThan(Suggestion.UrgencyLevel.high.sortWeight, Suggestion.UrgencyLevel.medium.sortWeight)
    XCTAssertLessThan(Suggestion.UrgencyLevel.medium.sortWeight, Suggestion.UrgencyLevel.low.sortWeight)
  }

  func test_sortedByUrgency_isStableWithinSameUrgency() {
    let input = [
      makeSuggestion(id: "a", urgency: .low),
      makeSuggestion(id: "b", urgency: .high),
      makeSuggestion(id: "c", urgency: .medium),
      makeSuggestion(id: "d", urgency: .high)
    ]
    let sorted = input.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }
    XCTAssertEqual(sorted.map(\.id), ["b", "d", "c", "a"])
  }

  private func makeSuggestion(id: String, urgency: Suggestion.UrgencyLevel) -> Suggestion {
    Suggestion(
      id: id, ruleType: "interaction-gap", message: "m", urgency: urgency,
      actionType: nil, relatedSchoolId: nil, dismissed: false, completed: false,
      pendingSurface: nil, surfacedAt: nil
    )
  }
}
