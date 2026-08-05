import Foundation

/// Tier classification for fit score
enum FitTier: String, Codable, CaseIterable, Sendable {
  case reach
  case match
  case safety
  case unlikely

  /// Tier thresholds mirror the web app's classification.
  init(score: Double) {
    switch score {
    case 80...: self = .safety
    case 60..<80: self = .match
    case 40..<60: self = .reach
    default: self = .unlikely
    }
  }

  var displayName: String {
    switch self {
    case .reach: return String(localized: "Reach")
    case .match: return String(localized: "Match")
    case .safety: return String(localized: "Safety")
    case .unlikely: return String(localized: "Unlikely")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .reach: return .orange
    case .match: return .emerald
    case .safety: return .emerald
    case .unlikely: return .red
    }
  }

  var description: String {
    switch self {
    case .reach:
      return String(localized: "This school is a reach - admission is competitive")
    case .match:
      return String(localized: "This school is a good match for your profile")
    case .safety:
      return String(localized: "This school is a safety - high likelihood of admission")
    case .unlikely:
      return String(localized: "This school may be outside your target range")
    }
  }
}
