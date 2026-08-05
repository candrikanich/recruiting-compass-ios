import Foundation

enum Sentiment: String, Codable, CaseIterable, Sendable {
  case veryPositive = "very_positive"
  case positive
  case neutral
  case negative

  var displayName: String {
    switch self {
    case .veryPositive: return "Very Positive"
    case .positive: return "Positive"
    case .neutral: return "Neutral"
    case .negative: return "Negative"
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .veryPositive: return .emerald
    case .positive:     return .blue
    case .neutral:      return .slate
    case .negative:     return .red
    }
  }

  var isPositive: Bool {
    self == .veryPositive || self == .positive
  }
}
