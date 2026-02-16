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
    case .velocity: return "Fastball Velocity"
    case .exitVelo: return "Exit Velocity"
    case .sixtyTime: return "60-Yard Dash"
    case .popTime: return "Pop Time"
    case .battingAvg: return "Batting Average"
    case .era: return "ERA"
    case .strikeouts: return "Strikeouts"
    case .other: return "Other Metric"
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
