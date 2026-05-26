import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class ActivityFeedViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Navigation Title

  func testView_HasNavigationTitle() {
    let view = ActivityFeedView()
    XCTAssertEqual(
      view.navigationTitleText,
      "Activity History",
      "View should expose 'Activity History' as its VoiceOver heading"
    )
  }

  // MARK: - Clear Search Button

  func testClearSearchButton_HasAccessibilityLabel() {
    let view = ActivityFeedView()
    XCTAssertEqual(
      view.clearSearchAccessibilityLabel,
      "Clear search",
      "Clear search button should announce 'Clear search'"
    )
  }

  // MARK: - Page Indicator

  func testPageIndicator_HasLabelWithPageNumbers() {
    let view = ActivityFeedView()
    XCTAssertEqual(
      view.pageIndicatorAccessibilityLabel(currentPage: 2, totalPages: 5),
      "Page 2 of 5",
      "Page indicator should announce current and total page"
    )
  }

  func testPageIndicator_LabelReflectsSinglePage() {
    let view = ActivityFeedView()
    XCTAssertEqual(view.pageIndicatorAccessibilityLabel(currentPage: 1, totalPages: 1), "Page 1 of 1")
  }

  // MARK: - Filter / Pagination / Decorative Icons
  //
  // The remaining a11y guarantees of this view live in private @ViewBuilder
  // subviews (filter section, pagination, empty/error states) that cannot be
  // constructed or introspected from a unit test, because SwiftUI does not expose
  // its accessibility tree to UIHostingController in unit tests. These are verified
  // by the E2E/VoiceOver audit:
  //   - Type/Date Range Pickers carry titles "Activity Type" / "Date Range".
  //   - Pagination Previous/Next use Label() so VoiceOver reads the text.
  //   - Search magnifier, empty-state, and error icons are `.accessibilityHidden(true)`.
  //   - Search field, empty-state, and pagination controls carry accessibility
  //     identifiers (e.g. "activity-feed-search-field", "activity-feed-empty-state").
  //   - Interactive controls use `.frame(minWidth: 44, minHeight: 44)`.
}
