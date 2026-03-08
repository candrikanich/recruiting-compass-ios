import Foundation

enum COPPAHelper {
  /// Minimum age allowed to create an account (COPPA).
  static let minimumAge = 13

  private static let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f
  }()

  private static let fallbackFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  /// Returns true if the given date of birth indicates the user is under 13.
  /// - Parameter dateOfBirth: ISO8601 date string or "YYYY-MM-DD".
  static func isUnderAge(_ dateOfBirth: String) -> Bool {
    var date = iso8601Formatter.date(from: dateOfBirth)
    if date == nil {
      date = fallbackFormatter.date(from: dateOfBirth)
    }
    guard let dob = date else { return false }
    let calendar = Calendar.current
    let age = calendar.dateComponents([.year], from: dob, to: Date.now).year ?? 0
    return age < minimumAge
  }
}
