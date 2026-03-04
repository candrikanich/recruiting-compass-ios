import XCTest
@testable import TheRecruitingCompass

@MainActor
final class MetricTrendTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_SetsAllProperties() {
    let trend = createTrend(
      type: .velocity,
      values: [88.0, 89.0, 90.0],
      min: 88.0,
      max: 90.0,
      average: 89.0,
      unit: "mph",
      count: 3,
      trend: .improving
    )

    XCTAssertEqual(trend.type, .velocity)
    XCTAssertEqual(trend.values, [88.0, 89.0, 90.0])
    XCTAssertEqual(trend.min, 88.0)
    XCTAssertEqual(trend.max, 90.0)
    XCTAssertEqual(trend.average, 89.0)
    XCTAssertEqual(trend.unit, "mph")
    XCTAssertEqual(trend.count, 3)
    XCTAssertEqual(trend.trend, .improving)
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_GeneratesUniqueId() {
    let trend1 = createTrend(type: .velocity)
    let trend2 = createTrend(type: .exitVelo)

    XCTAssertNotEqual(trend1.id, trend2.id)
    XCTAssertEqual(trend1.id, "velocity")
    XCTAssertEqual(trend2.id, "exit_velo")
  }

  // MARK: - Equatable Tests

  func testEquatable_SameTypeCountTrend_AreEqual() {
    let trend1 = createTrend(type: .velocity, count: 5, trend: .improving)
    let trend2 = createTrend(type: .velocity, count: 5, trend: .improving)

    XCTAssertEqual(trend1, trend2)
  }

  func testEquatable_DifferentType_AreNotEqual() {
    let trend1 = createTrend(type: .velocity, count: 5, trend: .improving)
    let trend2 = createTrend(type: .exitVelo, count: 5, trend: .improving)

    XCTAssertNotEqual(trend1, trend2)
  }

  func testEquatable_DifferentCount_AreNotEqual() {
    let trend1 = createTrend(type: .velocity, count: 5, trend: .improving)
    let trend2 = createTrend(type: .velocity, count: 3, trend: .improving)

    XCTAssertNotEqual(trend1, trend2)
  }

  func testEquatable_DifferentTrend_AreNotEqual() {
    let trend1 = createTrend(type: .velocity, count: 5, trend: .improving)
    let trend2 = createTrend(type: .velocity, count: 5, trend: .declining)

    XCTAssertNotEqual(trend1, trend2)
  }

  func testEquatable_DifferentValues_ButSameTypeCountTrend_AreEqual() {
    // Equatable only checks type, count, and trend
    let trend1 = createTrend(
      type: .velocity,
      values: [88.0, 90.0],
      min: 88.0,
      max: 90.0,
      average: 89.0,
      count: 2,
      trend: .improving
    )
    let trend2 = createTrend(
      type: .velocity,
      values: [85.0, 95.0],
      min: 85.0,
      max: 95.0,
      average: 90.0,
      count: 2,
      trend: .improving
    )

    XCTAssertEqual(trend1, trend2)
  }

  // MARK: - TrendDirection Tests

  func testTrendDirection_Label() {
    XCTAssertEqual(MetricTrend.TrendDirection.improving.label, "Improving")
    XCTAssertEqual(MetricTrend.TrendDirection.declining.label, "Declining")
    XCTAssertEqual(MetricTrend.TrendDirection.stable.label, "Stable")
  }

  func testTrendDirection_SystemImage() {
    XCTAssertEqual(MetricTrend.TrendDirection.improving.systemImage, "arrow.up.right")
    XCTAssertEqual(MetricTrend.TrendDirection.declining.systemImage, "arrow.down.right")
    XCTAssertEqual(MetricTrend.TrendDirection.stable.systemImage, "arrow.right")
  }

  func testTrendDirection_RawValues() {
    XCTAssertEqual(MetricTrend.TrendDirection.improving.rawValue, "improving")
    XCTAssertEqual(MetricTrend.TrendDirection.declining.rawValue, "declining")
    XCTAssertEqual(MetricTrend.TrendDirection.stable.rawValue, "stable")
  }

  func testTrendDirection_Equatable() {
    XCTAssertEqual(MetricTrend.TrendDirection.improving, MetricTrend.TrendDirection.improving)
    XCTAssertNotEqual(MetricTrend.TrendDirection.improving, MetricTrend.TrendDirection.declining)
  }

  // MARK: - Edge Cases

  func testTrend_WithEmptyValues() {
    let trend = createTrend(values: [], count: 0)
    XCTAssertTrue(trend.values.isEmpty)
    XCTAssertEqual(trend.count, 0)
  }

  func testTrend_WithSingleValue() {
    let trend = createTrend(
      values: [90.0],
      min: 90.0,
      max: 90.0,
      average: 90.0,
      count: 1,
      trend: .stable
    )

    XCTAssertEqual(trend.min, trend.max)
    XCTAssertEqual(trend.average, 90.0)
  }

  func testTrend_WithLargeValues() {
    let trend = createTrend(
      values: [99999.0, 100000.0],
      min: 99999.0,
      max: 100000.0,
      average: 99999.5,
      count: 2
    )

    XCTAssertEqual(trend.max, 100000.0)
  }

  func testTrend_WithVerySmallValues() {
    let trend = createTrend(
      values: [0.001, 0.002],
      min: 0.001,
      max: 0.002,
      average: 0.0015,
      count: 2
    )

    XCTAssertEqual(trend.min, 0.001, accuracy: 0.0001)
  }

  // MARK: - Helper Methods

  private func createTrend(
    type: MetricType = .velocity,
    values: [Double] = [88.0, 89.0, 90.0],
    min: Double = 88.0,
    max: Double = 90.0,
    average: Double = 89.0,
    unit: String = "mph",
    count: Int = 3,
    trend: MetricTrend.TrendDirection = .improving
  ) -> MetricTrend {
    MetricTrend(
      type: type,
      values: values,
      min: min,
      max: max,
      average: average,
      unit: unit,
      count: count,
      trend: trend
    )
  }
}
