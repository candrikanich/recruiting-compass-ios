import SwiftUI

// MARK: - Error Alert Modifier

struct PreferenceErrorAlertModifier: ViewModifier {
  @Binding var errorMessage: String?

  func body(content: Content) -> some View {
    content
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        if let errorMessage = errorMessage {
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

// MARK: - Save Toolbar Modifier

struct PreferenceSaveToolbarModifier: ViewModifier {
  let hasUnsavedChanges: Bool
  let isSaving: Bool
  let label: String
  let action: () async -> Void

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(label) {
            Task {
              await action()
            }
          }
          .disabled(!hasUnsavedChanges || isSaving)
          .accessibilityLabel("Save preferences")
        }
      }
  }
}

extension View {
  /// Adds a standard save button to the toolbar
  func preferenceSaveToolbar(
    hasUnsavedChanges: Bool,
    isSaving: Bool,
    label: String = "Save",
    action: @escaping () async -> Void
  ) -> some View {
    modifier(PreferenceSaveToolbarModifier(
      hasUnsavedChanges: hasUnsavedChanges,
      isSaving: isSaving,
      label: label,
      action: action
    ))
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

#Preview("Save Toolbar") {
  struct PreviewWrapper: View {
    @State private var hasUnsavedChanges = true
    @State private var isSaving = false

    var body: some View {
      NavigationStack {
        Form {
          Toggle("Example Setting", isOn: .constant(true))
        }
        .navigationTitle("Preferences")
        .preferenceSaveToolbar(
          hasUnsavedChanges: hasUnsavedChanges,
          isSaving: isSaving
        ) {
          isSaving = true
          try? await Task.sleep(for: .seconds(1))
          hasUnsavedChanges = false
          isSaving = false
        }
      }
    }
  }

  return PreviewWrapper()
}
