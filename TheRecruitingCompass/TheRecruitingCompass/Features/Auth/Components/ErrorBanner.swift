import SwiftUI

struct ErrorBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    Banner(style: .error, message: message, onDismiss: onDismiss)
  }
}

#Preview {
  ErrorBanner(message: "Invalid email or password", onDismiss: {})
    .padding()
}
