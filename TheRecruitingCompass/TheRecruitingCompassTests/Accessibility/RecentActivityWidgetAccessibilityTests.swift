import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class RecentActivityWidgetAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Refresh Button Accessibility

  func testRefreshButton_HasAccessibilityLabel() {
    let widget = RecentActivityWidget()
    XCTAssertEqual(
      widget.refreshAccessibilityLabel,
      "Refresh activities",
      "Refresh button should announce 'Refresh activities'"
    )
  }

  // MARK: - View All Link Accessibility

  func testViewAllLink_HasAccessibilityLabel() {
    let widget = RecentActivityWidget()
    XCTAssertEqual(
      widget.viewAllAccessibilityLabel,
      "View all activity",
      "View All link should announce 'View all activity'"
    )
  }

  func testViewAllLink_HasNavigationHint() {
    let widget = RecentActivityWidget()
    XCTAssertEqual(
      widget.viewAllAccessibilityHint,
      "Opens the full activity history page",
      "View All link should hint at navigation destination"
    )
  }

  // MARK: - Decorative Chevron / Touch Targets
  //
  // The "View All" chevron is `.accessibilityHidden(true)` and both the refresh
  // button and View All link use `.frame(minWidth: 44, minHeight: 44)`. Hidden
  // state and rendered frames are not introspectable from a unit test (SwiftUI
  // does not expose its accessibility tree to UIHostingController in unit tests);
  // these are covered by the E2E/VoiceOver audit. We instead assert the label/hint
  // strings VoiceOver actually announces, above.
}
