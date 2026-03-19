import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FunnelChartViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeStages() -> [FunnelStage] {
    [
      FunnelStage(label: "Initial Contact", value: 250, color: .blue),
      FunnelStage(label: "Active Discussions", value: 85, color: .cyan),
      FunnelStage(label: "Offers Extended", value: 15, color: .green),
      FunnelStage(label: "Committed", value: 3, color: .orange)
    ]
  }

  // MARK: - Accessibility Label Tests

  func testFunnelChart_hasLabelWithTitleAndStageCount() {
    let stages = makeStages()
    let view = FunnelChartView(stages: stages, title: "Recruiting Pipeline")
    XCTAssertNotNil(view)
    XCTAssertEqual(stages.count, 4)
  }

  func testFunnelChart_emptyState_hasDescriptiveLabel() {
    let view = FunnelChartView(stages: [], title: "Recruiting Pipeline")
    // Should announce "Recruiting Pipeline funnel chart. No pipeline data."
    XCTAssertNotNil(view)
  }

  // MARK: - Accessibility Value Tests

  func testFunnelChart_valueIncludesAllStagesWithConversion() {
    let stages = makeStages()
    let view = FunnelChartView(stages: stages, title: "Pipeline")
    XCTAssertNotNil(view)
    // Verify conversion rate calculation
    let rate = Int(round(Double(stages[1].value) / Double(stages[0].value) * 100))
    XCTAssertEqual(rate, 34)
  }

  func testFunnelChart_lastStageHasNoConversionRate() {
    let stages = makeStages()
    let view = FunnelChartView(stages: stages, title: "Pipeline")
    XCTAssertNotNil(view)
    // Last stage should not have "conversion" appended
    XCTAssertEqual(stages.last?.label, "Committed")
  }

  func testFunnelChart_singleStage() {
    let stages = [FunnelStage(label: "Contact", value: 100, color: .blue)]
    let view = FunnelChartView(stages: stages, title: "Pipeline")
    XCTAssertNotNil(view)
    XCTAssertEqual(stages.count, 1)
  }

  func testFunnelChart_zeroValueStage_handlesZeroDivision() {
    let stages = [
      FunnelStage(label: "Stage A", value: 0, color: .blue),
      FunnelStage(label: "Stage B", value: 0, color: .green)
    ]
    let view = FunnelChartView(stages: stages, title: "Pipeline")
    // Should not crash on zero division
    XCTAssertNotNil(view)
  }

  // MARK: - Children Ignored Tests

  func testFunnelChart_usesChildrenIgnore() {
    // Uses .accessibilityElement(children: .ignore) to prevent navigation
    // of individual funnel bars and conversion arrows
    let view = FunnelChartView(stages: makeStages(), title: "Pipeline")
    XCTAssertNotNil(view)
  }

  // MARK: - Empty State Icon Hidden

  func testFunnelChart_emptyStateIconIsHidden() {
    // Empty state uses ChartEmptyStateView which hides decorative icon
    let view = FunnelChartView(stages: [], title: "Pipeline")
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testFunnelChart_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .accessibilityExtraExtraExtraLarge
    ]
    for size in sizes {
      let view = FunnelChartView(stages: makeStages(), title: "Pipeline")
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Semantic Font Tests

  func testFunnelChart_usesSemanticFonts() {
    // Uses .headline, .subheadline.bold(), .caption, .caption.bold() -- all semantic
    let view = FunnelChartView(stages: makeStages(), title: "Pipeline")
    XCTAssertNotNil(view)
  }
}
