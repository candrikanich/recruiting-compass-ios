import SwiftUI

enum Division: String, Codable, CaseIterable, Sendable {
  case d1 = "D1"
  case d2 = "D2"
  case d3 = "D3"
  case naia = "NAIA"
  case juco = "JUCO"

  var displayName: String {
    rawValue
  }

  var badgeColor: Color {
    switch self {
    case .d1:
      return Color.blue
    case .d2:
      return Color.green
    case .d3:
      return Color.orange
    case .naia:
      return Color.purple
    case .juco:
      return Color.teal
    }
  }
}
