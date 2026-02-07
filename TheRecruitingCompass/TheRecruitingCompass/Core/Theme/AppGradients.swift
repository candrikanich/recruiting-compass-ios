import SwiftUI

extension LinearGradient {
    static let primaryBackground = LinearGradient(
        gradient: Gradient(colors: [Color.primaryGreen, Color.darkEmerald]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let landingBackground = LinearGradient(
        gradient: Gradient(colors: [Color.emeraldGradientStart, Color.emeraldGradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryButton = LinearGradient(
        gradient: Gradient(colors: [Color.blueGradientStart, Color.blueGradientEnd]),
        startPoint: .leading,
        endPoint: .trailing
    )
}
