import SwiftUI

struct SizeBadge: View {
  let size: SchoolSize

  var body: some View {
    Text(size.displayName)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.15))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Size: \(size.displayName)")
  }
}
