import SwiftUI

/// A reusable loading state component with progress indicator and message.
struct LoadingStateView: View {
  let message: String

  init(message: String = "Loading...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 12) {
      ProgressView()
        .accessibilityLabel(message)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  VStack(spacing: 40) {
    LoadingStateView(message: "Loading schools...")
    LoadingStateView(message: "Loading coaches...")
    LoadingStateView()
  }
}
