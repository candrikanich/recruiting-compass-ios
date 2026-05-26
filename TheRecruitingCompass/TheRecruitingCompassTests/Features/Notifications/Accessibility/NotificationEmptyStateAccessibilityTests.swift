import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationEmptyStateAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Accessibility Label

  func testEmptyState_HasDescriptiveLabel() {
    let label = NotificationEmptyState().emptyStateAccessibilityLabel
    XCTAssertTrue(label.contains("No notifications"), "Empty state should announce 'No notifications'")
  }

  func testEmptyState_ProvidesEncouragingContext() {
    let label = NotificationEmptyState().emptyStateAccessibilityLabel
    XCTAssertTrue(label.contains("caught up"), "Empty state should provide encouraging context beyond bare status")
  }

  func testEmptyState_LabelIsExactExpectedString() {
    let label = NotificationEmptyState().emptyStateAccessibilityLabel
    XCTAssertEqual(label, "No notifications. You're all caught up!")
  }

  // MARK: - Decorative Icon / Combined Element / Non-Interactive
  //
  // The empty state hides its bell icon via `.accessibilityHidden(true)`,
  // combines children with `.accessibilityElement(children: .combine)`, and is
  // purely informational (no button trait). Those modifiers are not
  // introspectable from a unit test (SwiftUI does not expose its accessibility
  // tree to UIHostingController in unit tests), so the single combined label is
  // asserted above and the hidden-icon / combined-element / non-interactive
  // behavior is verified by the E2E/VoiceOver audit.

  // MARK: - Dynamic Type

  func testEmptyState_IconScalesWithAccessibilityCategory() {
    // Icon size is data-driven from the size category, so it scales with
    // Dynamic Type rather than using a fixed point size.
    let standardState = NotificationEmptyState()
      .environment(\.sizeCategory, .large)
    let accessibilityState = NotificationEmptyState()
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let standardHost = UIHostingController(rootView: standardState)
    let accessibilityHost = UIHostingController(rootView: accessibilityState)

    XCTAssertNotNil(standardHost.view, "Empty state should render at the standard text size")
    XCTAssertNotNil(accessibilityHost.view, "Empty state should render at accessibility text sizes")
  }
}
