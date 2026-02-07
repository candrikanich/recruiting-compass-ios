import SwiftUI

struct TimeoutBanner: View {
  var body: some View {
    Banner(
      style: .warning,
      message: "You were logged out due to inactivity. Please log in again.",
      onDismiss: nil
    )
    .accessibilityLabel("Session timeout warning")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  TimeoutBanner()
    .padding()
}
