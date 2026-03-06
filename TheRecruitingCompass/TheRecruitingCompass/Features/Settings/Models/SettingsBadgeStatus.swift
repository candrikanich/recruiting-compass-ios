import SwiftUI

enum SettingsBadgeStatus {
  case complete
  case incomplete

  var label: String {
    switch self {
    case .complete: return "Complete"
    case .incomplete: return "Incomplete"
    }
  }

  var foregroundColor: Color {
    switch self {
    case .complete: return Color(red: 0.06, green: 0.52, blue: 0.28)   // emerald-700
    case .incomplete: return Color(red: 0.65, green: 0.44, blue: 0.09) // amber-700
    }
  }

  var backgroundColor: Color {
    switch self {
    case .complete: return Color(red: 0.85, green: 0.97, blue: 0.90)   // emerald-100
    case .incomplete: return Color(red: 0.99, green: 0.95, blue: 0.83) // amber-100
    }
  }
}
