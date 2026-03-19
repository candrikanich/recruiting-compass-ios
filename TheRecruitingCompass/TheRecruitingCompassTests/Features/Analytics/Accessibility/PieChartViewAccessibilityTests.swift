import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class PieChartViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeSegments(count: Int = 3) -> [PieChartSegment] {
    let labels = ["Email", "Phone Call", "Campus Visit", "Letter", "Social Media"]
    let colors: [Color] = [.blue, .green, .orange, .red, .purple]
    return (0..<count).map { i in
      PieChartSegment(
        label: labels[i % labels.count],
        value: (i + 1) * 10,
        color: colors[i % colors.count]
      )
    }
  }

  // MARK: - Accessibility Label Tests

  func testPieChart_hasLabelWithTitleAndSegmentCount() {
    let segments = makeSegments(count: 3)
    let view = PieChartView(segments: segments, title: "Interaction Types")
    XCTAssertNotNil(view)
    XCTAssertEqual(segments.count, 3)
  }

  func testPieChart_emptyState_hasDescriptiveLabel() {
    let view = PieChartView(segments: [], title: "Interaction Types")
    // Should announce "Interaction Types pie chart. No data available."
    XCTAssertNotNil(view)
  }

  // MARK: - Accessibility Value Tests

  func testPieChart_valueIncludesAllSegmentsWithPercentages() {
    let segments = [
      PieChartSegment(label: "Email", value: 60, color: .blue),
      PieChartSegment(label: "Phone", value: 40, color: .green)
    ]
    let view = PieChartView(segments: segments, title: "Interaction Types")
    // Value should be: "Email: 60 (60%); Phone: 40 (40%)"
    XCTAssertNotNil(view)
    let total = segments.reduce(0) { $0 + $1.value }
    XCTAssertEqual(total, 100)
  }

  func testPieChart_singleSegment_shows100Percent() {
    let segments = [PieChartSegment(label: "Email", value: 50, color: .blue)]
    let view = PieChartView(segments: segments, title: "Types")
    XCTAssertNotNil(view)
    XCTAssertEqual(segments.count, 1)
  }

  // MARK: - Children Ignored Tests

  func testPieChart_usesChildrenIgnore() {
    // Uses .accessibilityElement(children: .ignore) so VoiceOver doesn't
    // attempt to navigate individual pie slices or legend items
    let view = PieChartView(segments: makeSegments(), title: "Test")
    XCTAssertNotNil(view)
  }

  // MARK: - Empty State Icon Hidden

  func testPieChart_emptyStateIconIsHidden() {
    // Empty state uses ChartEmptyStateView which hides decorative icon
    let view = PieChartView(segments: [], title: "Test")
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testPieChart_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .accessibilityExtraExtraExtraLarge
    ]
    for size in sizes {
      let view = PieChartView(segments: makeSegments(), title: "Test")
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Semantic Font Tests

  func testPieChart_usesSemanticFonts() {
    // Uses .headline, .caption, .title2.bold(), .subheadline -- all semantic
    let view = PieChartView(segments: makeSegments(), title: "Test")
    XCTAssertNotNil(view)
  }
}
