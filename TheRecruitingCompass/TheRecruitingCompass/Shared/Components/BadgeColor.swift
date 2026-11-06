import SwiftUI

/// Semantic badge color vocabulary. Case names match the web app's BadgeColor type; hues follow the de-slop
/// palette (web Badge.vue light variant).
/// - blue (forest): primary actions, in-progress, interaction type
/// - emerald: success, completed, inbound
/// - orange: warning, pending, reach
/// - purple (gold): secondary, outbound
/// - red: error, danger, destructive, negative
/// - slate: neutral, disabled, fallback
enum BadgeColor: CaseIterable {
  case blue, emerald, orange, purple, red, slate

  var backgroundColor: Color {
    switch self {
    case .blue:    return Color.Brand.forest200
    case .emerald: return Color.Brand.emerald200
    case .orange:  return Color.Brand.orange100
    case .purple:  return Color.Brand.gold200
    case .red:     return Color.Brand.red200
    case .slate:   return Color.Brand.slate200
    }
  }

  var foregroundColor: Color {
    switch self {
    case .blue:    return Color.Brand.forest900
    case .emerald: return Color.Brand.emerald900
    case .orange:  return Color.Brand.orange700
    case .purple:  return Color.Brand.gold900
    case .red:     return Color.Brand.red900
    case .slate:   return Color.Brand.slate900
    }
  }

  /// Mid-tone color for dots, circles, and progress indicators.
  var indicatorColor: Color {
    switch self {
    case .blue:    return Color.Brand.forest500
    case .emerald: return Color.Brand.emerald500
    case .orange:  return Color.Brand.orange500
    case .purple:  return Color.Brand.gold500
    case .red:     return Color.Brand.red500
    case .slate:   return Color.Brand.slate500
    }
  }
}
