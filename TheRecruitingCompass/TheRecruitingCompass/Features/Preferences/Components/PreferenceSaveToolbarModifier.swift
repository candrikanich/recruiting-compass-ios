import SwiftUI

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
