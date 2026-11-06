import Foundation

struct InteractionTrendSummary: Sendable {
  let trends: [InteractionTrend]
  /// Interactions inside the window.
  let total: Int
  /// Date of the most recent interaction passed in, in or out of the window.
  let lastInteractionDate: Date?

  static let empty = InteractionTrendSummary(trends: [], total: 0, lastInteractionDate: nil)
}

/// The dashboard trends card counts a rolling 30-calendar-day window (today inclusive, user's time zone),
/// matching the web card.
enum InteractionTrendWindow {
  static let days = 30

  static func windowStart(now: Date, calendar: Calendar = .current) -> Date {
    let today = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
  }

  static func summarize(
    _ interactions: [Interaction], now: Date = .now, calendar: Calendar = .current
  ) -> InteractionTrendSummary {
    let start = windowStart(now: now, calendar: calendar)
    let dated = interactions.map { $0.displayDate }
    let inWindow = dated.filter { $0 >= start }

    let byDay = Dictionary(grouping: inWindow) { dayKey($0, calendar: calendar) }
    let trends = byDay
      .map { key, dates in InteractionTrend(id: key, date: key + "T00:00:00Z", count: dates.count) }
      .sorted { $0.id < $1.id }

    return InteractionTrendSummary(trends: trends, total: inWindow.count, lastInteractionDate: dated.max())
  }

  private static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
