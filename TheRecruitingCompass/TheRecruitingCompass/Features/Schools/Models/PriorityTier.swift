import Foundation

enum PriorityTier: String, Codable, CaseIterable, Sendable {
  case a = "A"
  case b = "B"
  case c = "C"

  var displayName: String {
    "Tier \(rawValue)"
  }
}
