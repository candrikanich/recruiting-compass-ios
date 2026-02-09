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
}
