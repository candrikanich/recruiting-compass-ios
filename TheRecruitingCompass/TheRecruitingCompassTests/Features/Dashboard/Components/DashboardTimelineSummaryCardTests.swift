import SwiftUI
import XCTest
@testable import TheRecruitingCompass

final class DashboardTimelineSummaryCardTests: XCTestCase {
  nonisolated deinit {}

  private func card(
    phase: TimelinePhase? = .junior,
    status: DashboardTimelineSummaryCard.Status? = nil,
    favorite: String? = nil,
    steps: [WhatMattersItem] = [],
    unavailable: Bool = false
  ) -> DashboardTimelineSummaryCard {
    DashboardTimelineSummaryCard(
      phase: phase, status: status, favoriteSchoolName: favorite, nextSteps: steps,
      stepsUnavailable: unavailable, onViewTimeline: {})
  }

  func testAccessibility_withoutStatus_neverMentionsAScore() {
    let text = card().accessibilityText
    XCTAssertFalse(text.lowercased().contains("status score"))
  }

  func testAccessibility_withStatus_readsTheScore() {
    let text = card(status: .init(score: 64, color: .successGreen)).accessibilityText
    XCTAssertTrue(text.contains("status score 64 out of 100"))
  }

  func testAccessibility_unavailable_saysSoAndNamesNoGrade() {
    let text = card(phase: nil, unavailable: true).accessibilityText
    XCTAssertTrue(text.contains(DashboardTimelineSummaryCard.unavailableMessage))
    XCTAssertFalse(text.contains(TimelinePhase.freshman.displayLabel))
  }

  func testAccessibility_readsFavoriteSchoolAndSteps() {
    let step = WhatMattersItem(
      taskId: "1", title: "Register", whyItMatters: "w", category: "c", priority: 1, isRequired: true)
    let text = card(favorite: "State", steps: [step]).accessibilityText
    XCTAssertTrue(text.contains("Your top school: State"))
    XCTAssertTrue(text.contains("Register"))
  }
}
