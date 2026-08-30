import Foundation

/// Formats a past date as a compact relative string floored at minutes (never seconds).
enum RelativeTimeFormatter {
  static func string(from date: Date, relativeTo now: Date = .now) -> String {
    let interval = now.timeIntervalSince(date)
    guard interval >= 0 else { return "just now" }

    let minutes = Int(interval / 60)
    let hours = minutes / 60
    let days = hours / 24
    let weeks = days / 7
    let months = days / 30
    let years = days / 365

    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes)m ago" }
    if hours < 24 { return "\(hours)h ago" }
    if days < 7 { return "\(days)d ago" }
    if weeks < 5 { return "\(weeks)w ago" }
    if months < 12 { return "\(months)mo ago" }
    return "\(years)y ago"
  }
}
