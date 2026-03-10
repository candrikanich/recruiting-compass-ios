import SwiftUI

/// Semantic badge color vocabulary. Matches the web app's BadgeColor type exactly.
/// - blue: primary actions, in-progress, interaction type
/// - emerald: success, completed, inbound
/// - orange: warning, pending, reach
/// - purple: secondary, outbound
/// - red: error, danger, destructive, negative
/// - slate: neutral, disabled, fallback
enum BadgeColor: CaseIterable {
  case blue, emerald, orange, purple, red, slate

  var backgroundColor: Color {
    switch self {
    case .blue:    return Color.Brand.blue100
    case .emerald: return Color.Brand.emerald100
    case .orange:  return Color.Brand.orange100
    case .purple:  return Color.Brand.purple100
    case .red:     return Color.Brand.red100
    case .slate:   return Color.Brand.slate100
    }
  }

  var foregroundColor: Color {
    switch self {
    case .blue:    return Color.Brand.blue700
    case .emerald: return Color.Brand.emerald700
    case .orange:  return Color.Brand.orange700
    case .purple:  return Color.Brand.purple700
    case .red:     return Color.Brand.red700
    case .slate:   return Color.Brand.slate700
    }
  }

  /// Mid-tone color for dots, circles, and progress indicators.
  var indicatorColor: Color {
    switch self {
    case .blue:    return Color.Brand.blue500
    case .emerald: return Color.Brand.emerald500
    case .orange:  return Color.Brand.orange500
    case .purple:  return Color.Brand.purple500
    case .red:     return Color.Brand.red500
    case .slate:   return Color.Brand.slate500
    }
  }
}
