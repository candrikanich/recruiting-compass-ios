import SwiftUI

struct CoachEditForm: View {
  @Binding var editedCoach: EditableCoach
  let validationErrors: [String: String]
  let isSaving: Bool
  let onSave: () async -> Void
  let onCancel: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var minFieldHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 50 : 44
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Basic Information") {
          TextField("First Name", text: $editedCoach.firstName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("First Name")

          if let error = validationErrors["firstName"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("First name error: \(error)")
          }

          TextField("Last Name", text: $editedCoach.lastName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("Last Name")

          if let error = validationErrors["lastName"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("Last name error: \(error)")
          }

          Picker("Role", selection: $editedCoach.position) {
            Text("Head Coach").tag("head")
            Text("Assistant Coach").tag("assistant")
            Text("Recruiting Coordinator").tag("recruiting")
          }
          .frame(minHeight: minFieldHeight)
          .accessibilityLabel("Coach role")
        }

        Section("Contact Information") {
          TextField("Email", text: $editedCoach.email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("Email address")

          if let error = validationErrors["email"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("Email error: \(error)")
          }

          TextField("Phone", text: $editedCoach.phone)
            .keyboardType(.phonePad)
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("Phone number")

          if let error = validationErrors["phone"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("Phone error: \(error)")
          }
        }

        Section("Social Media") {
          TextField("Twitter Handle", text: $editedCoach.twitterHandle)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("Twitter handle")

          if let error = validationErrors["twitterHandle"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("Twitter error: \(error)")
          }

          TextField("Instagram Handle", text: $editedCoach.instagramHandle)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .frame(minHeight: minFieldHeight)
            .accessibilityLabel("Instagram handle")

          if let error = validationErrors["instagramHandle"] {
            Text(error)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel("Instagram error: \(error)")
          }
        }
      }
      .navigationTitle("Edit Coach")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
          if isSaving {
            ProgressView()
              .accessibilityLabel("Saving changes")
          } else {
            Button("Save") {
              Task {
                await onSave()
              }
            }
            .disabled(isSaving)
            .accessibilityLabel("Save coach changes")
          }
        }
      }
      .disabled(isSaving)
    }
  }
}

#Preview {
  CoachEditForm(
    editedCoach: .constant(EditableCoach(
      from: Coach(
        id: "coach-1",
        firstName: "John",
        lastName: "Smith",
        email: "john@university.edu",
        phone: "555-0123",
        position: "head",
        schoolId: "school-1",
        twitterHandle: "@coachsmith",
        instagramHandle: "@coachsmith",
        notes: "Great recruiter",
        privateNotes: nil,
        responsivenessScore: 85,
        lastContactDate: "2026-01-15T10:00:00Z",
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2026-01-15T10:00:00Z"
      )
    )),
    validationErrors: [:],
    isSaving: false,
    onSave: {},
    onCancel: {}
  )
}

#Preview("With Validation Errors") {
  CoachEditForm(
    editedCoach: .constant(EditableCoach(
      from: Coach(
        id: "coach-1",
        firstName: "",
        lastName: "S",
        email: "invalid-email",
        phone: "555-0123",
        position: "head",
        schoolId: "school-1",
        twitterHandle: "@verylonghandlethatismorethan15chars",
        instagramHandle: "@coachsmith",
        notes: "Great recruiter",
        privateNotes: nil,
        responsivenessScore: 85,
        lastContactDate: "2026-01-15T10:00:00Z",
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2026-01-15T10:00:00Z"
      )
    )),
    validationErrors: [
      "firstName": "Name is required",
      "lastName": "Name must be at least 2 characters",
      "email": "Invalid email address",
      "twitterHandle": "Twitter handle must be 15 characters or less"
    ],
    isSaving: false,
    onSave: {},
    onCancel: {}
  )
}
