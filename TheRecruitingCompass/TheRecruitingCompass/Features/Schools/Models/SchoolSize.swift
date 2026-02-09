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
      return "Very Small"
    case .small:
      return "Small"
    case .medium:
      return "Medium"
    case .large:
      return "Large"
    case .veryLarge:
      return "Very Large"
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
