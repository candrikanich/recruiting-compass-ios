import SwiftUI

struct InlineErrorView: View {
  let message: String
  let icon: String
  let onRetry: (() -> Void)?
  let retryAccessibilityHint: String?

  init(
    message: String,
    icon: String = "exclamationmark.triangle",
    onRetry: (() -> Void)? = nil,
    retryAccessibilityHint: String? = nil
  ) {
    self.message = message
    self.icon = icon
    self.onRetry = onRetry
    self.retryAccessibilityHint = retryAccessibilityHint
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(Color.errorRed)
        .accessibilityHidden(true)

      Text(message)
        .font(.body)
        .foregroundStyle(Color.secondaryText)
        .multilineTextAlignment(.center)

      if let onRetry {
        Button("Retry", action: onRetry)
          .buttonStyle(.borderedProminent)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel(String(localized: "Retry"))
          .accessibilityHint(retryAccessibilityHint ?? "Attempts to load again")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

#Preview {
  VStack(spacing: 40) {
    InlineErrorView(message: "Unable to load coach details")
    InlineErrorView(message: "Network connection failed", icon: "wifi.slash")
    InlineErrorView(message: "Something went wrong")
  }
}
