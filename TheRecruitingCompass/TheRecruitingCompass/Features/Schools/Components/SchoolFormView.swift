//
//  SchoolFormView.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 6: View Components - School form fields with validation
//

import SwiftUI

struct SchoolFormView: View {
  @Binding var formState: SchoolFormState
  @Binding var formErrors: SchoolFormErrors
  let isDisabled: Bool
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void
  let onNcaaLookup: ((String) -> Void)? // Phase 1: Trigger NCAA lookup
  let onCharacterCountChange: ((Int) -> Void)? // Accessibility: Announce character count milestones

  @FocusState private var focusedField: Field?

  enum Field: Hashable {
    case name, location, city, state, conference, website, twitter, instagram, notes
  }

  var body: some View {
    VStack(spacing: 24) {
      SchoolFormNameField(
        formState: $formState,
        error: formErrors.name,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField,
        onNcaaLookup: onNcaaLookup
      )

      SchoolFormLocationFields(
        formState: $formState,
        formErrors: formErrors,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField
      )

      SchoolFormDivisionPicker(formState: $formState, error: formErrors.division, isDisabled: isDisabled)
      SchoolFormConferenceField(
        formState: $formState,
        error: formErrors.conference,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField
      )

      SchoolFormWebsiteField(
        formState: $formState,
        error: formErrors.website,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField
      )

      SchoolFormSocialMediaFields(
        formState: $formState,
        formErrors: formErrors,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField
      )

      SchoolFormNotesField(
        formState: $formState,
        error: formErrors.notes,
        isDisabled: isDisabled,
        focusedField: $focusedField,
        onValidateField: onValidateField,
        onCharacterCountChange: onCharacterCountChange
      )

      SchoolFormStatusPicker(formState: $formState, error: formErrors.status, isDisabled: isDisabled)
    }
  }
}

// MARK: - Name Field

private struct SchoolFormNameField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void
  let onNcaaLookup: ((String) -> Void)?

  var body: some View {
    FormFieldWrapper(label: "School Name", isRequired: true, error: error) {
      TextField("e.g., Harvard University", text: $formState.name)
        .textFieldStyle(.roundedBorder)
        .textContentType(.organizationName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .name)
        .onSubmit {
          onValidateField(\.name, formState.name)
          // Phase 1: Trigger NCAA lookup after validation
          onNcaaLookup?(formState.name)
        }
        .onChange(of: focusedField.wrappedValue) { oldValue, newValue in
          // Trigger NCAA lookup when name field loses focus
          if oldValue == .name && newValue != .name && !formState.name.isEmpty {
            onNcaaLookup?(formState.name)
          }
        }
        .accessibilityLabel("School name, required")
        .accessibilityHint("Enter the school's full name")
    }
  }
}

// MARK: - Location Fields

private struct SchoolFormLocationFields: View {
  @Binding var formState: SchoolFormState
  let formErrors: SchoolFormErrors
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    AdaptiveHStackVStack {
      SchoolFormCityField(
        formState: $formState,
        error: formErrors.city,
        isDisabled: isDisabled,
        focusedField: focusedField,
        onValidateField: onValidateField
      )
      SchoolFormStateField(
        formState: $formState,
        error: formErrors.state,
        isDisabled: isDisabled,
        focusedField: focusedField,
        onValidateField: onValidateField
      )
    }
  }
}

private struct SchoolFormCityField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "City", error: error) {
      TextField("e.g., Cambridge", text: $formState.city)
        .textFieldStyle(.roundedBorder)
        .textContentType(.addressCity)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .city)
        .onSubmit {
          onValidateField(\.city, formState.city)
        }
        .accessibilityLabel("City, optional")
        .accessibilityHint("Enter the city where the school is located")
    }
  }
}

private struct SchoolFormStateField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "State", error: error) {
      TextField("e.g., Massachusetts", text: $formState.state)
        .textFieldStyle(.roundedBorder)
        .textContentType(.addressState)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .state)
        .onSubmit {
          onValidateField(\.state, formState.state)
        }
        .accessibilityLabel("State, optional")
        .accessibilityHint("Enter the state where the school is located")
    }
  }
}

// MARK: - Division Picker

private struct SchoolFormDivisionPicker: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool

  var body: some View {
    FormFieldWrapper(label: "Division", error: error) {
      Picker("Division", selection: $formState.division) {
        Text("Select Division")
          .tag(nil as Division?)

        ForEach(Division.allCases, id: \.self) { division in
          Text(division.displayName)
            .tag(division as Division?)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      // ✅ Accessibility: Hide visual label (FormFieldWrapper provides semantic label)
      .labelsHidden()
      .accessibilityHint("Select the school's NCAA division")
    }
  }
}

// MARK: - Conference Field

private struct SchoolFormConferenceField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "Conference", error: error) {
      TextField("e.g., Ivy League", text: $formState.conference)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .conference)
        .onSubmit {
          onValidateField(\.conference, formState.conference)
        }
        .accessibilityLabel("Conference, optional")
        .accessibilityHint("Enter the athletic conference name")
    }
  }
}

// MARK: - Website Field

private struct SchoolFormWebsiteField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "Website", error: error) {
      TextField("https://example.edu", text: $formState.website)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.URL)
        .textContentType(.URL)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .website)
        .onSubmit {
          onValidateField(\.website, formState.website)
        }
        .accessibilityLabel("Website, optional")
        .accessibilityHint("Enter the school's website URL")
    }
  }
}

// MARK: - Social Media

private struct SchoolFormSocialMediaFields: View {
  @Binding var formState: SchoolFormState
  let formErrors: SchoolFormErrors
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    AdaptiveHStackVStack {
      SchoolFormTwitterField(
        formState: $formState,
        error: formErrors.twitterHandle,
        isDisabled: isDisabled,
        focusedField: focusedField,
        onValidateField: onValidateField
      )
      SchoolFormInstagramField(
        formState: $formState,
        error: formErrors.instagramHandle,
        isDisabled: isDisabled,
        focusedField: focusedField,
        onValidateField: onValidateField
      )
    }
  }
}

private struct SchoolFormTwitterField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "Twitter Handle", error: error) {
      TextField("@handle", text: $formState.twitterHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .twitter)
        .onSubmit {
          onValidateField(\.twitterHandle, formState.twitterHandle)
        }
        .accessibilityLabel("Twitter handle, optional")
        .accessibilityHint("Enter the school's Twitter handle")
    }
  }
}

private struct SchoolFormInstagramField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void

  var body: some View {
    FormFieldWrapper(label: "Instagram Handle", error: error) {
      TextField("@handle", text: $formState.instagramHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .instagram)
        .onSubmit {
          onValidateField(\.instagramHandle, formState.instagramHandle)
        }
        .accessibilityLabel("Instagram handle, optional")
        .accessibilityHint("Enter the school's Instagram handle")
    }
  }
}

// MARK: - Notes

private struct SchoolFormNotesField: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool
  var focusedField: FocusState<SchoolFormView.Field?>.Binding
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void
  let onCharacterCountChange: ((Int) -> Void)?

  var body: some View {
    FormFieldWrapper(label: "Notes", error: error) {
      VStack(spacing: 4) {
        ZStack(alignment: .topLeading) {
          if formState.notes.isEmpty {
            Text("Any notes about this school...")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)
              .padding(.vertical, 8)
          }

          TextEditor(text: $formState.notes)
            .frame(minHeight: 100)
            .disabled(isDisabled)
            .focused(focusedField, equals: .notes)
            .onChange(of: formState.notes) { _, newValue in
              // Accessibility: Announce character count milestones
              onCharacterCountChange?(newValue.count)
            }
            .onChange(of: focusedField.wrappedValue) { _, newFocus in
              if newFocus != .notes && !formState.notes.isEmpty {
                onValidateField(\.notes, formState.notes)
              }
            }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel("Notes, optional")
        .accessibilityHint("Enter any notes about this school")

        // Character count
        HStack {
          Spacer()
          Text("\(formState.notes.count) / \(SchoolFormState.notesCharacterLimit)")
            .font(.caption)
            .foregroundStyle(formState.notes.count > SchoolFormState.notesCharacterLimit ? .red : .secondary)
            .accessibilityLabel("\(formState.notes.count) characters entered, limit \(SchoolFormState.notesCharacterLimit)")
        }
      }
    }
  }
}

// MARK: - Status Picker

private struct SchoolFormStatusPicker: View {
  @Binding var formState: SchoolFormState
  let error: String?
  let isDisabled: Bool

  var body: some View {
    FormFieldWrapper(label: "Status", error: error) {
      Picker("Status", selection: $formState.status) {
        ForEach(SchoolStatus.allCases, id: \.self) { status in
          Text(status.displayName)
            .tag(status)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      // ✅ Accessibility: Hide visual label (FormFieldWrapper provides semantic label)
      .labelsHidden()
      .accessibilityHint("Select the recruiting status for this school")
    }
  }
}

#Preview {
  @Previewable @State var formState = SchoolFormState()
  @Previewable @State var formErrors = SchoolFormErrors.empty

  ScrollView {
    SchoolFormView(
      formState: $formState,
      formErrors: $formErrors,
      isDisabled: false,
      onValidateField: { _, _ in },
      onNcaaLookup: { _ in },
      onCharacterCountChange: { _ in }
    )
    .padding()
  }
}
