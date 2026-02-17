import SwiftUI

/// A reusable error state component with an icon and message.
/// Optionally show a Retry button that invokes `onRetry` when provided.
struct ErrorStateView: View {
  let message: String
  let icon: String
  let onRetry: (() -> Void)?

  init(message: String, icon: String = "exclamationmark.triangle", onRetry: (() -> Void)? = nil) {
    self.message = message
    self.icon = icon
    self.onRetry = onRetry
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(Color.errorRed)
        .accessibilityHidden(true)

      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if let onRetry {
        Button("Retry", action: onRetry)
          .buttonStyle(.borderedProminent)
          .frame(minHeight: 44)
          .accessibilityLabel("Retry")
          .accessibilityHint("Attempts to load again")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

#Preview {
  VStack(spacing: 40) {
    ErrorStateView(message: "Unable to load coach details")
    ErrorStateView(message: "Network connection failed", icon: "wifi.slash")
    ErrorStateView(message: "Something went wrong")
  }
}
