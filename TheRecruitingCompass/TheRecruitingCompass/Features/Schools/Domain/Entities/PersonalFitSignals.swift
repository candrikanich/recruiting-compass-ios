import Foundation

enum FitSignalStrength: String, Sendable, Equatable {
  case strong, good, stretch, unknown
}

struct PersonalFitSignal: Sendable, Equatable {
  let label: String
  let value: String?
  let strength: FitSignalStrength
  let explanation: String
}

struct PersonalFitAnalysis: Sendable, Equatable {
  let location: PersonalFitSignal
  let campusSize: PersonalFitSignal
  let cost: PersonalFitSignal

  var orderedSignals: [PersonalFitSignal] { [location, campusSize, cost] }
  var availableSignals: Int { orderedSignals.filter { $0.strength != .unknown }.count }
}

struct OverallPersonalFit: Sendable, Equatable {
  enum Strength: String, CaseIterable, Sendable {
    case strong, good, stretch

    var label: String {
      switch self {
      case .strong: return String(localized: "Strong fit")
      case .good: return String(localized: "Good fit")
      case .stretch: return String(localized: "Stretch")
      }
    }

    var badgeColor: BadgeColor {
      switch self {
      case .strong: return .emerald
      case .good: return .orange
      case .stretch: return .red
      }
    }
  }

  let strength: Strength
  var label: String { strength.label }
  var badgeColor: BadgeColor { strength.badgeColor }
}
