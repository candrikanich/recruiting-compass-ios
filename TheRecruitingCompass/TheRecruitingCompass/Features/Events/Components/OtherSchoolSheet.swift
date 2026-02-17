import SwiftUI

struct OtherSchoolSheet: View {
  @Binding var schoolName: String
  let onContinue: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("School Name", text: $schoolName)
            .accessibilityLabel("School name, not listed")
        } header: {
          Text("Enter the school name")
        }
      }
      .navigationTitle("School Not Listed")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Continue", action: onContinue)
            .disabled(schoolName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .presentationDetents([.medium])
  }
}
