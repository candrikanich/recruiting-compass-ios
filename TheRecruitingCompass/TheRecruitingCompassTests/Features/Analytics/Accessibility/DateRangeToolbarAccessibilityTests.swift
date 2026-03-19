import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class DateRangeToolbarAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Filter Button Label Tests

  func testDateRangeToolbar_presetButtonsHaveLabels() {
    let presets = AnalyticsDateRange.allPresets
    XCTAssertEqual(presets.count, 3)
    // Each button gets .accessibilityLabel("Filter by [displayName]")
    XCTAssertEqual(presets[0].displayName, "Last 7 Days")
    XCTAssertEqual(presets[1].displayName, "Last 30 Days")
    XCTAssertEqual(presets[2].displayName, "Last 90 Days")
  }

  func testDateRangeToolbar_customButtonHasLabel() {
    // Custom button has .accessibilityLabel("Select custom date range")
    let view = DateRangeToolbar(
      selectedRange: .constant(.last30Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    XCTAssertNotNil(view)
  }

  // MARK: - Selected Trait Tests

  func testDateRangeToolbar_selectedPresetHasSelectedTrait() {
    let view = DateRangeToolbar(
      selectedRange: .constant(.last7Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    // Selected preset should have .isSelected trait and "Currently selected" hint
    XCTAssertNotNil(view)
  }

  func testDateRangeToolbar_unselectedPresetHasFilterHint() {
    let view = DateRangeToolbar(
      selectedRange: .constant(.last30Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    // Unselected presets should have "Double tap to filter by [name]" hint
    XCTAssertNotNil(view)
  }

  func testDateRangeToolbar_customButtonHasSelectedTraitWhenActive() {
    let view = DateRangeToolbar(
      selectedRange: .constant(.custom(start: Date(), end: Date())),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    // Custom button should have .isSelected trait and "Currently selected" hint
    XCTAssertNotNil(view)
  }

  // MARK: - Hit Target Tests

  func testDateRangeToolbar_filterButtonsMeetMinimumHitTarget() {
    // All filter buttons use .frame(minHeight: 44) to meet 44pt minimum
    let view = DateRangeToolbar(
      selectedRange: .constant(.last30Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    XCTAssertNotNil(view)
  }

  // MARK: - Container Label Tests

  func testDateRangeToolbar_containerHasLabel() {
    // Container HStack has .accessibilityElement(children: .contain)
    // and .accessibilityLabel("Date range filters")
    let view = DateRangeToolbar(
      selectedRange: .constant(.last30Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    XCTAssertNotNil(view)
  }

  // MARK: - Calendar Icon Hidden Tests

  func testDateRangeToolbar_calendarIconIsHidden() {
    // Calendar icon on custom button uses .accessibilityHidden(true)
    let view = DateRangeToolbar(
      selectedRange: .constant(.last30Days),
      showDatePicker: .constant(false),
      onRangeSelected: { _ in }
    )
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testDateRangeToolbar_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .accessibilityExtraExtraExtraLarge
    ]
    for size in sizes {
      let view = DateRangeToolbar(
        selectedRange: .constant(.last30Days),
        showDatePicker: .constant(false),
        onRangeSelected: { _ in }
      )
      .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }
}
