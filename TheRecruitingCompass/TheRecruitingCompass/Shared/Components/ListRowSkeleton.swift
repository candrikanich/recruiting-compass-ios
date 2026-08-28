import SwiftUI

/// Skeleton placeholder for a single list row while data is loading.
/// Usage: ForEach(0..<5, id: \.self) { _ in ListRowSkeleton() }
struct ListRowSkeleton: View {
  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color.Brand.slate100)
        .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 6) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(height: 14)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Brand.slate100)
          .frame(width: 160, height: 12)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .shimmer()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(String(localized: "Loading"))
    .accessibilityAddTraits(.updatesFrequently)
  }
}

#Preview {
  VStack(spacing: 0) {
    ForEach(0..<5, id: \.self) { _ in
      ListRowSkeleton()
      Divider()
    }
  }
}
