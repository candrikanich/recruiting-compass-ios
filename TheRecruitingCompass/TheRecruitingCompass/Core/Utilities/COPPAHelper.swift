import Foundation

enum COPPAHelper {
  /// Minimum age allowed to create an account (COPPA).
  static let minimumAge = 13

  /// Returns true if the given date of birth indicates the user is under 13.
  /// - Parameter dateOfBirth: ISO8601 date string or "YYYY-MM-DD".
  static func isUnderAge(_ dateOfBirth: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    var date = formatter.date(from: dateOfBirth)
    if date == nil {
      let fallback = DateFormatter()
      fallback.dateFormat = "yyyy-MM-dd"
      fallback.locale = Locale(identifier: "en_US_POSIX")
      date = fallback.date(from: dateOfBirth)
    }
    guard let dob = date else { return false }
    let calendar = Calendar.current
    let age = calendar.dateComponents([.year], from: dob, to: Date()).year ?? 0
    return age < minimumAge
  }
}
