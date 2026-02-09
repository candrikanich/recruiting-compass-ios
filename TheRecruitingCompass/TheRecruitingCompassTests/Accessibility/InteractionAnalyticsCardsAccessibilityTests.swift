import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InteractionAnalyticsCardsAccessibilityTests: XCTestCase {

  // MARK: - Total Card

  func testTotalCard_HasDescriptiveAccessibilityLabel_Singular() {
    let card = AnalyticsCard(
      title: "Total",
      value: 1,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    // Should announce count before context (singular)
    XCTAssertEqual(view.accessibilityLabel, "1 total interaction")
  }

  func testTotalCard_HasDescriptiveAccessibilityLabel_Plural() {
    let card = AnalyticsCard(
      title: "Total",
      value: 47,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    // Should announce count before context (plural)
    XCTAssertEqual(view.accessibilityLabel, "47 total interactions")
  }

  // MARK: - Outbound Card

  func testOutboundCard_HasDescriptiveAccessibilityLabel() {
    let card = AnalyticsCard(
      title: "Outbound",
      value: 32,
      icon: "arrow.up.circle.fill",
      backgroundColor: Color.green.opacity(0.1),
      iconColor: .green
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    XCTAssertEqual(view.accessibilityLabel, "32 outbound interactions")
  }

  // MARK: - Inbound Card

  func testInboundCard_HasDescriptiveAccessibilityLabel() {
    let card = AnalyticsCard(
      title: "Inbound",
      value: 15,
      icon: "arrow.down.circle.fill",
      backgroundColor: Color.purple.opacity(0.1),
      iconColor: .purple
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    XCTAssertEqual(view.accessibilityLabel, "15 inbound interactions")
  }

  // MARK: - This Week Card

  func testThisWeekCard_HasDescriptiveAccessibilityLabel() {
    let card = AnalyticsCard(
      title: "This Week",
      value: 8,
      icon: "calendar.circle.fill",
      backgroundColor: Color.orange.opacity(0.1),
      iconColor: .orange
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    XCTAssertEqual(view.accessibilityLabel, "8 interactions this week")
  }

  // MARK: - Icon Hiding

  func testCardIcon_IsHidden() {
    let card = AnalyticsCard(
      title: "Total",
      value: 47,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    // Find image views - should be hidden
    let images = findSubviews(of: UIImageView.self, in: view)
    XCTAssertTrue(images.allSatisfy { $0.accessibilityElementsHidden })
  }

  // MARK: - Dynamic Type Support

  func testCard_SupportsDynamicType() {
    let card = AnalyticsCard(
      title: "Total",
      value: 47,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    // Force layout
    hostingController.view.layoutIfNeeded()

    // Card should scale appropriately
    // Minimum height should be larger for accessibility sizes
    XCTAssertGreaterThanOrEqual(view.frame.height, 44.0)
  }

  // MARK: - Zero Count

  func testCard_HandlesZeroCount() {
    let card = AnalyticsCard(
      title: "Total",
      value: 0,
      icon: "bubble.left.and.bubble.right.fill",
      backgroundColor: Color.blue.opacity(0.1),
      iconColor: .blue
    )

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    // Should use plural for zero
    XCTAssertEqual(view.accessibilityLabel, "0 total interactions")
  }

  // MARK: - Helper Methods

  private func findSubviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
    var results: [T] = []
    for subview in view.subviews {
      if let match = subview as? T {
        results.append(match)
      }
      results.append(contentsOf: findSubviews(of: type, in: subview))
    }
    return results
  }
}
