import SwiftUI

struct AddSchoolSheet: View {
  @Binding var schoolName: String
  @Binding var schoolLocation: String
  let isSaving: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  private var isSaveDisabled: Bool {
    isSaving || schoolName.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("School Name", text: $schoolName)
            .accessibilityLabel("School name, required")
          TextField("Location (optional)", text: $schoolLocation)
            .accessibilityLabel("School location, optional")
        } header: {
          Text("School Details")
        }
      }
      .navigationTitle("Add New School")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          if isSaving {
            ProgressView()
              .accessibilityLabel("Saving school")
          } else {
            Button("Save School", action: onSave)
              .disabled(isSaveDisabled)
              .accessibilityIdentifier("save-school-button")
          }
        }
      }
    }
    .presentationDetents([.medium])
    .interactiveDismissDisabled(isSaving)
    .accessibilityIdentifier("add-school-modal")
  }
}
