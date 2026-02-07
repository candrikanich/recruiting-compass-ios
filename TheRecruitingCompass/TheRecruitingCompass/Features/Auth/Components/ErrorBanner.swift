import SwiftUI

struct ErrorBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundColor(Color(red: 0.859, green: 0.149, blue: 0.149))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(message)
          .font(.footnote)
          .foregroundColor(Color(red: 0.859, green: 0.149, blue: 0.149))
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .foregroundColor(Color(red: 0.859, green: 0.149, blue: 0.149))
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Close error message")
    }
    .padding(12)
    .background(Color(red: 0.996, green: 0.886, blue: 0.886))
    .border(Color(red: 0.996, green: 0.792, blue: 0.792), width: 1)
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Error: \(message)")
  }
}

#Preview {
  ErrorBanner(message: "Invalid email or password", onDismiss: {})
    .padding()
}
