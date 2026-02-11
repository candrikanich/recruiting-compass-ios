import SwiftUI

/// Coach interest level based on interaction calibration
enum InterestLevel: String, Codable, Sendable {
  case high
  case medium
  case low
  case notSet = "not_set"

  var displayName: String {
    switch self {
    case .high: return "High Interest"
    case .medium: return "Medium Interest"
    case .low: return "Low Interest"
    case .notSet: return "Not Set"
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

  var color: Color {
    switch self {
    case .high: return .green
    case .medium: return .orange
    case .low: return .gray
    case .notSet: return .gray
    }
  }
}
