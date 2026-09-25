import XCTest
import Accessibility
@testable import TheRecruitingCompass

@MainActor
final class InteractionTrendsChartDescriptorTests: XCTestCase {
  nonisolated deinit {}

  private let trends = [
    InteractionTrend(id: "1", date: "2026-02-01T12:00:00Z", count: 3),
    InteractionTrend(id: "2", date: "2026-02-02T12:00:00Z", count: 0),
    InteractionTrend(id: "3", date: "2026-02-03T12:00:00Z", count: 7)
  ]

  func testDescriptor_hasOneDiscreteSeriesWithDailyCounts() {
    let descriptor = InteractionTrendsChartDescriptor(trends: trends).makeChartDescriptor()

    XCTAssertEqual(descriptor.series.count, 1)
    XCTAssertFalse(descriptor.series[0].isContinuous)
    XCTAssertEqual(descriptor.series[0].dataPoints.count, 3)
    XCTAssertEqual(InteractionTrendsChartDescriptor(trends: trends).counts, [3, 0, 7])
  }

  func testDescriptor_yAxisStartsAtZeroAndCoversMax() {
    let descriptor = InteractionTrendsChartDescriptor(trends: trends).makeChartDescriptor()

    XCTAssertEqual(descriptor.yAxis?.range, 0...7)
  }

  func testDescriptor_allZeroCountsStillHasNonEmptyRange() throws {
    let empty = [InteractionTrend(id: "1", date: "2026-02-01T12:00:00Z", count: 0)]
    let descriptor = InteractionTrendsChartDescriptor(trends: empty).makeChartDescriptor()

    let range = try XCTUnwrap(descriptor.yAxis?.range)
    XCTAssertLessThan(range.lowerBound, range.upperBound)
  }

  func testDescriptor_summaryStatesTotal() {
    let descriptor = InteractionTrendsChartDescriptor(trends: trends).makeChartDescriptor()

    XCTAssertEqual(descriptor.summary, "10 total interactions over 3 days")
  }
}
