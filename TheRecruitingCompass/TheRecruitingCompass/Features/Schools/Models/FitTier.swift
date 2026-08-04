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
    case .reach: return "Reach"
    case .match: return "Match"
    case .safety: return "Safety"
    case .unlikely: return "Unlikely"
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
      return "This school is a reach - admission is competitive"
    case .match:
      return "This school is a good match for your profile"
    case .safety:
      return "This school is a safety - high likelihood of admission"
    case .unlikely:
      return "This school may be outside your target range"
    }
  }
}
