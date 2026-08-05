import SwiftUI

// MARK: - Shared Preview Unavailable

struct PreviewUnavailableView: View {
  let icon: String
  let message: LocalizedStringKey

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}
