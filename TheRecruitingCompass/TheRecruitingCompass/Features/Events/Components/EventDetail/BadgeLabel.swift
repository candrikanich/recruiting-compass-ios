import SwiftUI

// MARK: - Shared Badge Style

struct BadgeLabel: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }
}
