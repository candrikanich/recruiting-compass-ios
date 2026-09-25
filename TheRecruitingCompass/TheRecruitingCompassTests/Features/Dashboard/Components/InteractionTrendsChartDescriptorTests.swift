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

  func testUpdate_replacesContentsWithCurrentTrends() {
    let descriptor = InteractionTrendsChartDescriptor(trends: trends).makeChartDescriptor()

    InteractionTrendsChartDescriptor(trends: [trends[0]]).updateChartDescriptor(descriptor)

    XCTAssertEqual(descriptor.series.first?.dataPoints.count, 1)
    XCTAssertEqual(descriptor.summary, "3 total interactions over 1 days")
  }

  /// Buckets are "YYYY-MM-DD" + "T00:00:00Z"; west of UTC that instant is the previous
  /// local day, so the calendar day must come from the bucket string, not the instant.
  func testCalendarDay_matchesBucketDateWestOfUTC() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

    let day = trends[0].calendarDay(in: calendar)

    let parts = calendar.dateComponents([.year, .month, .day], from: day)
    XCTAssertEqual([parts.year, parts.month, parts.day], [2026, 2, 1])
  }

  func testDescriptor_summaryStatesTotal() {
    let descriptor = InteractionTrendsChartDescriptor(trends: trends).makeChartDescriptor()

    XCTAssertEqual(descriptor.summary, "10 total interactions over 3 days")
  }
}
