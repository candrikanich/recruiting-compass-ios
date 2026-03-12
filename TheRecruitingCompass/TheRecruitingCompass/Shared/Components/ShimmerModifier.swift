import SwiftUI

/// Applies a shimmer animation to any view for skeleton loading states.
/// Automatically disables animation when accessibilityReduceMotion is enabled.
struct ShimmerModifier: ViewModifier {
  @State private var isAnimating = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .opacity(reduceMotion ? 0.6 : (isAnimating ? 0.4 : 0.8))
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
        value: isAnimating
      )
      .onAppear { if !reduceMotion { isAnimating = true } }
  }
}

extension View {
  func shimmer() -> some View {
    modifier(ShimmerModifier())
  }
}
