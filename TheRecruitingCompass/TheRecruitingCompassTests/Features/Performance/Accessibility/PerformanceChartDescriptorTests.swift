import XCTest
import Accessibility
@testable import TheRecruitingCompass

@MainActor
final class PerformanceChartDescriptorTests: XCTestCase {
  nonisolated deinit {}

  private let baseDate = Date(timeIntervalSince1970: 1_780_000_000)

  private func makeMetric(id: String, value: Double, daysOffset: Int, unit: String = "mph") -> PerformanceMetric {
    PerformanceMetric(
      id: id,
      userId: "test-user",
      metricType: .velocity,
      value: value,
      unit: unit,
      recordedDate: baseDate.addingTimeInterval(Double(daysOffset) * 86_400),
      eventId: nil,
      verified: false,
      notes: nil,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  private var metrics: [PerformanceMetric] {
    [
      makeMetric(id: "a", value: 84, daysOffset: 0),
      makeMetric(id: "b", value: 88, daysOffset: 7),
      makeMetric(id: "c", value: 86, daysOffset: 14)
    ]
  }

  // MARK: - Chart descriptor (VoiceOver Audio Graph)

  func testDescriptor_titleNamesMetricType() {
    let descriptor = PerformanceChartDescriptor(metrics: metrics, metricType: .velocity).makeChartDescriptor()

    XCTAssertEqual(descriptor.title, MetricType.velocity.displayName)
  }

  func testDescriptor_fallsBackToGenericTitleWithoutMetricType() {
    let descriptor = PerformanceChartDescriptor(metrics: metrics, metricType: nil).makeChartDescriptor()

    XCTAssertEqual(descriptor.title, "Performance")
  }

  func testDescriptor_hasOneContinuousSeriesWithEveryPoint() {
    let descriptor = PerformanceChartDescriptor(metrics: metrics, metricType: .velocity).makeChartDescriptor()

    XCTAssertEqual(descriptor.series.count, 1)
    XCTAssertTrue(descriptor.series[0].isContinuous)
    XCTAssertEqual(descriptor.series[0].dataPoints.count, 3)
    XCTAssertEqual(PerformanceChartDescriptor(metrics: metrics, metricType: .velocity).points.map(\.y), [84, 88, 86])
  }

  func testDescriptor_yAxisSpansValueRange() {
    let descriptor = PerformanceChartDescriptor(metrics: metrics, metricType: .velocity).makeChartDescriptor()

    XCTAssertEqual(descriptor.yAxis?.range, 84...88)
  }

  func testDescriptor_singleValueStillHasNonEmptyRange() throws {
    let flat = [makeMetric(id: "a", value: 90, daysOffset: 0), makeMetric(id: "b", value: 90, daysOffset: 1)]
    let descriptor = PerformanceChartDescriptor(metrics: flat, metricType: .velocity).makeChartDescriptor()

    let range = try XCTUnwrap(descriptor.yAxis?.range)
    XCTAssertLessThan(range.lowerBound, range.upperBound)
  }

  func testDescriptor_pointsAreChronological() {
    let shuffled = [metrics[2], metrics[0], metrics[1]]
    let xs = PerformanceChartDescriptor(metrics: shuffled, metricType: .velocity).points.map(\.x)
    XCTAssertEqual(xs, xs.sorted())
  }

  func testUpdate_replacesContentsWithCurrentMetrics() {
    let descriptor = PerformanceChartDescriptor(metrics: metrics, metricType: .velocity).makeChartDescriptor()

    PerformanceChartDescriptor(metrics: Array(metrics.prefix(2)), metricType: .exitVelo)
      .updateChartDescriptor(descriptor)

    XCTAssertEqual(descriptor.series.first?.dataPoints.count, 2)
    XCTAssertEqual(descriptor.title, MetricType.exitVelo.displayName)
  }

  func testMixedUnits_eachPointAnnouncesItsOwnUnit() {
    let mixed = [
      makeMetric(id: "a", value: 5, daysOffset: 0, unit: "sec"),
      makeMetric(id: "b", value: 90, daysOffset: 1, unit: "mph")
    ]
    let descriptor = PerformanceChartDescriptor(metrics: mixed, metricType: .other).makeChartDescriptor()

    let labels = descriptor.series[0].dataPoints.map { $0.label ?? "" }
    XCTAssertTrue(labels[0].hasSuffix("sec"))
    XCTAssertTrue(labels[1].hasSuffix("mph"))
  }

  // MARK: - Tap-to-inspect selection

  func testNearestMetric_picksClosestDate() {
    let tapped = baseDate.addingTimeInterval(8 * 86_400)

    XCTAssertEqual(PerformanceChartDescriptor.nearestMetric(to: tapped, in: metrics)?.id, "b")
  }

  func testNearestMetric_emptyReturnsNil() {
    XCTAssertNil(PerformanceChartDescriptor.nearestMetric(to: baseDate, in: []))
  }
}
