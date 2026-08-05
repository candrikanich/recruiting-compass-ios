import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionCardTests: XCTestCase {
  nonisolated deinit {}

  private func makeInteraction(type: InteractionType = .email) -> Interaction {
    Interaction(
      id: "1",
      type: type,
      direction: .outbound,
      schoolId: "school1",
      coachId: "coach1",
      subject: "Follow-up",
      content: "Some content",
      sentiment: .veryPositive,
      occurredAt: ISO8601DateFormatter().string(from: Date()),
      loggedBy: "user1",
      attachments: [],
      familyUnitId: "family1",
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }

  // MARK: - Delete Affordance
  // Regression: delete was reachable only via .swipeActions, inert inside
  // ScrollView+LazyVStack. The card now owns an explicit, labeled delete button.

  func testDeleteAccessibilityLabel() {
    let card = InteractionCard(
      interaction: makeInteraction(type: .email),
      schoolName: "Stanford",
      coachName: "Coach Smith",
      onDelete: {}
    )

    XCTAssertEqual(card.deleteAccessibilityLabel, "Delete Email interaction")
  }

  func testOnDeleteClosureIsStored() {
    var deleted = false
    let card = InteractionCard(
      interaction: makeInteraction(),
      schoolName: nil,
      coachName: nil,
      onDelete: { deleted = true }
    )

    card.onDelete()

    XCTAssertTrue(deleted, "Delete button must invoke the supplied onDelete closure")
  }
}
