import Foundation
import SwiftUI

enum PriorityTier: String, Codable, CaseIterable, Sendable {
  case a = "A"
  case b = "B"
  case c = "C"

  var displayName: String {
    rawValue
  }

  var badgeColor: BadgeColor {
    switch self {
    case .a: return .red      // Urgency/top choice
    case .b: return .orange   // Strong interest
    case .c: return .slate    // Fallback
    }
  }
}
