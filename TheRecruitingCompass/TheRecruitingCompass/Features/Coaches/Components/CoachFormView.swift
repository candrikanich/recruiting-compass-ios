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
    }
  }

  // MARK: - Role Picker

  private var rolePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Role")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Spacer()
      }

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
      .accessibilityLabel("Role, required")
      .accessibilityHint("Select the coach's role")

      FieldError(error: formErrors.role)
    }
  }

  // MARK: - Name Fields

  @ViewBuilder
  private var nameFields: some View {
    ViewThatFits {
      HStack(spacing: 16) {
        firstNameField
        lastNameField
      }

      VStack(spacing: 16) {
        firstNameField
        lastNameField
      }
    }
  }

  private var firstNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("First Name")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)
      }

      TextField("e.g., John", text: $formState.firstName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.givenName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused($focusedField, equals: .firstName)
        .onSubmit {
          onValidateField(\.firstName, formState.firstName)
        }
        .accessibilityLabel("First name, required")
        .accessibilityHint("Enter coach's first name")

      FieldError(error: formErrors.firstName)
    }
  }

  private var lastNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Last Name")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)
      }

      TextField("e.g., Smith", text: $formState.lastName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.familyName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused($focusedField, equals: .lastName)
        .onSubmit {
          onValidateField(\.lastName, formState.lastName)
        }
        .accessibilityLabel("Last name, required")
        .accessibilityHint("Enter coach's last name")

      FieldError(error: formErrors.lastName)
    }
  }

  // MARK: - Contact Info

  private var emailField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Email")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

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
        .accessibilityLabel("Email, optional")
        .accessibilityHint("Enter coach's email address")

      FieldError(error: formErrors.email)
    }
  }

  private var phoneField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Phone")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

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
        .accessibilityLabel("Phone, optional")
        .accessibilityHint("Enter coach's phone number")

      FieldError(error: formErrors.phone)
    }
  }

  // MARK: - Social Media

  @ViewBuilder
  private var socialMediaFields: some View {
    ViewThatFits {
      HStack(spacing: 16) {
        twitterField
        instagramField
      }

      VStack(spacing: 16) {
        twitterField
        instagramField
      }
    }
  }

  private var twitterField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Twitter Handle")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("@handle", text: $formState.twitterHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused($focusedField, equals: .twitter)
        .onSubmit {
          onValidateField(\.twitterHandle, formState.twitterHandle)
        }
        .accessibilityLabel("Twitter handle, optional")
        .accessibilityHint("Enter coach's Twitter handle")

      FieldError(error: formErrors.twitterHandle)
    }
  }

  private var instagramField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Instagram Handle")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("@handle", text: $formState.instagramHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused($focusedField, equals: .instagram)
        .onSubmit {
          onValidateField(\.instagramHandle, formState.instagramHandle)
        }
        .accessibilityLabel("Instagram handle, optional")
        .accessibilityHint("Enter coach's Instagram handle")

      FieldError(error: formErrors.instagramHandle)
    }
  }

  // MARK: - Notes

  private var notesField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Notes")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

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
      .accessibilityLabel("Notes, optional")
      .accessibilityHint("Enter any notes about this coach")

      HStack {
        Spacer()
        Text("\(formState.notes.count) / 5000")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      FieldError(error: formErrors.notes)
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
