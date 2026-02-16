import SwiftUI

enum AnalyticsChartColors {
  static let primary = Color(hex: "3b82f6")
  static let secondary = Color(hex: "10b981")
  static let tertiary = Color(hex: "f59e0b")
  static let quaternary = Color(hex: "ef4444")
  static let purple = Color(hex: "8b5cf6")
  static let pink = Color(hex: "ec4899")

  static let palette: [Color] = [
    primary, secondary, tertiary, quaternary, purple, pink
  ]

  static func color(at index: Int) -> Color {
    palette[index % palette.count]
  }

  static let funnelPalette: [Color] = [
    primary, secondary, tertiary, quaternary
  ]

  static let sentimentColors: [String: Color] = [
    "Positive": secondary,
    "Very Positive": Color(hex: "059669"),
    "Neutral": Color(hex: "6b7280"),
    "Negative": quaternary
  ]
}
