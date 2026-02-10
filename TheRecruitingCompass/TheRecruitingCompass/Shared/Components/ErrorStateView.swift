import SwiftUI

/// A reusable error state component with an icon and message.
struct ErrorStateView: View {
  let message: String
  let icon: String

  init(message: String, icon: String = "exclamationmark.triangle") {
    self.message = message
    self.icon = icon
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
