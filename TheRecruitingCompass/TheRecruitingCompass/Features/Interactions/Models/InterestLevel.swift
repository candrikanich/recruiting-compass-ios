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

  /// SF Symbol for the level; `nil` when no interest has been set.
  var systemImage: String? {
    switch self {
    case .high: return "flame"
    case .medium: return "bolt"
    case .low: return "chart.line.downtrend.xyaxis"
    case .notSet: return nil
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
