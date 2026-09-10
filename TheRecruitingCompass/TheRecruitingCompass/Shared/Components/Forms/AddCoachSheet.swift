import SwiftUI

/// Sheet for adding a new coach to a school
struct AddCoachSheet: View {
  @Binding var firstName: String
  @Binding var lastName: String
  @Binding var email: String
  @Binding var role: CoachRole
  let isValid: Bool
  let onSave: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("Coach Information") {
          TextField("First Name", text: $firstName)
            .textContentType(.givenName)
            .accessibilityLabel(String(localized: "First name field"))

          TextField("Last Name", text: $lastName)
            .textContentType(.familyName)
            .accessibilityLabel(String(localized: "Last name field"))

          TextField("Email (Optional)", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(String(localized: "Email field, optional"))

          Picker("Role", selection: $role) {
            ForEach(CoachRole.allCases, id: \.self) { coachRole in
              Text(coachRole.displayName).tag(coachRole)
            }
          }
          .accessibilityLabel(String(localized: "Coach role picker"))
        }

        Section {
          Button("Save Coach") {
            onSave()
          }
          .disabled(!isValid)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Add New Coach")
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
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var role = CoachRole.head

    var body: some View {
      AddCoachSheet(
        firstName: $firstName,
        lastName: $lastName,
        email: $email,
        role: $role,
        isValid: !firstName.isEmpty && !lastName.isEmpty,
        onSave: {}
      )
    }
  }

  return PreviewWrapper()
}
