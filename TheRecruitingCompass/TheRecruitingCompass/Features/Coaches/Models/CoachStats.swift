import Foundation
import SwiftUI

struct CoachStats: Sendable {
  let totalInteractions: Int
  let daysSinceContact: Int?
  let preferredMethod: String?

  var contactStatusColor: Color {
    guard let days = daysSinceContact else { return .gray }
    if days == 0 { return Color(hex: "#10B981") }      // emerald - today
    if days <= 30 { return Color(hex: "#F97316") }     // orange - within month
    return Color(hex: "#EF4444")                       // red - over month
  }

  /// Shape cue paired with `contactStatusColor`; the recency tier is not in `contactStatusText`.
  var contactStatusIconName: String {
    guard let days = daysSinceContact else { return "minus.circle" }
    if days == 0 { return "checkmark.circle.fill" }
    if days <= 30 { return "clock.fill" }
    return "exclamationmark.triangle.fill"
  }

  var contactStatusText: String {
    guard let days = daysSinceContact else { return String(localized: "Never") }
    if days == 0 { return String(localized: "Today") }
    return String(localized: "\(days) days ago")
  }
}
