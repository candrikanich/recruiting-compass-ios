import Foundation
import SwiftUI

enum PriorityTier: String, Codable, CaseIterable, Sendable {
  case a = "A"
  case b = "B"
  case c = "C"

  var displayName: String {
    rawValue
  }

  var badgeColor: Color {
    switch self {
    case .a: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
    case .b: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
    case .c: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
    }
  }
}
