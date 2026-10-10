import SwiftUI

// MARK: - Shared Preview Unavailable

struct PreviewUnavailableView: View {
  let icon: String
  let message: LocalizedStringKey

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.brand(.largeTitle))
        .foregroundStyle(.secondary)
      Text(message)
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}
