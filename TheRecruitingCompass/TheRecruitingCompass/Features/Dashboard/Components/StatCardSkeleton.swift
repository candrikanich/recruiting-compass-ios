import SwiftUI

struct StatCardSkeleton: View {
  @State private var isAnimating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.gray.opacity(0.3))
          .frame(height: 32)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.gray.opacity(0.3))
          .frame(width: 100, height: 16)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 120)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
    .opacity(isAnimating ? 0.5 : 1.0)
    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
    .onAppear { isAnimating = true }
  }
}

#Preview {
  StatCardSkeleton()
    .padding()
}
