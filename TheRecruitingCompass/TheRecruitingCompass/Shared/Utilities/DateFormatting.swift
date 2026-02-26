import Foundation

enum DateFormatting {
  private static let mediumDateShortTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private static let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  private static let mediumDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  static func mediumDateShortTime(_ date: Date) -> String {
    mediumDateShortTimeFormatter.string(from: date)
  }

  static func shortDate(_ date: Date) -> String {
    shortDateFormatter.string(from: date)
  }

  static func mediumDate(_ date: Date) -> String {
    mediumDateFormatter.string(from: date)
  }

  /// Shared formatter for ISO date export ("yyyy-MM-dd")
  static let isoExportFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  /// Converts an ISO date string ("yyyy-MM-dd") to a display string ("Apr 15, 2026")
  static func isoDateString(_ isoDate: String) -> String {
    let components = isoDate.split(separator: "-").compactMap { Int($0) }
    guard components.count == 3 else { return isoDate }
    let date = DateComponents(
      calendar: .current,
      year: components[0], month: components[1], day: components[2]
    ).date
    return date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? isoDate
  }

  /// Converts an ISO date range to "Apr 15, 2026" or "Apr 15 – Jun 5, 2026"
  static func isoDateRangeString(from startDate: String, to endDate: String?) -> String {
    let start = isoDateString(startDate)
    guard let endDate, endDate != startDate else { return start }
    let endComponents = endDate.split(separator: "-").compactMap { Int($0) }
    guard endComponents.count == 3,
          let end = DateComponents(
            calendar: .current,
            year: endComponents[0], month: endComponents[1], day: endComponents[2]
          ).date else { return "\(start) – \(isoDateString(endDate))" }
    return "\(start) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
  }
}
