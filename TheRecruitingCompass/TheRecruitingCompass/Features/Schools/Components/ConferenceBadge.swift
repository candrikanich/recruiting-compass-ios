import SwiftUI

struct ConferenceBadge: View {
  let conference: String

  var body: some View {
    Text(conference)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.gray.opacity(0.1))
      .foregroundStyle(.secondary)
      .clipShape(Capsule())
      .accessibilityLabel("Conference: \(conference)")
  }
}
