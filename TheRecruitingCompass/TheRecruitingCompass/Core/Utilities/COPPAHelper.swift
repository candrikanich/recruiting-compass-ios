import Foundation

enum COPPAHelper {
  /// Minimum age allowed to create an account (COPPA).
  static let minimumAge = 13

  /// Age at which a player may hold a standalone (unsupervised) account.
  static let adultAge = 18

  /// Whole years elapsed between a date of birth and `now`.
  static func age(fromDateOfBirth dob: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
    calendar.dateComponents([.year], from: dob, to: now).year ?? 0
  }

  /// Whole years between a `YYYY-MM-DD` (or ISO8601 date-time) date of birth and `now`, or nil when the string is not
  /// a real calendar date. A DOB is a calendar date, not an instant: it is compared with today's date in
  /// `calendar` field by field, so no time zone can shift the birthday (mirrors web's `ageFromDateOfBirth`).
  static func age(fromDateOfBirth dateOfBirth: String, now: Date = .now, calendar: Calendar = .current) -> Int? {
    guard let dob = dateComponents(from: dateOfBirth) else { return nil }
    let today = calendar.dateComponents([.year, .month, .day], from: now)
    guard let year = today.year, let month = today.month, let day = today.day else { return nil }
    let birthdayPassed = (month, day) >= (dob.month, dob.day)
    return year - dob.year - (birthdayPassed ? 0 : 1)
  }

  /// Returns true if the given date of birth indicates the user is under 13.
  /// Fails closed: a date string that is not a real calendar date is treated as under-age,
  /// so a malformed DOB can never bypass the age gate.
  /// - Parameter dateOfBirth: "YYYY-MM-DD", optionally followed by a time part (ISO8601).
  static func isUnderAge(_ dateOfBirth: String, now: Date = .now, calendar: Calendar = .current) -> Bool {
    guard let years = age(fromDateOfBirth: dateOfBirth, now: now, calendar: calendar) else { return true }
    return years < minimumAge
  }

  /// Returns true when the date of birth indicates ages 13-17 (inclusive) — a minor
  /// who may use the app only through a parent/guardian family invite, never a
  /// standalone signup. Returns false for unparseable dates (the under-13 gate
  /// handles those); the app's DOB comes from a date picker, so dates are well-formed.
  /// - Parameter dateOfBirth: "YYYY-MM-DD", optionally followed by a time part (ISO8601).
  static func requiresGuardianInvite(_ dateOfBirth: String, now: Date = .now, calendar: Calendar = .current) -> Bool {
    guard let years = age(fromDateOfBirth: dateOfBirth, now: now, calendar: calendar) else { return false }
    return years >= minimumAge && years < adultAge
  }

  private static func dateComponents(from string: String) -> (year: Int, month: Int, day: Int)? {
    let parts = string.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, string.count == 10 || string.dropFirst(10).first == "T",
          parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
    else { return nil }
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = TimeZone(identifier: "UTC")!
    let components = DateComponents(year: year, month: month, day: day)
    guard let date = gregorian.date(from: components) else { return nil }
    let roundTrip = gregorian.dateComponents([.year, .month, .day], from: date)
    guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else { return nil }
    return (year, month, day)
  }
}
