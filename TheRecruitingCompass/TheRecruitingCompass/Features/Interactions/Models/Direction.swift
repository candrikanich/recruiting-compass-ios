import Foundation

enum Direction: String, Codable, CaseIterable, Sendable {
  case outbound
  case inbound

  var displayName: String {
    switch self {
    case .outbound: return String(localized: "Outbound")
    case .inbound: return String(localized: "Inbound")
    }
  }

  var subtitle: String {
    switch self {
    case .outbound: return String(localized: "We initiated")
    case .inbound: return String(localized: "They initiated")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .outbound: return .purple
    case .inbound: return .emerald
    }
  }
}
