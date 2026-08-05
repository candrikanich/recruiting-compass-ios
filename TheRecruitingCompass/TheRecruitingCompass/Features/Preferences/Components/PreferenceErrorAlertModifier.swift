import SwiftUI

struct PreferenceErrorAlertModifier: ViewModifier {
  @Binding var errorMessage: String?

  func body(content: Content) -> some View {
    content
      .alert("Error", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) {
      } message: {
        if let errorMessage {
          Text(errorMessage)
        }
      }
  }
}

extension View {
  /// Adds a standard error alert to preference views
  func preferenceErrorAlert(errorMessage: Binding<String?>) -> some View {
    modifier(PreferenceErrorAlertModifier(errorMessage: errorMessage))
  }
}

#Preview("Error Alert") {
  struct PreviewWrapper: View {
    @State private var errorMessage: String? = "Something went wrong"

    var body: some View {
      NavigationStack {
        VStack {
          Text("Content")
          Button("Show Error") {
            errorMessage = "Test error message"
          }
        }
        .preferenceErrorAlert(errorMessage: $errorMessage)
      }
    }
  }

  return PreviewWrapper()
}
