import Foundation

enum MetricType: String, Codable, CaseIterable, Identifiable {
  case velocity = "velocity"
  case exitVelo = "exit_velo"
  case sixtyTime = "sixty_time"
  case popTime = "pop_time"
  case battingAvg = "batting_avg"
  case era = "era"
  case strikeouts = "strikeouts"
  case other = "other"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .velocity: return String(localized: "Fastball Velocity")
    case .exitVelo: return String(localized: "Exit Velocity")
    case .sixtyTime: return String(localized: "60-Yard Dash")
    case .popTime: return String(localized: "Pop Time")
    case .battingAvg: return String(localized: "Batting Average")
    case .era: return String(localized: "ERA")
    case .strikeouts: return String(localized: "Strikeouts")
    case .other: return String(localized: "Other Metric")
    }
  }

  var defaultUnit: String {
    switch self {
    case .velocity, .exitVelo: return "mph"
    case .sixtyTime, .popTime: return "sec"
    case .battingAvg, .era: return ""
    case .strikeouts: return "count"
    case .other: return ""
    }
  }

  var isLowerBetter: Bool {
    self == .sixtyTime || self == .popTime || self == .era
  }

  /// Decimal places this metric renders at. Batting average and ERA are 3/2-decimal rate
  /// stats; velocities read to a tenth; times to a hundredth; strikeouts are whole.
  private var fractionDigits: Int {
    switch self {
    case .battingAvg: return 3
    case .era, .sixtyTime, .popTime, .other: return 2
    case .velocity, .exitVelo: return 1
    case .strikeouts: return 0
    }
  }

  /// Baseball convention: batting average drops the leading zero (`.410`), so `<1` reads as a
  /// pure fraction. Every other rate keeps its leading digit (ERA `3.45`, `1.000` stays).
  private var dropsLeadingZero: Bool { self == .battingAvg }

  /// Format a raw metric value to its display string (number only — callers append the unit).
  /// Parity with web `formatMetricValue`; keep the two in sync.
  func format(_ value: Double) -> String {
    let s = String(format: "%.\(fractionDigits)f", value)
    if dropsLeadingZero, s.hasPrefix("0.") { return String(s.dropFirst()) }
    return s
  }

  /// The unit is fixed (locked to `defaultUnit`) for every type except `.other`,
  /// which lets the athlete pick from the shared vocabulary. Mirrors the web
  /// log-metric modal — no user-typed units.
  var unitIsFixed: Bool { self != .other }

  /// Fixed unit vocabulary offered for `.other` (value stored as-is). Mirrors the
  /// web modal's unit dropdown so cross-platform units stay consistent.
  static let unitVocabulary: [String] = ["", "mph", "sec", "in", "ft", "lbs", "count", "%"]
}
