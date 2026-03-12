import SwiftUI

enum AnalyticsChartColors {
  static let primary    = Color.Brand.blue500
  static let secondary  = Color.Brand.emerald500
  static let tertiary   = Color.Brand.orange500
  static let quaternary = Color.Brand.red500
  static let purple     = Color.Brand.purple500
  static let pink       = Color(hex: "ec4899")  // no brand token for pink

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
    "Positive":      secondary,
    "Very Positive": Color.Brand.emerald600,
    "Neutral":       Color.Brand.slate500,
    "Negative":      quaternary
  ]
}
