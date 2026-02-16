import XCTest
@testable import TheRecruitingCompass

final class RelativeTimeFormatterTests: XCTestCase {
  private let referenceDate = Date(timeIntervalSince1970: 1739620800) // 2025-02-15T12:00:00Z

  // MARK: - Just Now Tests

  func testJustNow_ZeroSeconds() {
    let result = RelativeTimeFormatter.format(referenceDate, relativeTo: referenceDate)
    XCTAssertEqual(result, "just now")
  }

  func testJustNow_30Seconds() {
    let date = referenceDate.addingTimeInterval(-30)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "just now")
  }

  func testJustNow_59Seconds() {
    let date = referenceDate.addingTimeInterval(-59)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "just now")
  }

  func testJustNow_FutureDate() {
    let futureDate = referenceDate.addingTimeInterval(60)
    let result = RelativeTimeFormatter.format(futureDate, relativeTo: referenceDate)
    XCTAssertEqual(result, "just now")
  }

  // MARK: - Minutes Ago Tests

  func testMinutesAgo_1Minute() {
    let date = referenceDate.addingTimeInterval(-60)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "1m ago")
  }

  func testMinutesAgo_30Minutes() {
    let date = referenceDate.addingTimeInterval(-1800)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "30m ago")
  }

  func testMinutesAgo_59Minutes() {
    let date = referenceDate.addingTimeInterval(-3540)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "59m ago")
  }

  // MARK: - Hours Ago Tests

  func testHoursAgo_1Hour() {
    let date = referenceDate.addingTimeInterval(-3600)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "1h ago")
  }

  func testHoursAgo_12Hours() {
    let date = referenceDate.addingTimeInterval(-43200)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "12h ago")
  }

  func testHoursAgo_23Hours() {
    let date = referenceDate.addingTimeInterval(-82800)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "23h ago")
  }

  // MARK: - Days Ago Tests

  func testDaysAgo_1Day() {
    let date = referenceDate.addingTimeInterval(-86400)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "1d ago")
  }

  func testDaysAgo_3Days() {
    let date = referenceDate.addingTimeInterval(-259200)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "3d ago")
  }

  func testDaysAgo_6Days() {
    let date = referenceDate.addingTimeInterval(-518400)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertEqual(result, "6d ago")
  }

  // MARK: - Formatted Date Tests (7+ days)

  func testFormattedDate_ExactlySevenDays() {
    let date = referenceDate.addingTimeInterval(-604800)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    // Should show month + day format, not "7d ago"
    XCTAssertFalse(result.contains("ago"))
    XCTAssertTrue(result.contains("Feb") || result.contains("8"))
  }

  func testFormattedDate_30DaysAgo() {
    let date = referenceDate.addingTimeInterval(-2592000)
    let result = RelativeTimeFormatter.format(date, relativeTo: referenceDate)
    XCTAssertFalse(result.contains("ago"))
    // Should be a month-day formatted string
    XCTAssertFalse(result.isEmpty)
  }

  // MARK: - Boundary Tests

  func testBoundary_59SecondsToMinutes() {
    let justUnder = referenceDate.addingTimeInterval(-59)
    let atBoundary = referenceDate.addingTimeInterval(-60)

    XCTAssertEqual(
      RelativeTimeFormatter.format(justUnder, relativeTo: referenceDate),
      "just now"
    )
    XCTAssertEqual(
      RelativeTimeFormatter.format(atBoundary, relativeTo: referenceDate),
      "1m ago"
    )
  }

  func testBoundary_59MinutesToHours() {
    let justUnder = referenceDate.addingTimeInterval(-3599)
    let atBoundary = referenceDate.addingTimeInterval(-3600)

    XCTAssertEqual(
      RelativeTimeFormatter.format(justUnder, relativeTo: referenceDate),
      "59m ago"
    )
    XCTAssertEqual(
      RelativeTimeFormatter.format(atBoundary, relativeTo: referenceDate),
      "1h ago"
    )
  }

  func testBoundary_23HoursToDays() {
    let justUnder = referenceDate.addingTimeInterval(-86399)
    let atBoundary = referenceDate.addingTimeInterval(-86400)

    XCTAssertEqual(
      RelativeTimeFormatter.format(justUnder, relativeTo: referenceDate),
      "23h ago"
    )
    XCTAssertEqual(
      RelativeTimeFormatter.format(atBoundary, relativeTo: referenceDate),
      "1d ago"
    )
  }

  func testBoundary_6DaysToFormatted() {
    let justUnder = referenceDate.addingTimeInterval(-604799) // 6d 23h 59m 59s
    let atBoundary = referenceDate.addingTimeInterval(-604800) // exactly 7 days

    let underResult = RelativeTimeFormatter.format(justUnder, relativeTo: referenceDate)
    let boundaryResult = RelativeTimeFormatter.format(atBoundary, relativeTo: referenceDate)

    XCTAssertTrue(underResult.contains("ago"))
    XCTAssertFalse(boundaryResult.contains("ago"))
  }

  // MARK: - Default Parameter Tests

  func testDefaultRelativeTo_UsesCurrentDate() {
    let recentDate = Date().addingTimeInterval(-30)
    let result = RelativeTimeFormatter.format(recentDate)
    XCTAssertEqual(result, "just now")
  }
}
