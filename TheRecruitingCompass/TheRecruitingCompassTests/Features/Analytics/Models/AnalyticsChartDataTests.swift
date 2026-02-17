import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsChartDataTests: XCTestCase {

  // MARK: - PieChartSegment Tests

  func testPieChartSegment_Initialization() {
    let segment = PieChartSegment(label: "Email", value: 34, color: .blue)

    XCTAssertEqual(segment.label, "Email")
    XCTAssertEqual(segment.value, 34)
    XCTAssertEqual(segment.color, .blue)
    XCTAssertNotNil(segment.id)
  }

  func testPieChartSegment_DefaultIdIsUnique() {
    let segment1 = PieChartSegment(label: "Email", value: 34, color: .blue)
    let segment2 = PieChartSegment(label: "Email", value: 34, color: .blue)

    XCTAssertNotEqual(segment1.id, segment2.id)
  }

  func testPieChartSegment_CustomId() {
    let customId = UUID()
    let segment = PieChartSegment(id: customId, label: "Phone", value: 28, color: .green)

    XCTAssertEqual(segment.id, customId)
  }

  func testPieChartSegment_Percentage() {
    let segment = PieChartSegment(label: "Email", value: 50, color: .blue)

    XCTAssertEqual(segment.percentage, 50.0)
  }

  func testPieChartSegment_PercentageWithZeroValue() {
    let segment = PieChartSegment(label: "None", value: 0, color: .gray)

    XCTAssertEqual(segment.percentage, 0.0)
  }

  func testPieChartSegment_Equatable_SameId() {
    let id = UUID()
    let segment1 = PieChartSegment(id: id, label: "Email", value: 34, color: .blue)
    let segment2 = PieChartSegment(id: id, label: "Email", value: 34, color: .blue)

    XCTAssertEqual(segment1, segment2)
  }

  func testPieChartSegment_Equatable_DifferentId() {
    let segment1 = PieChartSegment(label: "Email", value: 34, color: .blue)
    let segment2 = PieChartSegment(label: "Email", value: 34, color: .blue)

    XCTAssertNotEqual(segment1, segment2)
  }

  func testPieChartSegment_EmptyLabel() {
    let segment = PieChartSegment(label: "", value: 10, color: .red)

    XCTAssertTrue(segment.label.isEmpty)
    XCTAssertEqual(segment.value, 10)
  }

  func testPieChartSegment_LargeValue() {
    let segment = PieChartSegment(label: "Large", value: 1_000_000, color: .purple)

    XCTAssertEqual(segment.value, 1_000_000)
    XCTAssertEqual(segment.percentage, 1_000_000.0)
  }

  // MARK: - FunnelStage Tests

  func testFunnelStage_Initialization() {
    let stage = FunnelStage(label: "Initial Contact", value: 250, color: .blue)

    XCTAssertEqual(stage.label, "Initial Contact")
    XCTAssertEqual(stage.value, 250)
    XCTAssertEqual(stage.color, .blue)
    XCTAssertNotNil(stage.id)
  }

  func testFunnelStage_DefaultIdIsUnique() {
    let stage1 = FunnelStage(label: "Contact", value: 100, color: .blue)
    let stage2 = FunnelStage(label: "Contact", value: 100, color: .blue)

    XCTAssertNotEqual(stage1.id, stage2.id)
  }

  func testFunnelStage_CustomId() {
    let customId = UUID()
    let stage = FunnelStage(id: customId, label: "Offers", value: 15, color: .green)

    XCTAssertEqual(stage.id, customId)
  }

  func testFunnelStage_Equatable_SameId() {
    let id = UUID()
    let stage1 = FunnelStage(id: id, label: "Contact", value: 100, color: .blue)
    let stage2 = FunnelStage(id: id, label: "Contact", value: 100, color: .blue)

    XCTAssertEqual(stage1, stage2)
  }

  func testFunnelStage_Equatable_DifferentValues() {
    let id = UUID()
    let stage1 = FunnelStage(id: id, label: "Contact", value: 100, color: .blue)
    let stage2 = FunnelStage(id: id, label: "Contact", value: 200, color: .blue)

    XCTAssertNotEqual(stage1, stage2)
  }

  func testFunnelStage_ZeroValue() {
    let stage = FunnelStage(label: "Committed", value: 0, color: .orange)

    XCTAssertEqual(stage.value, 0)
  }

  // MARK: - ScatterDataPoint Tests

  func testScatterDataPoint_Initialization() {
    let point = ScatterDataPoint(x: 85.0, y: 340.0, label: "Player A", color: .red)

    XCTAssertEqual(point.x, 85.0)
    XCTAssertEqual(point.y, 340.0)
    XCTAssertEqual(point.label, "Player A")
    XCTAssertEqual(point.color, .red)
    XCTAssertNotNil(point.id)
  }

  func testScatterDataPoint_DefaultColor() {
    let point = ScatterDataPoint(x: 85.0, y: 340.0, label: "Player A")

    XCTAssertEqual(point.color, .accentBlue)
  }

  func testScatterDataPoint_DefaultIdIsUnique() {
    let point1 = ScatterDataPoint(x: 85.0, y: 340.0, label: "Player A")
    let point2 = ScatterDataPoint(x: 85.0, y: 340.0, label: "Player A")

    XCTAssertNotEqual(point1.id, point2.id)
  }

  func testScatterDataPoint_CustomId() {
    let customId = UUID()
    let point = ScatterDataPoint(id: customId, x: 90.0, y: 400.0, label: "Player B")

    XCTAssertEqual(point.id, customId)
  }

  func testScatterDataPoint_NegativeCoordinates() {
    let point = ScatterDataPoint(x: -10.0, y: -5.0, label: "Negative")

    XCTAssertEqual(point.x, -10.0)
    XCTAssertEqual(point.y, -5.0)
  }

  func testScatterDataPoint_ZeroCoordinates() {
    let point = ScatterDataPoint(x: 0.0, y: 0.0, label: "Origin")

    XCTAssertEqual(point.x, 0.0)
    XCTAssertEqual(point.y, 0.0)
  }

  func testScatterDataPoint_Equatable_SameId() {
    let id = UUID()
    let point1 = ScatterDataPoint(id: id, x: 85.0, y: 340.0, label: "A")
    let point2 = ScatterDataPoint(id: id, x: 85.0, y: 340.0, label: "A")

    XCTAssertEqual(point1, point2)
  }

  func testScatterDataPoint_EmptyLabel() {
    let point = ScatterDataPoint(x: 50.0, y: 50.0, label: "")

    XCTAssertTrue(point.label.isEmpty)
  }

  // MARK: - ScatterDataSet Tests

  func testScatterDataSet_Initialization() {
    let points = [
      ScatterDataPoint(x: 85.0, y: 340.0, label: "Player A"),
      ScatterDataPoint(x: 90.0, y: 380.0, label: "Player B")
    ]
    let dataSet = ScatterDataSet(
      label: "Exit Velocity vs Distance",
      points: points,
      xAxisLabel: "Exit Velocity (mph)",
      yAxisLabel: "Distance (ft)"
    )

    XCTAssertEqual(dataSet.label, "Exit Velocity vs Distance")
    XCTAssertEqual(dataSet.points.count, 2)
    XCTAssertEqual(dataSet.xAxisLabel, "Exit Velocity (mph)")
    XCTAssertEqual(dataSet.yAxisLabel, "Distance (ft)")
  }

  func testScatterDataSet_DefaultAxisLabels() {
    let dataSet = ScatterDataSet(label: "Data", points: [])

    XCTAssertEqual(dataSet.xAxisLabel, "X")
    XCTAssertEqual(dataSet.yAxisLabel, "Y")
  }

  func testScatterDataSet_EmptyPoints() {
    let dataSet = ScatterDataSet(label: "Empty", points: [])

    XCTAssertTrue(dataSet.points.isEmpty)
  }

  func testScatterDataSet_Equatable() {
    let id = UUID()
    let points = [ScatterDataPoint(id: id, x: 1.0, y: 2.0, label: "P1")]
    let set1 = ScatterDataSet(label: "Set", points: points, xAxisLabel: "X", yAxisLabel: "Y")
    let set2 = ScatterDataSet(label: "Set", points: points, xAxisLabel: "X", yAxisLabel: "Y")

    XCTAssertEqual(set1, set2)
  }

  func testScatterDataSet_NotEqual_DifferentLabels() {
    let points = [ScatterDataPoint(x: 1.0, y: 2.0, label: "P1")]
    let set1 = ScatterDataSet(label: "Set A", points: points)
    let set2 = ScatterDataSet(label: "Set B", points: points)

    XCTAssertNotEqual(set1, set2)
  }

  func testScatterDataSet_LargePointCount() {
    let points = (0..<1000).map { i in
      ScatterDataPoint(x: Double(i), y: Double(i * 2), label: "P\(i)")
    }
    let dataSet = ScatterDataSet(label: "Large", points: points)

    XCTAssertEqual(dataSet.points.count, 1000)
  }

  // MARK: - Identifiable Conformance Tests

  func testPieChartSegment_CanBeUsedInArray() {
    let segments = [
      PieChartSegment(label: "Email", value: 34, color: .blue),
      PieChartSegment(label: "Phone", value: 28, color: .green),
      PieChartSegment(label: "Text", value: 15, color: .orange)
    ]

    XCTAssertEqual(segments.count, 3)
    let ids = Set(segments.map(\.id))
    XCTAssertEqual(ids.count, 3)
  }

  func testFunnelStage_CanBeUsedInArray() {
    let stages = [
      FunnelStage(label: "Initial Contact", value: 250, color: .blue),
      FunnelStage(label: "Active Discussions", value: 85, color: .green),
      FunnelStage(label: "Offers", value: 15, color: .orange),
      FunnelStage(label: "Committed", value: 3, color: .red)
    ]

    XCTAssertEqual(stages.count, 4)
    let ids = Set(stages.map(\.id))
    XCTAssertEqual(ids.count, 4)
  }
}
