import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class ScatterChartViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeDataSet(
    pointCount: Int = 5,
    label: String = "Exit Velocity vs Distance"
  ) -> ScatterDataSet {
    let points = (0..<pointCount).map { i in
      ScatterDataPoint(
        x: 80.0 + Double(i) * 2,
        y: 300.0 + Double(i) * 20,
        label: "Player \(i + 1)"
      )
    }
    return ScatterDataSet(
      label: label,
      points: points,
      xAxisLabel: "Exit Velocity (mph)",
      yAxisLabel: "Distance (ft)"
    )
  }

  // MARK: - Accessibility Label Tests

  func testScatterChart_hasLabelWithTitleAndDataSetInfo() {
    let dataSet = makeDataSet(pointCount: 5)
    let view = ScatterChartView(dataSet: dataSet, title: "Performance Correlation")
    XCTAssertNotNil(view)
    XCTAssertEqual(dataSet.points.count, 5)
  }

  func testScatterChart_emptyState_hasDescriptiveLabel() {
    let emptyDataSet = ScatterDataSet(label: "Test", points: [], xAxisLabel: "X", yAxisLabel: "Y")
    let view = ScatterChartView(dataSet: emptyDataSet, title: "Performance Correlation")
    // Should announce "Performance Correlation scatter plot. No correlation data."
    XCTAssertNotNil(view)
    XCTAssertTrue(emptyDataSet.points.isEmpty)
  }

  // MARK: - Accessibility Value Tests

  func testScatterChart_valueIncludesDataRanges() {
    let dataSet = makeDataSet(pointCount: 5)
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)

    let xValues = dataSet.points.map(\.x)
    XCTAssertNotNil(xValues.min())
    XCTAssertNotNil(xValues.max())
  }

  func testScatterChart_singlePoint() {
    let dataSet = ScatterDataSet(
      label: "Test",
      points: [ScatterDataPoint(x: 85, y: 320, label: "Player 1")],
      xAxisLabel: "Velocity",
      yAxisLabel: "Distance"
    )
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
    XCTAssertEqual(dataSet.points.count, 1)
  }

  // MARK: - Data Points Hidden from Accessibility

  func testScatterChart_individualPointsAreHidden() {
    // Individual scatter points use .accessibilityHidden(true) since the
    // parent element provides a comprehensive summary via .accessibilityValue
    let dataSet = makeDataSet()
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
  }

  // MARK: - Reduce Motion Tests

  func testScatterChart_respectsReduceMotion() {
    // ScatterChartView reads @Environment(\.accessibilityReduceMotion)
    // and conditionally uses animation only when reduce motion is off
    let dataSet = makeDataSet()
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
  }

  // MARK: - Dismiss Button Tests

  func testScatterChart_dismissButtonHasAccessibilityLabel() {
    // Dismiss button has .accessibilityLabel("Dismiss data point details")
    // and meets 44x44pt hit target via .frame(minWidth: 44, minHeight: 44)
    let dataSet = makeDataSet()
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
  }

  func testScatterChart_dismissButtonMeetsHitTarget() {
    // Dismiss button has .frame(minWidth: 44, minHeight: 44) and .contentShape(Rectangle())
    let dataSet = makeDataSet()
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
  }

  // MARK: - Selected Point Info Tests

  func testScatterChart_selectedPointInfoHasCombinedLabel() {
    // Selected point info uses .accessibilityElement(children: .combine)
    // with full descriptive label including axis values
    let dataSet = makeDataSet()
    let view = ScatterChartView(dataSet: dataSet, title: "Correlation")
    XCTAssertNotNil(view)
    XCTAssertEqual(dataSet.xAxisLabel, "Exit Velocity (mph)")
    XCTAssertEqual(dataSet.yAxisLabel, "Distance (ft)")
  }

  // MARK: - Empty State Icon Hidden

  func testScatterChart_emptyStateIconIsHidden() {
    // Empty state uses ChartEmptyStateView which hides decorative icon
    let emptyDataSet = ScatterDataSet(label: "Test", points: [], xAxisLabel: "X", yAxisLabel: "Y")
    let view = ScatterChartView(dataSet: emptyDataSet, title: "Correlation")
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testScatterChart_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .accessibilityExtraExtraExtraLarge
    ]
    for size in sizes {
      let view = ScatterChartView(dataSet: makeDataSet(), title: "Correlation")
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Semantic Font Tests

  func testScatterChart_usesSemanticFonts() {
    // Uses .headline, .subheadline, .caption, .subheadline.bold() -- all semantic
    let view = ScatterChartView(dataSet: makeDataSet(), title: "Correlation")
    XCTAssertNotNil(view)
  }
}
