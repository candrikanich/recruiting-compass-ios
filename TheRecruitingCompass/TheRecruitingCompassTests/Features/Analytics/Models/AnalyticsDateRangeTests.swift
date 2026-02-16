import XCTest
@testable import TheRecruitingCompass

final class AnalyticsDateRangeTests: XCTestCase {

  // MARK: - Display Name Tests

  func testDisplayName_Last7Days() {
    XCTAssertEqual(AnalyticsDateRange.last7Days.displayName, "Last 7 Days")
  }

  func testDisplayName_Last30Days() {
    XCTAssertEqual(AnalyticsDateRange.last30Days.displayName, "Last 30 Days")
  }

  func testDisplayName_Last90Days() {
    XCTAssertEqual(AnalyticsDateRange.last90Days.displayName, "Last 90 Days")
  }

  func testDisplayName_Custom() {
    let start = Date()
    let end = Date()
    XCTAssertEqual(AnalyticsDateRange.custom(start: start, end: end).displayName, "Custom Range")
  }

  // MARK: - Start Date Tests

  func testStartDate_Last7Days_Is7DaysAgo() {
    let range = AnalyticsDateRange.last7Days
    let expected = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    let difference = abs(range.startDate.timeIntervalSince(expected))

    XCTAssertLessThan(difference, 1.0)
  }

  func testStartDate_Last30Days_Is30DaysAgo() {
    let range = AnalyticsDateRange.last30Days
    let expected = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    let difference = abs(range.startDate.timeIntervalSince(expected))

    XCTAssertLessThan(difference, 1.0)
  }

  func testStartDate_Last90Days_Is90DaysAgo() {
    let range = AnalyticsDateRange.last90Days
    let expected = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
    let difference = abs(range.startDate.timeIntervalSince(expected))

    XCTAssertLessThan(difference, 1.0)
  }

  func testStartDate_Custom_ReturnsProvidedStart() {
    let start = Date(timeIntervalSince1970: 1000000)
    let end = Date(timeIntervalSince1970: 2000000)
    let range = AnalyticsDateRange.custom(start: start, end: end)

    XCTAssertEqual(range.startDate, start)
  }

  // MARK: - End Date Tests

  func testEndDate_Last7Days_IsNow() {
    let range = AnalyticsDateRange.last7Days
    let difference = abs(range.endDate.timeIntervalSinceNow)

    XCTAssertLessThan(difference, 1.0)
  }

  func testEndDate_Last30Days_IsNow() {
    let range = AnalyticsDateRange.last30Days
    let difference = abs(range.endDate.timeIntervalSinceNow)

    XCTAssertLessThan(difference, 1.0)
  }

  func testEndDate_Last90Days_IsNow() {
    let range = AnalyticsDateRange.last90Days
    let difference = abs(range.endDate.timeIntervalSinceNow)

    XCTAssertLessThan(difference, 1.0)
  }

  func testEndDate_Custom_ReturnsProvidedEnd() {
    let start = Date(timeIntervalSince1970: 1000000)
    let end = Date(timeIntervalSince1970: 2000000)
    let range = AnalyticsDateRange.custom(start: start, end: end)

    XCTAssertEqual(range.endDate, end)
  }

  // MARK: - Query Date String Tests

  func testQueryStartDate_FormatsCorrectly() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let range = AnalyticsDateRange.last30Days
    let expected = formatter.string(from: range.startDate)

    XCTAssertEqual(range.queryStartDate, expected)
  }

  func testQueryEndDate_FormatsCorrectly() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let range = AnalyticsDateRange.last30Days
    let expected = formatter.string(from: range.endDate)

    XCTAssertEqual(range.queryEndDate, expected)
  }

  func testQueryDates_CustomRange_FormatCorrectly() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let start = formatter.date(from: "2026-01-01")!
    let end = formatter.date(from: "2026-01-31")!

    let range = AnalyticsDateRange.custom(start: start, end: end)

    XCTAssertEqual(range.queryStartDate, "2026-01-01")
    XCTAssertEqual(range.queryEndDate, "2026-01-31")
  }

  // MARK: - All Presets Tests

  func testAllPresets_ContainsThreeItems() {
    XCTAssertEqual(AnalyticsDateRange.allPresets.count, 3)
  }

  func testAllPresets_ContainsExpectedRanges() {
    let presets = AnalyticsDateRange.allPresets

    XCTAssertEqual(presets[0], .last7Days)
    XCTAssertEqual(presets[1], .last30Days)
    XCTAssertEqual(presets[2], .last90Days)
  }

  // MARK: - Equatable Tests

  func testEquatable_SamePresets() {
    XCTAssertEqual(AnalyticsDateRange.last7Days, AnalyticsDateRange.last7Days)
    XCTAssertEqual(AnalyticsDateRange.last30Days, AnalyticsDateRange.last30Days)
    XCTAssertEqual(AnalyticsDateRange.last90Days, AnalyticsDateRange.last90Days)
  }

  func testEquatable_DifferentPresets() {
    XCTAssertNotEqual(AnalyticsDateRange.last7Days, AnalyticsDateRange.last30Days)
    XCTAssertNotEqual(AnalyticsDateRange.last30Days, AnalyticsDateRange.last90Days)
  }

  func testEquatable_CustomWithSameDates() {
    let date1 = Date(timeIntervalSince1970: 1000000)
    let date2 = Date(timeIntervalSince1970: 2000000)

    let range1 = AnalyticsDateRange.custom(start: date1, end: date2)
    let range2 = AnalyticsDateRange.custom(start: date1, end: date2)

    XCTAssertEqual(range1, range2)
  }

  func testEquatable_CustomWithDifferentDates() {
    let range1 = AnalyticsDateRange.custom(start: Date(timeIntervalSince1970: 1000000), end: Date(timeIntervalSince1970: 2000000))
    let range2 = AnalyticsDateRange.custom(start: Date(timeIntervalSince1970: 3000000), end: Date(timeIntervalSince1970: 4000000))

    XCTAssertNotEqual(range1, range2)
  }

  func testEquatable_PresetVsCustom() {
    let range1 = AnalyticsDateRange.last7Days
    let range2 = AnalyticsDateRange.custom(start: Date(), end: Date())

    XCTAssertNotEqual(range1, range2)
  }

  // MARK: - Date Range Validity Tests

  func testStartDate_IsBeforeEndDate_ForAllPresets() {
    for preset in AnalyticsDateRange.allPresets {
      XCTAssertLessThan(preset.startDate, preset.endDate, "Start should be before end for \(preset.displayName)")
    }
  }

  func testStartDate_DurationDifferences() {
    let last7 = AnalyticsDateRange.last7Days
    let last30 = AnalyticsDateRange.last30Days
    let last90 = AnalyticsDateRange.last90Days

    let duration7 = last7.endDate.timeIntervalSince(last7.startDate)
    let duration30 = last30.endDate.timeIntervalSince(last30.startDate)
    let duration90 = last90.endDate.timeIntervalSince(last90.startDate)

    XCTAssertLessThan(duration7, duration30)
    XCTAssertLessThan(duration30, duration90)
  }
}
