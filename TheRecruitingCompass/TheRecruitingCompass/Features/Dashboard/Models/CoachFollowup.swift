import Foundation

/// Pure follow-up logic for the dashboard "Coaches Needing Follow-up" widget.
/// Web parity: a coach needs follow-up when never contacted, or last contacted
/// more than `defaultThresholdDays` (14) ago. Kept side-effect free for testing.
enum CoachFollowup {
  static let defaultThresholdDays = 14

  static func needsFollowup(
    _ coach: Coach, asOf now: Date, thresholdDays: Int = defaultThresholdDays
  ) -> Bool {
    guard let last = coach.lastContactDateParsed else { return true }
    guard let cutoff = Calendar.current.date(byAdding: .day, value: -thresholdDays, to: now)
    else { return true }
    return last < cutoff
  }

  /// Coaches needing follow-up, sorted never-contacted first then oldest contact first.
  static func stale(
    _ coaches: [Coach], asOf now: Date, thresholdDays: Int = defaultThresholdDays
  ) -> [Coach] {
    coaches
      .filter { needsFollowup($0, asOf: now, thresholdDays: thresholdDays) }
      .sorted { a, b in
        switch (a.lastContactDateParsed, b.lastContactDateParsed) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (x?, y?): return x < y
        }
      }
  }

  static func daysSinceLabel(_ coach: Coach, asOf now: Date) -> String {
    guard let last = coach.lastContactDateParsed else {
      return String(localized: "Never contacted")
    }
    let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
    switch days {
    case ..<1: return String(localized: "Today")
    case 1: return String(localized: "1 day ago")
    default: return String(localized: "\(days) days ago")
    }
  }
}
