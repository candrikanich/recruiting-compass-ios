import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionAnalyticsCardsAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeCard(title: String, value: Int) -> AnalyticsCard {
    AnalyticsCard(
      title: title,
      value: value,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )
  }

  // MARK: - Total Card

  func testTotalCard_HasDescriptiveAccessibilityLabel_Singular() {
    let card = makeCard(title: "Total", value: 1)
    XCTAssertEqual(card.accessibilityLabel, "1 total interaction")
  }

  func testTotalCard_HasDescriptiveAccessibilityLabel_Plural() {
    let card = makeCard(title: "Total", value: 47)
    XCTAssertEqual(card.accessibilityLabel, "47 total interactions")
  }

  // MARK: - Outbound Card

  func testOutboundCard_HasDescriptiveAccessibilityLabel() {
    let card = makeCard(title: "Outbound", value: 32)
    XCTAssertEqual(card.accessibilityLabel, "32 outbound interactions")
  }

  // MARK: - Inbound Card

  func testInboundCard_HasDescriptiveAccessibilityLabel() {
    let card = makeCard(title: "Inbound", value: 15)
    XCTAssertEqual(card.accessibilityLabel, "15 inbound interactions")
  }

  // MARK: - This Week Card

  func testThisWeekCard_HasDescriptiveAccessibilityLabel() {
    let card = makeCard(title: "This Week", value: 8)
    XCTAssertEqual(card.accessibilityLabel, "8 interactions this week")
  }

  // MARK: - Icon Hiding
  //
  // The icon is hidden via `.accessibilityHidden(true)` in the SwiftUI body.
  // That modifier is not introspectable from a unit test (SwiftUI does not
  // expose its accessibility tree to UIHostingController here), so we instead
  // assert the count is conveyed in the label text. Hidden state is verified by
  // the E2E/VoiceOver audit.

  func testCardValueConveyedViaLabelNotIconAlone() {
    let card = makeCard(title: "Total", value: 47)
    XCTAssertTrue(
      card.accessibilityLabel.contains("47"),
      "Count must be conveyed as text, not the decorative icon alone"
    )
  }

  // MARK: - Zero Count

  func testCard_HandlesZeroCount() {
    let card = makeCard(title: "Total", value: 0)
    XCTAssertEqual(card.accessibilityLabel, "0 total interactions")
  }
}
