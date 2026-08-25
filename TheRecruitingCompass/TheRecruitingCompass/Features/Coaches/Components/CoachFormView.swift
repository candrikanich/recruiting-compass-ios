//
//  CoachFormView.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 4: Reusable Components - Coach form fields with validation
//

import SwiftUI

struct CoachFormView: View {
  @Binding var formState: CoachFormState
  @Binding var formErrors: CoachFormErrors
  let isDisabled: Bool
  let onValidateField: (KeyPath<CoachFormState, String>, String) -> Void
  let onValidateRole: (CoachRole?) -> Void

  @FocusState private var focusedField: Field?

  enum Field: Hashable {
    case firstName, lastName, email, phone, twitter, instagram, notes
  }

  var body: some View {
    VStack(spacing: 24) {
      // Role Picker
      rolePicker

      // Name Fields (side-by-side on iPad, stacked on iPhone)
      nameFields

      // Contact Info
      emailField
      phoneField

      // Social Media (side-by-side on iPad, stacked on iPhone)
      socialMediaFields

      // Notes
      notesField

      // Source + Tags
      sourceField
      tagsField
    }
  }

  // MARK: - Source + Tags

  @ViewBuilder
  private var sourceField: some View {
    FormFieldWrapper(label: "Source") {
      TextField("e.g., LinkedIn, camp, referral", text: $formState.source)
        .textFieldStyle(.roundedBorder)
        .disabled(isDisabled)
        .accessibilityLabel(String(localized: "Source, optional"))
        .accessibilityHint("Where you found this coach")
    }
  }

  @ViewBuilder
  private var tagsField: some View {
    FormFieldWrapper(label: "Tags") {
      CoachTagsCard(
        tags: formState.tags,
        onAdd: { formState.tags = CoachTagsValidator.sanitize(formState.tags + [$0]) },
        onRemove: { tag in formState.tags.removeAll { $0 == tag } }
      )
      .disabled(isDisabled)
    }
  }

  // MARK: - Role Picker

  @ViewBuilder
  private var rolePicker: some View {
    FormFieldWrapper(label: "Role", isRequired: true, error: formErrors.role) {
      Picker("Role", selection: $formState.role) {
        Text("Select Role")
          .tag(nil as CoachRole?)

        ForEach(CoachRole.allCases, id: \.self) { role in
          Text(role.displayName)
            .tag(role as CoachRole?)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      .onChange(of: formState.role) { _, newRole in
        onValidateRole(newRole)
      }
      .accessibilityLabel(String(localized: "Role, required"))
      .accessibilityHint("Select the coach's role")
    }
  }

  // MARK: - Name Fields

  @ViewBuilder
  private var nameFields: some View {
    AdaptiveHStackVStack {
      firstNameField
      lastNameField
    }
  }

  @ViewBuilder
  private var firstNameField: some View {
    FormFieldWrapper(label: "First Name", isRequired: true, error: formErrors.firstName) {
      TextField("e.g., John", text: $formState.firstName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.givenName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused($focusedField, equals: .firstName)
        .onSubmit {
          onValidateField(\.firstName, formState.firstName)
        }
        .accessibilityLabel(String(localized: "First name, required"))
        .accessibilityHint("Enter coach's first name")
    }
  }

  @ViewBuilder
  private var lastNameField: some View {
    FormFieldWrapper(label: "Last Name", isRequired: true, error: formErrors.lastName) {
      TextField("e.g., Smith", text: $formState.lastName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.familyName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused($focusedField, equals: .lastName)
        .onSubmit {
          onValidateField(\.lastName, formState.lastName)
        }
        .accessibilityLabel(String(localized: "Last name, required"))
        .accessibilityHint("Enter coach's last name")
    }
  }

  // MARK: - Contact Info

  @ViewBuilder
  private var emailField: some View {
    FormFieldWrapper(label: "Email", error: formErrors.email) {
      TextField("john.smith@university.edu", text: $formState.email)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused($focusedField, equals: .email)
        .onSubmit {
          onValidateField(\.email, formState.email)
        }
        .accessibilityLabel(String(localized: "Email, optional"))
        .accessibilityHint("Enter coach's email address")
    }
  }

  @ViewBuilder
  private var phoneField: some View {
    FormFieldWrapper(label: "Phone", error: formErrors.phone) {
      TextField("(555) 123-4567", text: $formState.phone)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .disabled(isDisabled)
        .focused($focusedField, equals: .phone)
        .onChange(of: focusedField) { _, newFocus in
          if newFocus != .phone && !formState.phone.isEmpty {
            onValidateField(\.phone, formState.phone)
          }
        }
        .accessibilityLabel(String(localized: "Phone, optional"))
        .accessibilityHint("Enter coach's phone number")
    }
  }

  // MARK: - Social Media

  @ViewBuilder
  private var socialMediaFields: some View {
    AdaptiveHStackVStack {
      twitterField
      instagramField
    }
  }

  @ViewBuilder
  private var twitterField: some View {
    FormFieldWrapper(label: "Twitter Handle", error: formErrors.twitterHandle) {
      TextField("@handle", text: $formState.twitterHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused($focusedField, equals: .twitter)
        .onSubmit {
          onValidateField(\.twitterHandle, formState.twitterHandle)
        }
        .accessibilityLabel(String(localized: "Twitter handle, optional"))
        .accessibilityHint("Enter coach's Twitter handle")
    }
  }

  @ViewBuilder
  private var instagramField: some View {
    FormFieldWrapper(label: "Instagram Handle", error: formErrors.instagramHandle) {
      TextField("@handle", text: $formState.instagramHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused($focusedField, equals: .instagram)
        .onSubmit {
          onValidateField(\.instagramHandle, formState.instagramHandle)
        }
        .accessibilityLabel(String(localized: "Instagram handle, optional"))
        .accessibilityHint("Enter coach's Instagram handle")
    }
  }

  // MARK: - Notes

  @ViewBuilder
  private var notesField: some View {
    FormFieldWrapper(label: "Notes", error: formErrors.notes) {
      VStack(spacing: 4) {
        ZStack(alignment: .topLeading) {
          if formState.notes.isEmpty {
            Text("Any notes about this coach...")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)
              .padding(.vertical, 8)
          }

          TextEditor(text: $formState.notes)
            .frame(minHeight: 100)
            .disabled(isDisabled)
            .focused($focusedField, equals: .notes)
            .onChange(of: focusedField) { _, newFocus in
              if newFocus != .notes && !formState.notes.isEmpty {
                onValidateField(\.notes, formState.notes)
              }
            }
        }
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .accessibilityLabel(String(localized: "Notes, optional"))
        .accessibilityHint("Enter any notes about this coach")

        HStack {
          Spacer()
          Text("\(formState.notes.count) / \(CoachFormState.notesCharacterLimit)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

#Preview {
  Form {
    CoachFormView(
      formState: .constant(CoachFormState()),
      formErrors: .constant(CoachFormErrors.empty),
      isDisabled: false,
      onValidateField: { _, _ in },
      onValidateRole: { _ in }
    )
  }
}
