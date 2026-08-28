import Foundation

enum SchoolSize: String, Codable, CaseIterable, Sendable {
  case verySmall = "very_small"
  case small
  case medium
  case large
  case veryLarge = "very_large"

  var displayName: String {
    switch self {
    case .verySmall:
      return String(localized: "Very Small")
    case .small:
      return String(localized: "Small")
    case .medium:
      return String(localized: "Medium")
    case .large:
      return String(localized: "Large")
    case .veryLarge:
      return String(localized: "Very Large")
    }
  }

  static func from(studentSize: Int) -> SchoolSize {
    switch studentSize {
    case 0..<2000:
      return .verySmall
    case 2000..<5000:
      return .small
    case 5000..<15000:
      return .medium
    case 15000..<30000:
      return .large
    default:
      return .veryLarge
    }
  }
}
