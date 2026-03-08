import SwiftUI

/// Reusable success toast message for preference views
struct PreferenceSuccessToast: View {
  let message: String?

  var body: some View {
    Group {
      if let message = message {
        Text(message)
          .font(.callout)
          .foregroundStyle(.white)
          .padding()
          .background(Color.green)
          .clipShape(.rect(cornerRadius: 8))
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
          .accessibilityLabel(message)
      }
    }
  }
}

#Preview {
  VStack {
    PreferenceSuccessToast(message: "Preferences saved successfully")
    Spacer()
  }
}
