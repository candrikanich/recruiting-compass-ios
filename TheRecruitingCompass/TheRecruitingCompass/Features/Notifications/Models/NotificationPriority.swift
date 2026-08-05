import Foundation

enum NotificationPriority: String, Codable, Sendable {
  case low
  case normal
  case high
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = NotificationPriority(rawValue: rawValue) ?? .unknown
  }

  var label: String {
    switch self {
    case .low: return String(localized: "LOW")
    case .normal: return String(localized: "NORMAL")
    case .high: return String(localized: "HIGH")
    case .unknown: return String(localized: "UNKNOWN")
    }
  }
}
