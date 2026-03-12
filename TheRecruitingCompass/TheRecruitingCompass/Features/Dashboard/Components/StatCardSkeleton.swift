import SwiftUI

struct StatCardSkeleton: View {
  @State private var isAnimating = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Circle()
        .fill(Color.Brand.slate100)
        .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(height: 32)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(width: 100, height: 16)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 120)
    .background(Color.Brand.slate100)
    .clipShape(.rect(cornerRadius: 12))
    .opacity(isAnimating ? 0.5 : 1.0)
    .animation(reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
    .onAppear { if !reduceMotion { isAnimating = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading statistics")
    .accessibilityAddTraits(.updatesFrequently)
  }
}

#Preview {
  StatCardSkeleton()
    .padding()
}
