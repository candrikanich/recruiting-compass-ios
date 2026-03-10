import SwiftUI

extension LinearGradient {
  static let primaryBackground = LinearGradient(
    gradient: Gradient(colors: [Color.Brand.emerald500, Color.Brand.emerald700]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let landingBackground = LinearGradient(
    gradient: Gradient(colors: [Color.Brand.emerald500, Color.Brand.emerald600]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let primaryButton = LinearGradient(
    gradient: Gradient(colors: [Color.Brand.blue500, Color.Brand.blue700]),
    startPoint: .leading,
    endPoint: .trailing
  )
}
