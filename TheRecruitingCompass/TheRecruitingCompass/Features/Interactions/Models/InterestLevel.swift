import SwiftUI

/// Coach interest level based on interaction calibration
enum InterestLevel: String, Codable, Sendable {
  case high
  case medium
  case low
  case notSet = "not_set"

  var displayName: String {
    switch self {
    case .high: return String(localized: "High Interest")
    case .medium: return String(localized: "Medium Interest")
    case .low: return String(localized: "Low Interest")
    case .notSet: return String(localized: "Not Set")
    }
  }

  var emoji: String {
    switch self {
    case .high: return "🔥"
    case .medium: return "⚡"
    case .low: return "❄️"
    case .notSet: return "—"
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .high: return .emerald
    case .medium: return .orange
    case .low: return .slate
    case .notSet: return .slate
    }
  }
}
