import SwiftUI

struct ErrorBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundColor(Color.errorRed)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(message)
          .font(.footnote)
          .foregroundColor(Color.errorRed)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .foregroundColor(Color.errorRed)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Close error message")
    }
    .padding(12)
    .background(Color.errorBackground)
    .border(Color.errorBorder, width: 1)
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Error: \(message)")
  }
}

#Preview {
  ErrorBanner(message: "Invalid email or password", onDismiss: {})
    .padding()
}
