import Foundation

/// Event times are stored as Postgres `time` ("14:30:00") and written as 24-hour "HH:mm".
/// Display is a fixed en_US "h:mm a" like the web app, so a family sees the same text on both platforms.
enum TimeOfDay {
  /// 12-hour text for a stored time. nil/empty -> nil (show nothing); unparseable -> unchanged.
  nonisolated static func display(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }
    guard let date = parse(raw) else { return raw }
    return formatter("h:mm a").string(from: date)
  }

  /// "HH:mm" for a stored time ("HH:mm:ss" accepted); unparseable is returned unchanged.
  nonisolated static func normalized(_ raw: String) -> String {
    parse(raw).map { formatter("HH:mm").string(from: $0) } ?? raw
  }

  /// A Date whose local hour and minute match the stored time, for an hour-and-minute DatePicker.
  nonisolated static func pickerDate(from raw: String) -> Date? {
    guard let parsed = parse(raw) else { return nil }
    let parts = utcCalendar.dateComponents([.hour, .minute], from: parsed)
    return Calendar.current.date(
      bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()
    )
  }

  /// 24-hour "HH:mm" in the user's calendar, matching what the DatePicker shows.
  nonisolated static func string(from pickerDate: Date) -> String {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: pickerDate)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
  }

  // GMT keeps parsing independent of the device's DST rules (e.g. a nonexistent 02:30).
  private nonisolated static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }

  private nonisolated static func formatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = utcCalendar
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.isLenient = false
    formatter.dateFormat = format
    return formatter
  }

  private nonisolated static func parse(_ raw: String) -> Date? {
    ["HH:mm:ss", "HH:mm"].lazy.compactMap { formatter($0).date(from: raw) }.first
  }
}
