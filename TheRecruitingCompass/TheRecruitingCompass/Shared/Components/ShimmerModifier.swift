import SwiftUI

/// Opacity pulse for skeleton placeholders. No-ops into a static fade when
/// Reduce Motion is on. Apply to the placeholder container, not each bar.
struct ShimmerModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAnimating = false

  func body(content: Content) -> some View {
    content
      .opacity(isAnimating ? 0.4 : 0.8)
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
        value: isAnimating
      )
      .onAppear {
        if !reduceMotion {
          isAnimating = true
        }
      }
  }
}

extension View {
  func shimmer() -> some View {
    modifier(ShimmerModifier())
  }
}
