import SwiftUI

/// Sheet for entering a coach name that isn't in the system
struct OtherCoachSheet: View {
  @Binding var coachName: String
  let onContinue: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("Coach Name") {
          TextField("Enter coach name", text: $coachName)
            .textContentType(.name)
            .accessibilityLabel("Coach name field")
            .accessibilityHint("Enter the name of a coach not in the system")
        }

        Section {
          Button("Continue") {
            onContinue()
            dismiss()
          }
          .disabled(coachName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Other Coach")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  struct PreviewWrapper: View {
    @State private var coachName = ""

    var body: some View {
      OtherCoachSheet(
        coachName: $coachName,
        onContinue: {}
      )
    }
  }

  return PreviewWrapper()
}
