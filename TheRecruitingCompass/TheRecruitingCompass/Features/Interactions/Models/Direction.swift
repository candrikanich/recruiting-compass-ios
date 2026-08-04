import Foundation

enum Direction: String, Codable, CaseIterable, Sendable {
  case outbound
  case inbound

  var displayName: String {
    switch self {
    case .outbound: return "Outbound"
    case .inbound: return "Inbound"
    }
  }

  var subtitle: String {
    switch self {
    case .outbound: return "We initiated"
    case .inbound: return "They initiated"
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .outbound: return .purple
    case .inbound: return .emerald
    }
  }
}
