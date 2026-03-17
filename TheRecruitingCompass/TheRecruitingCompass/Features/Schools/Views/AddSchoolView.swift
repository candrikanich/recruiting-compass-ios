//
//  AddSchoolView.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 6: Main View - Form flow for adding a school
//

import SwiftUI

struct AddSchoolView: View {
  @State private var viewModel: AddSchoolViewModel
  @Environment(\.dismiss) private var dismiss
  @Binding var navigationPath: NavigationPath

  init(
    schoolsService: SchoolsManaging,
    familyUnitId: String,
    userId: String,
    navigationPath: Binding<NavigationPath>
  ) {
    _viewModel = State(initialValue: AddSchoolViewModel(
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
      AddSchoolAutocompleteToggleSection(
        formState: $viewModel.formState,
        searchQuery: $viewModel.searchQuery,
        selectedCollege: viewModel.selectedCollege,
        scorecardData: viewModel.scorecardData,
        isEnrichmentLoading: viewModel.isEnrichmentLoading,
        isSearching: viewModel.isSearching,
        searchResults: viewModel.searchResults,
        searchError: viewModel.searchError,
        onSearchQueryChanged: { viewModel.handleSearchQueryChanged($0) },
        onSelectCollege: { college in
          Task { await viewModel.selectCollege(college) }
        },
        onClearSelection: { viewModel.clearSelection() }
      )
      AddSchoolFormSection(
        formState: $viewModel.formState,
        formErrors: $viewModel.formErrors,
        isSubmitting: viewModel.isSubmitting,
        onValidateField: viewModel.validateField,
        onCharacterCountChange: viewModel.announceCharacterCountIfNeeded,
        onClearErrors: { viewModel.clearErrors() },
        onNameChanged: { viewModel.handleNameChanged($0) }
      )
      AddSchoolActionsSection(
        isSubmitting: viewModel.isSubmitting,
        isSubmitDisabled: viewModel.isSubmitDisabled,
        submitButtonTitle: viewModel.submitButtonTitle,
        onSubmit: {
          Task {
            if let newSchool = await viewModel.submitSchool() {
              // Replace the Add School entry so back arrow returns to the list
              var path = NavigationPath()
              path.append(SchoolDestination.detail(newSchool.id))
              navigationPath = path
            }
          }
        },
        onCancel: { dismiss() }
      )
    }
    .navigationTitle("Add School")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          dismiss()
        } label: {
          Label("Back", systemImage: "chevron.left")
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
    .confirmationDialog(
      "Duplicate School Detected",
      isPresented: $viewModel.showDuplicateDialog,
      titleVisibility: .visible
    ) {
      Button("Cancel", role: .cancel) {
        viewModel.cancelDuplicate()
      }

      Button("Proceed Anyway") {
        Task {
          if let newSchool = await viewModel.proceedDespiteDuplicate() {
            navigationPath.append(SchoolDestination.detail(newSchool.id))
          }
        }
      }
    } message: {
      if let result = viewModel.duplicateResult,
         let duplicate = result.duplicate,
         let matchType = result.matchType {
        // ✅ Accessibility: Plain text for proper VoiceOver announcement
        Text(buildDuplicateMessage(duplicate: duplicate, matchType: matchType))
      }
    }
  }

  // MARK: - Helper Methods

  /// Builds an accessible message for the duplicate school dialog
  private func buildDuplicateMessage(duplicate: School, matchType: DuplicateMatchType) -> String {
    var message = "A school already exists that matches your entry:\n\n"
    message += "\(duplicate.name)\n\n"
    message += "Match Type: \(matchType.displayLabel)\n"

    if let location = duplicate.location {
      message += "Location: \(location)"
    }

    return message
  }
}

// MARK: - Private Subviews

private struct AddSchoolAutocompleteToggleSection: View {
  @Binding var formState: SchoolFormState
  @Binding var searchQuery: String
  let selectedCollege: CollegeSearchResult?
  let scorecardData: CollegeDataResult?
  let isEnrichmentLoading: Bool
  let isSearching: Bool
  let searchResults: [CollegeSearchResult]
  let searchError: String?
  let onSearchQueryChanged: (String) -> Void
  let onSelectCollege: (CollegeSearchResult) -> Void
  let onClearSelection: () -> Void

  var body: some View {
    Section {
      // Phase 2: Enable toggle (was disabled in MVP)
      Toggle("Search college database", isOn: $formState.isAutocompleteEnabled)
        .accessibilityLabel("Search college database toggle")
        .accessibilityHint("Enable to search and auto-fill from college database")
        .accessibilityAddTraits(.isButton)

      // Phase 2: Autocomplete search and selected college card
      if formState.isAutocompleteEnabled {
        if let selectedCollege {
          // Phase 3: Show selected college card with enrichment loading
          SelectedCollegeCard(
            college: selectedCollege,
            isEnrichmentLoading: isEnrichmentLoading,
            onClear: onClearSelection
          )

          // Phase 3: Show College Scorecard data if available
          if let scorecardData {
            CollegeScorecardDataDisplay(data: scorecardData)
          }
        } else {
          // Show search field
          VStack(spacing: 8) {
            TextField("Search for college...", text: $searchQuery)
              .textFieldStyle(.roundedBorder)
              .textContentType(.organizationName)
              .autocapitalization(.words)
              .accessibilityLabel("College search")
              .accessibilityHint("Type at least 3 characters to search")
              .onChange(of: searchQuery) { _, newValue in
                onSearchQueryChanged(newValue)
              }

            // Show character count hint if user has started typing but hasn't reached minimum
            if !searchQuery.isEmpty && searchQuery.count < 3 {
              Text("\(3 - searchQuery.count) more character\(searchQuery.count == 2 ? "" : "s") needed")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Show autocomplete dropdown if there are results or loading/error
            if isSearching || !searchResults.isEmpty || searchError != nil {
              SchoolAutocompleteDropdown(
                results: searchResults,
                isLoading: isSearching,
                error: searchError,
                onSelect: onSelectCollege
              )
            }
          }
        }
      }
    } header: {
      Text("College Information")
    } footer: {
      if formState.isAutocompleteEnabled {
        Text("Search by college name to auto-fill school information")
          .accessibilityLabel("Search by college name to auto-fill")
      } else {
        Text("Enable database search to auto-fill school information")
          .accessibilityLabel("Enable database search to auto-fill")
      }
    }
  }
}

private struct AddSchoolFormSection: View {
  @Binding var formState: SchoolFormState
  @Binding var formErrors: SchoolFormErrors
  let isSubmitting: Bool
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void
  let onCharacterCountChange: (Int) -> Void
  let onClearErrors: () -> Void
  let onNameChanged: (String) -> Void

  var body: some View {
    Section {
      // Error summary banner
      if formErrors.hasErrors {
        FormErrorSummary(
          errors: formErrors.allErrors,
          onDismiss: onClearErrors
        )
      }

      // All form fields
      SchoolFormView(
        formState: $formState,
        formErrors: $formErrors,
        isDisabled: isSubmitting,
        onValidateField: onValidateField,
        onNcaaLookup: nil, // NCAA lookup triggered via .onChange below
        onCharacterCountChange: onCharacterCountChange
      )
    }
    .onChange(of: formState.name) { _, newName in
      onNameChanged(newName)
    }
  }
}

private struct AddSchoolActionsSection: View {
  let isSubmitting: Bool
  let isSubmitDisabled: Bool
  let submitButtonTitle: String
  let onSubmit: () -> Void
  let onCancel: () -> Void

  var body: some View {
    Section {
      AddSchoolSubmitButton(
        isSubmitting: isSubmitting,
        isDisabled: isSubmitDisabled,
        title: submitButtonTitle,
        onTap: onSubmit
      )
      AddSchoolCancelButton(onTap: onCancel)
    }
  }
}

private struct AddSchoolSubmitButton: View {
  let isSubmitting: Bool
  let isDisabled: Bool
  let title: String
  let onTap: () -> Void

  var body: some View {
    Button {
      onTap()
    } label: {
      HStack(spacing: 8) {
        if isSubmitting {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
        }
        Text(title)
          .fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.borderedProminent)
    .disabled(isDisabled)
    .accessibilityLabel(title)
    .accessibilityHint(
      isDisabled
        ? "Fill all required fields to enable"
        : "Create new school"
    )
  }
}

private struct AddSchoolCancelButton: View {
  let onTap: () -> Void

  var body: some View {
    Button("Cancel", role: .cancel) {
      onTap()
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
