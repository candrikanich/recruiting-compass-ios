import SwiftUI

// Brand-tinted shadow modifiers.
// The shadow hue (30, 50, 100) carries the blue brand temperature into depth,
// replacing pure-black shadows that make surfaces feel disconnected from the brand.

private let brandShadowColor = Color(red: 30 / 255, green: 50 / 255, blue: 100 / 255)

extension View {
  /// Subtle card resting shadow — matches CSS `--shadow-card`.
  func brandShadowSm(cornerRadius: CGFloat = 12) -> some View {
    self
      .shadow(color: brandShadowColor.opacity(0.08), radius: 3, x: 0, y: 1)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(brandShadowColor.opacity(0.06), lineWidth: 1)
      )
  }

  /// Elevated card shadow — matches CSS `--shadow-card-hover`.
  func brandShadowMd() -> some View {
    self
      .shadow(color: brandShadowColor.opacity(0.10), radius: 8, x: 0, y: 4)
      .shadow(color: brandShadowColor.opacity(0.06), radius: 2, x: 0, y: 1)
  }

  /// Large depth shadow — matches CSS `--shadow-lg`.
  func brandShadowLg() -> some View {
    self
      .shadow(color: brandShadowColor.opacity(0.12), radius: 20, x: 0, y: 8)
  }
}
