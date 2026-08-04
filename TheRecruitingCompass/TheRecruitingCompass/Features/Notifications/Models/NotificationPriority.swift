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
}
