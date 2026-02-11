//
//  AddSchoolView.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 6: Main View - Form flow for adding a school
//

import SwiftUI

struct AddSchoolView: View {
  @StateObject private var viewModel: AddSchoolViewModel
  @Environment(\.dismiss) private var dismiss
  @Binding var navigationPath: NavigationPath

  init(
    schoolsService: SchoolsManaging,
    familyUnitId: String,
    userId: String,
    navigationPath: Binding<NavigationPath>
  ) {
    _viewModel = StateObject(wrappedValue: AddSchoolViewModel(
      schoolsService: schoolsService,
      familyUnitId: familyUnitId,
      userId: userId
    ))
    _navigationPath = navigationPath
  }

  // MARK: - Computed Properties

  private var isShowingError: Binding<Bool> {
    Binding(
      get: { viewModel.submitError != nil },
      set: { if !$0 { viewModel.submitError = nil } }
    )
  }

  var body: some View {
    Form {
      autocompleteToggleSection
      schoolFormSection
      actionsSection
    }
    .navigationTitle("Add School")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Back") {
          dismiss()
        }
        .accessibilityLabel("Back to schools list")
      }
    }
    .alert("Error", isPresented: isShowingError) {
      Button("OK", role: .cancel) { }
    } message: {
      if let error = viewModel.submitError {
        Text(error)
      }
    }
  }

  // MARK: - Sections

  private var autocompleteToggleSection: some View {
    Section {
      Toggle("Search college database", isOn: $viewModel.formState.isAutocompleteEnabled)
        .disabled(true) // MVP: Disabled, scaffolded for fast-follow
        .accessibilityLabel("Search college database toggle")
        .accessibilityHint("Enable to search and auto-fill from college database. Currently disabled in this version.")
        .accessibilityAddTraits(.isButton)

      if viewModel.formState.isAutocompleteEnabled {
        // Fast-follow: College Scorecard autocomplete will go here
        EmptyView()
      }
    } header: {
      Text("College Information")
    } footer: {
      Text("Enable database search to auto-fill school information (coming soon)")
        .accessibilityLabel("Database search feature coming soon")
    }
  }

  private var schoolFormSection: some View {
    Section {
      // Error summary banner
      if viewModel.formErrors.hasErrors {
        FormErrorSummary(
          errors: viewModel.formErrors.allErrors,
          onDismiss: {
            viewModel.clearErrors()
          }
        )
      }

      // All form fields
      SchoolFormView(
        formState: $viewModel.formState,
        formErrors: $viewModel.formErrors,
        isDisabled: viewModel.isSubmitting,
        onValidateField: viewModel.validateField
      )
    }
  }

  private var actionsSection: some View {
    Section {
      submitButton
      cancelButton
    }
  }

  // MARK: - Submit Button

  private var submitButton: some View {
    Button {
      Task {
        if let newSchool = await viewModel.submitSchool() {
          // Navigate to school detail
          navigationPath.append(SchoolDestination.detail(newSchool.id))
        }
      }
    } label: {
      HStack {
        Spacer()

        if viewModel.isSubmitting {
          ProgressView()
            .progressViewStyle(.circular)
        }

        Text(viewModel.submitButtonTitle)
          .fontWeight(.semibold)

        Spacer()
      }
      .frame(minHeight: 44)
    }
    .disabled(viewModel.isSubmitDisabled)
    .accessibilityLabel(viewModel.submitButtonTitle)
    .accessibilityHint(
      viewModel.isSubmitDisabled
        ? "Fill all required fields to enable"
        : "Create new school"
    )
  }

  // MARK: - Cancel Button

  private var cancelButton: some View {
    Button("Cancel", role: .cancel) {
      dismiss()
    }
    .frame(minHeight: 44)
    .accessibilityLabel("Cancel adding school")
    .accessibilityHint("Return to schools list without saving")
  }
}

#Preview {
  @Previewable @State var navigationPath = NavigationPath()

  NavigationStack(path: $navigationPath) {
    AddSchoolView(
      schoolsService: SchoolsServiceImpl(supabaseManager: SupabaseManager.shared),
      familyUnitId: "preview-family",
      userId: "preview-user",
      navigationPath: $navigationPath
    )
  }
}
