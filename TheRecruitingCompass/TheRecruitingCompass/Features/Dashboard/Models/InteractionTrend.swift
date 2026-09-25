import Foundation

struct InteractionTrend: Codable, Identifiable, Sendable {
  let id: String
  let date: String
  let count: Int

  /// `date` is a UTC day bucket ("YYYY-MM-DD" + "T00:00:00Z"). Reading that instant in a
  /// time zone west of UTC lands on the previous day, so build the day from the bucket's
  /// calendar components instead.
  func calendarDay(in calendar: Calendar = .current) -> Date {
    let parts = date.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
          let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    else { return .now }
    return day
  }
}
