import XCTest
@testable import TheRecruitingCompass

final class COPPAHelperTests: XCTestCase {

  // Fixed clock and zone: the suite must not depend on the machine's TZ or wall clock.
  private let calendar = COPPAHelperTests.calendar(in: "UTC")
  private lazy var now = instant(2026, 10, 21, 12, 0, in: calendar)

  private static func calendar(in zoneID: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zoneID)!
    return calendar
  }

  private func instant(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, in calendar: Calendar
  ) -> Date {
    calendar.date(from: DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  private func dobString(yearsAgo: Int, extraDays: Int = 0) -> String {
    let dob = calendar.date(byAdding: .year, value: -yearsAgo, to: now)!
    let adjusted = calendar.date(byAdding: .day, value: extraDays, to: dob)!
    let parts = calendar.dateComponents([.year, .month, .day], from: adjusted)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  private func isUnderAge(_ dob: String) -> Bool {
    COPPAHelper.isUnderAge(dob, now: now, calendar: calendar)
  }

  private func requiresGuardianInvite(_ dob: String) -> Bool {
    COPPAHelper.requiresGuardianInvite(dob, now: now, calendar: calendar)
  }

  func testIsUnderAge_TwelveYearsOld_IsUnderAge() {
    XCTAssertTrue(isUnderAge(dobString(yearsAgo: 12)))
  }

  func testIsUnderAge_FourteenYearsOld_IsNotUnderAge() {
    XCTAssertFalse(isUnderAge(dobString(yearsAgo: 14)))
  }

  func testIsUnderAge_ThirteenthBirthdayToday_IsNotUnderAge() {
    XCTAssertFalse(isUnderAge(dobString(yearsAgo: 13)))
  }

  func testIsUnderAge_OneDayBeforeThirteenthBirthday_IsUnderAge() {
    XCTAssertTrue(isUnderAge(dobString(yearsAgo: 13, extraDays: 1)))
  }

  func testIsUnderAge_ISO8601FullDate_Parses() {
    XCTAssertTrue(isUnderAge(dobString(yearsAgo: 10)))
    XCTAssertFalse(isUnderAge("2000-01-15"))
  }

  func testIsUnderAge_UnparseableDOB_FailsClosed() {
    XCTAssertTrue(isUnderAge("not-a-date"), "Unparseable DOB must be treated as under-age (fail closed)")
    XCTAssertTrue(isUnderAge(""), "Empty DOB must be treated as under-age (fail closed)")
    XCTAssertTrue(isUnderAge("13"), "Bare number must be treated as under-age (fail closed)")
  }

  // MARK: - requiresGuardianInvite (13-17 band)

  func testRequiresGuardianInvite_Under13_IsFalse() {
    XCTAssertFalse(requiresGuardianInvite(dobString(yearsAgo: 10)))
  }

  func testRequiresGuardianInvite_ThirteenToSeventeen_IsTrue() {
    XCTAssertTrue(requiresGuardianInvite(dobString(yearsAgo: 13)))
    XCTAssertTrue(requiresGuardianInvite(dobString(yearsAgo: 15)))
    XCTAssertTrue(requiresGuardianInvite(dobString(yearsAgo: 17)))
  }

  func testRequiresGuardianInvite_EighteenAndOver_IsFalse() {
    XCTAssertFalse(requiresGuardianInvite(dobString(yearsAgo: 18)))
    XCTAssertFalse(requiresGuardianInvite(dobString(yearsAgo: 25)))
  }

  func testRequiresGuardianInvite_UnparseableDOB_IsFalse() {
    XCTAssertFalse(requiresGuardianInvite("not-a-date"))
    XCTAssertFalse(requiresGuardianInvite(""))
  }

  // MARK: - Boundary across time zones (ios#435)

  private static let zones = [
    "America/Los_Angeles", "America/New_York", "UTC", "Pacific/Kiritimati", "Pacific/Honolulu"
  ]
  private static let localTimes = [(0, 1), (12, 0), (23, 59)]

  /// DOB 2013-06-15 turns 13 and 18 on the 2026/2031 anniversaries; the day before, still 12/17.
  private func assertBoundary(
    dob: String, birthday: (Int, Int, Int), underAt: (Int, Int, Int),
    check: (String, Date, Calendar) -> Bool, expectedBefore: Bool,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    for zone in Self.zones {
      let cal = Self.calendar(in: zone)
      for (hour, minute) in Self.localTimes {
        let before = instant(underAt.0, underAt.1, underAt.2, hour, minute, in: cal)
        let onDay = instant(birthday.0, birthday.1, birthday.2, hour, minute, in: cal)
        let label = "\(zone) \(hour):\(minute)"
        XCTAssertEqual(check(dob, before, cal), expectedBefore, "\(label) day before", file: file, line: line)
        XCTAssertEqual(check(dob, onDay, cal), !expectedBefore, "\(label) birthday", file: file, line: line)
      }
    }
  }

  func testIsUnderAge_BoundaryAcrossTimeZones_DayBeforeIsUnder_BirthdayIsNot() {
    assertBoundary(
      dob: "2013-06-15", birthday: (2026, 6, 15), underAt: (2026, 6, 14),
      check: { COPPAHelper.isUnderAge($0, now: $1, calendar: $2) }, expectedBefore: true)
  }

  func testRequiresGuardianInvite_BoundaryAtEighteenAcrossTimeZones() {
    assertBoundary(
      dob: "2008-06-15", birthday: (2026, 6, 15), underAt: (2026, 6, 14),
      check: { COPPAHelper.requiresGuardianInvite($0, now: $1, calendar: $2) }, expectedBefore: true)
  }

  func testIsUnderAge_LosAngelesEveningBeforeThirteenthBirthday_IsUnderAge() {
    let cal = Self.calendar(in: "America/Los_Angeles")
    let eveningBefore = instant(2026, 6, 14, 23, 30, in: cal)
    XCTAssertTrue(COPPAHelper.isUnderAge("2013-06-15", now: eveningBefore, calendar: cal))
    let birthdayMorning = instant(2026, 6, 15, 0, 1, in: cal)
    XCTAssertFalse(COPPAHelper.isUnderAge("2013-06-15", now: birthdayMorning, calendar: cal))
  }

  func testIsUnderAge_LeapDayBirthday_TurnsThirteenOnMarchFirstInNonLeapYear() {
    let cal = Self.calendar(in: "UTC")
    XCTAssertTrue(COPPAHelper.isUnderAge("2012-02-29", now: instant(2025, 2, 28, 12, 0, in: cal), calendar: cal))
    XCTAssertFalse(COPPAHelper.isUnderAge("2012-02-29", now: instant(2025, 3, 1, 0, 1, in: cal), calendar: cal))
  }

  func testIsUnderAge_InvalidCalendarDate_FailsClosed() {
    XCTAssertTrue(isUnderAge("2000-02-30"))
    XCTAssertTrue(isUnderAge("2000-13-01"))
  }

  // MARK: - Non-Gregorian device calendars (age-gate bypass)

  private static let nonGregorian: [(Calendar.Identifier, String)] = [
    (.buddhist, "th_TH"), (.japanese, "ja_JP"), (.islamicUmmAlQura, "ar_SA"), (.republicOfChina, "zh_TW")
  ]

  func testIsUnderAge_NonGregorianDeviceCalendar_StillGatesAtThirteen() {
    for (identifier, localeID) in Self.nonGregorian {
      var cal = Calendar(identifier: identifier)
      cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
      cal.locale = Locale(identifier: localeID)
      let gregorian = Self.calendar(in: "America/Los_Angeles")
      let birthdayNoon = instant(2026, 6, 15, 12, 0, in: gregorian)
      let dayBefore = instant(2026, 6, 14, 12, 0, in: gregorian)
      XCTAssertTrue(COPPAHelper.isUnderAge("2013-06-15", now: dayBefore, calendar: cal), "\(identifier) 12yo")
      XCTAssertFalse(COPPAHelper.isUnderAge("2013-06-15", now: birthdayNoon, calendar: cal), "\(identifier) 13yo")
      XCTAssertTrue(COPPAHelper.requiresGuardianInvite("2013-06-15", now: birthdayNoon, calendar: cal))
      XCTAssertFalse(COPPAHelper.requiresGuardianInvite("2008-06-15", now: birthdayNoon, calendar: cal))
    }
  }

  func testIsUnderAge_SignedOrPaddedComponents_FailClosed() {
    for dob in ["+201-01-01", " 2010-01-01", "2010-+1-01", "2010-01-+1", "-201-01-01", "2010-01-01 "] {
      XCTAssertTrue(isUnderAge(dob), "\(dob) must fail closed")
    }
  }

  func testDateOfBirthFormatter_NonGregorianLocale_WritesGregorianYear() {
    let gregorian = Self.calendar(in: TimeZone.current.identifier)
    let date = instant(2013, 6, 15, 12, 0, in: gregorian)
    XCTAssertEqual(COPPAHelper.makeDateOfBirthFormatter().string(from: date), "2013-06-15")
  }
}
