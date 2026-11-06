import SwiftUI

enum AnalyticsChartColors {
  static let primary    = Color.Brand.forest500
  static let secondary  = Color.Brand.emerald500
  static let tertiary   = Color(hex: "f59e0b")  // amber, web slot 3
  static let quaternary = Color.Brand.red500
  static let accent     = Color.Brand.gold400
  static let accentDeep = Color.Brand.gold500

  static let palette: [Color] = [
    primary, secondary, tertiary, quaternary, accent, accentDeep
  ]

  static func color(at index: Int) -> Color {
    palette[index % palette.count]
  }

  static let funnelPalette: [Color] = [
    primary, secondary, tertiary, quaternary
  ]

  static let sentimentColors: [String: Color] = [
    "Positive": secondary,
    "Very Positive": Color.Brand.emerald600,
    "Neutral": Color.Brand.slate500,
    "Negative": quaternary
  ]
}
