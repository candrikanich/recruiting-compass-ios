import Foundation

enum Division: String, Codable, CaseIterable, Sendable {
  case d1 = "D1"
  case d2 = "D2"
  case d3 = "D3"
  case naia = "NAIA"
  case juco = "JUCO"

  var displayName: String {
    switch self {
    case .d1:   return String(localized: "D1")
    case .d2:   return String(localized: "D2")
    case .d3:   return String(localized: "D3")
    case .naia: return String(localized: "NAIA")
    case .juco: return String(localized: "JUCO")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .d1:   return .blue
    case .d2:   return .emerald
    case .d3:   return .orange
    case .naia: return .purple
    case .juco: return .slate
    }
  }
}
