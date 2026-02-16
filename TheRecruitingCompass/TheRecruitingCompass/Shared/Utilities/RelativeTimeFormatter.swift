import Foundation

enum RelativeTimeFormatter {
  static func format(_ date: Date, relativeTo now: Date = Date()) -> String {
    let seconds = now.timeIntervalSince(date)

    guard seconds >= 0 else { return "just now" }

    if seconds < 60 { return "just now" }
    if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
    if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }

    return date.formatted(.dateTime.month(.abbreviated).day())
  }
}
