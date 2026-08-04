import SwiftUI

enum ToastType {
  case success
  case error
  case info
  case warning

  var iconName: String {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "exclamationmark.circle.fill"
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .success: return .successGreen
    case .error: return .errorRed
    case .info: return .accentBlue
    case .warning: return Color(hex: "F59E0B") // Amber
    }
  }
}
