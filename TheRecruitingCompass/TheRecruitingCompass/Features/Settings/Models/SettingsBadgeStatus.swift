import SwiftUI

enum SettingsBadgeStatus {
  case complete
  case incomplete

  var label: String {
    switch self {
    case .complete: return String(localized: "Complete")
    case .incomplete: return String(localized: "Incomplete")
    }
  }

  /// Shape cue so the badge reads without relying on the emerald/amber fill.
  var iconName: String {
    switch self {
    case .complete: return "checkmark.circle.fill"
    case .incomplete: return "exclamationmark.circle.fill"
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
