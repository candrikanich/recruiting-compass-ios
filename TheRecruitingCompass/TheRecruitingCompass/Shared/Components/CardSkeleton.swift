import SwiftUI

/// Skeleton placeholder for a card while data is loading.
/// Usage: CardSkeleton() or LazyVGrid { ForEach(0..<4) { _ in CardSkeleton() } }
struct CardSkeleton: View {
  @State private var isAnimating = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color.Brand.slate100)
        .frame(height: 16)

      RoundedRectangle(cornerRadius: 4)
        .fill(Color.Brand.slate100)
        .frame(height: 12)
        .frame(maxWidth: .infinity)

      RoundedRectangle(cornerRadius: 4)
        .fill(Color.Brand.slate100)
        .frame(width: 100, height: 12)

      Spacer()

      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.Brand.slate100)
          .frame(width: 60, height: 22)
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.Brand.slate100)
          .frame(width: 50, height: 22)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 140)
    .background(Color.Brand.slate100.opacity(0.4))
    .clipShape(.rect(cornerRadius: 12))
    .opacity(isAnimating ? 0.4 : 0.8)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
      value: isAnimating
    )
    .onAppear { if !reduceMotion { isAnimating = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading")
    .accessibilityAddTraits(.updatesFrequently)
  }
}

#Preview {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    ForEach(0..<4, id: \.self) { _ in CardSkeleton() }
  }
  .padding()
}
