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
    case .battingAvg: return "avg"
    case .era: return "era"
    case .strikeouts: return "K"
    case .other: return ""
    }
  }

  var isLowerBetter: Bool {
    self == .sixtyTime || self == .popTime || self == .era
  }
}
