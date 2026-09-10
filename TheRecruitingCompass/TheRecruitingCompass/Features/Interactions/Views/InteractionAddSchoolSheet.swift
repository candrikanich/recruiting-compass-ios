import SwiftUI

/// Self-contained "add a school" sheet for the inbound-draft review form
/// (#125, parity w/ web #675). Reuses `AddSchoolViewModel` and the same form
/// sections as `AddSchoolView`, but completes via `onSchoolCreated` instead
/// of a `NavigationPath` push — keeping `AddInteractionViewModel` alive
/// underneath so the reviewer's in-progress edits are never disturbed.
struct InteractionAddSchoolSheet: View {
  @State private var viewModel: AddSchoolViewModel
  @Environment(\.dismiss) private var dismiss
  let onSchoolCreated: (School) -> Void

  init(
    schoolsService: any SchoolsManaging,
    familyUnitId: String,
    userId: String,
    prefillWebsite: String?,
    onSchoolCreated: @escaping (School) -> Void
  ) {
    let addViewModel = SchoolsFactory.makeAddViewModel(
      schoolsService: schoolsService,
      familyUnitId: familyUnitId,
      userId: userId
    )
    if let prefillWebsite {
      addViewModel.formState.website = prefillWebsite
    }
    _viewModel = State(initialValue: addViewModel)
    self.onSchoolCreated = onSchoolCreated
  }

  var body: some View {
    NavigationStack {
      Form {
        InteractionAddSchoolAutocompleteToggleSection(
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
        InteractionAddSchoolFormSection(
          formState: $viewModel.formState,
          formErrors: $viewModel.formErrors,
          isSubmitting: viewModel.isSubmitting,
          onValidateField: viewModel.validateField,
          onCharacterCountChange: viewModel.announceCharacterCountIfNeeded,
          onClearErrors: { viewModel.clearErrors() },
          onNameChanged: { viewModel.handleNameChanged($0) }
        )
      }
      .navigationTitle("Add School")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(viewModel.isSubmitting)
        }
        ToolbarItem(placement: .confirmationAction) {
          if viewModel.isSubmitting {
            ProgressView()
              .accessibilityLabel(String(localized: "Adding school"))
          } else {
            Button(viewModel.submitButtonTitle) {
              Task {
                if let newSchool = await viewModel.submitSchool() {
                  onSchoolCreated(newSchool)
                }
              }
            }
            .disabled(viewModel.isSubmitDisabled)
          }
        }
      }
      .alert("Error", isPresented: $viewModel.isShowingError) {
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

        Button("Use Existing School") {
          if let existing = viewModel.duplicateResult?.duplicate {
            onSchoolCreated(existing)
          }
        }

        Button("Proceed Anyway") {
          Task {
            if let newSchool = await viewModel.proceedDespiteDuplicate() {
              onSchoolCreated(newSchool)
            }
          }
        }
      } message: {
        if let result = viewModel.duplicateResult,
           let duplicate = result.duplicate,
           let matchType = result.matchType {
          Text(buildDuplicateMessage(duplicate: duplicate, matchType: matchType))
        }
      }
    }
  }

  private func buildDuplicateMessage(duplicate: School, matchType: DuplicateMatchType) -> String {
    var message = String(localized: "A school already exists that matches your entry:\n\n")
    message += "\(duplicate.name)\n\n"
    message += String(localized: "Match Type: \(matchType.displayLabel)\n")

    if let location = duplicate.location {
      message += String(localized: "Location: \(location)")
    }

    return message
  }
}

// MARK: - Private Subviews (mirrors AddSchoolView's composition)

private struct InteractionAddSchoolAutocompleteToggleSection: View {
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
      Toggle("Search college database", isOn: $formState.isAutocompleteEnabled)
        .accessibilityLabel(String(localized: "Search college database"))
        .accessibilityHint("Enable to search and auto-fill from college database")
        .accessibilityAddTraits(.isButton)

      if formState.isAutocompleteEnabled {
        if let selectedCollege {
          SelectedCollegeCard(
            college: selectedCollege,
            isEnrichmentLoading: isEnrichmentLoading,
            onClear: onClearSelection
          )

          if let scorecardData {
            CollegeScorecardDataDisplay(data: scorecardData)
          }
        } else {
          VStack(spacing: 8) {
            TextField("Search for college...", text: $searchQuery)
              .textFieldStyle(.roundedBorder)
              .textContentType(.organizationName)
              .autocapitalization(.words)
              .accessibilityLabel(String(localized: "College search"))
              .accessibilityHint("Type at least 3 characters to search")
              .onChange(of: searchQuery) { _, newValue in
                onSearchQueryChanged(newValue)
              }

            if !searchQuery.isEmpty && searchQuery.count < 3 {
              Text("\(3 - searchQuery.count) more character\(searchQuery.count == 2 ? "" : "s") needed")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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
          .accessibilityLabel(String(localized: "Search by college name to auto-fill"))
      } else {
        Text("Enable database search to auto-fill school information")
          .accessibilityLabel(String(localized: "Enable database search to auto-fill"))
      }
    }
  }
}

private struct InteractionAddSchoolFormSection: View {
  @Binding var formState: SchoolFormState
  @Binding var formErrors: SchoolFormErrors
  let isSubmitting: Bool
  let onValidateField: (KeyPath<SchoolFormState, String>, String) -> Void
  let onCharacterCountChange: (Int) -> Void
  let onClearErrors: () -> Void
  let onNameChanged: (String) -> Void

  var body: some View {
    Section {
      if formErrors.hasErrors {
        FormErrorSummary(
          errors: formErrors.allErrors,
          onDismiss: onClearErrors
        )
      }

      SchoolFormView(
        formState: $formState,
        formErrors: $formErrors,
        isDisabled: isSubmitting,
        onValidateField: onValidateField,
        onNcaaLookup: nil,
        onCharacterCountChange: onCharacterCountChange
      )
    }
    .onChange(of: formState.name) { _, newName in
      onNameChanged(newName)
    }
  }
}
