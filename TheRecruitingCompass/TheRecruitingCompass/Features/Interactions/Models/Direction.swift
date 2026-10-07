import Foundation

enum Direction: String, Codable, CaseIterable, Sendable {
  case outbound
  case inbound
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = Direction(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable values. Excludes `unknown`: a decode-only fallback for server values this build lacks.
  static var selectableCases: [Direction] {
    allCases.filter { $0 != .unknown }
  }

  var displayName: String {
    switch self {
    case .outbound: return String(localized: "Outbound")
    case .inbound: return String(localized: "Inbound")
    case .unknown: return String(localized: "Unknown")
    }
  }

  var subtitle: String {
    switch self {
    case .outbound: return String(localized: "We initiated")
    case .inbound: return String(localized: "They initiated")
    case .unknown: return ""
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .outbound: return .purple
    case .inbound: return .emerald
    case .unknown: return .slate
    }
  }
}
