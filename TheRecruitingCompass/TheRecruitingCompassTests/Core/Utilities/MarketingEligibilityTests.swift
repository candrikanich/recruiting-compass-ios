import XCTest
@testable import TheRecruitingCompass

/// Mirrors web `isMarketingEligible` (#1066): parents by role, players only when an
/// entered DOB makes them 18+. A missing player DOB fails closed.
final class MarketingEligibilityTests: XCTestCase {
  private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/New_York")!
    return cal
  }

  private var now: Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9, minute: 30))!
  }

  private func dob(yearsAgo years: Int, dayOffset: Int = 0, hour: Int = 0) -> Date {
    let today = calendar.startOfDay(for: now)
    let base = calendar.date(byAdding: .year, value: -years, to: today)!
    let shifted = calendar.date(byAdding: .day, value: dayOffset, to: base)!
    return calendar.date(byAdding: .hour, value: hour, to: shifted)!
  }

  private func eligible(_ role: UserRole?, _ dateOfBirth: Date?) -> Bool {
    MarketingEligibility.isEligible(role: role, dateOfBirth: dateOfBirth, now: now, calendar: calendar)
  }

  func test_parent_withNilDOB_isEligible() {
    XCTAssertTrue(eligible(.parent, nil))
  }

  func test_parent_ignoresDOB() {
    XCTAssertTrue(eligible(.parent, dob(yearsAgo: 15)))
  }

  func test_player_turning18Today_isEligible() {
    XCTAssertTrue(eligible(.player, dob(yearsAgo: 18)))
  }

  func test_player_turning18Today_withLaterTimeOfDay_isEligible() {
    // DatePicker keeps the initial value's time-of-day; a birthday later today must still count.
    XCTAssertTrue(eligible(.player, dob(yearsAgo: 18, hour: 23)))
  }

  func test_player_turning18Tomorrow_isNotEligible() {
    XCTAssertFalse(eligible(.player, dob(yearsAgo: 18, dayOffset: 1)))
  }

  func test_player_17_isNotEligible() {
    XCTAssertFalse(eligible(.player, dob(yearsAgo: 17)))
  }

  func test_player_adult_isEligible() {
    XCTAssertTrue(eligible(.player, dob(yearsAgo: 30)))
  }

  func test_player_nilDOB_isNotEligible() {
    XCTAssertFalse(eligible(.player, nil))
  }

  func test_nilRole_isNotEligible() {
    XCTAssertFalse(eligible(nil, dob(yearsAgo: 30)))
  }
}
