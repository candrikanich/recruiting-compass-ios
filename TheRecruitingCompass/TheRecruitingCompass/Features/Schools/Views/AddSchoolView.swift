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

  // Phase 2: Search debounce
  @State private var searchTask: Task<Void, Never>?

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
      autocompleteToggleSection
      schoolFormSection
      actionsSection
    }
    .navigationTitle("Add School")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
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

  // MARK: - Sections

  private var autocompleteToggleSection: some View {
    Section {
      // Phase 2: Enable toggle (was disabled in MVP)
      Toggle("Search college database", isOn: $viewModel.formState.isAutocompleteEnabled)
        .accessibilityLabel("Search college database toggle")
        .accessibilityHint("Enable to search and auto-fill from college database")
        .accessibilityAddTraits(.isButton)

      // Phase 2: Autocomplete search and selected college card
      if viewModel.formState.isAutocompleteEnabled {
        if let selectedCollege = viewModel.selectedCollege {
          // Phase 3: Show selected college card with enrichment loading
          SelectedCollegeCard(
            college: selectedCollege,
            isEnrichmentLoading: viewModel.isEnrichmentLoading,
            onClear: {
              viewModel.clearSelection()
            }
          )

          // Phase 3: Show College Scorecard data if available
          if let scorecardData = viewModel.scorecardData {
            CollegeScorecardDataDisplay(data: scorecardData)
          }
        } else {
          // Show search field
          VStack(spacing: 8) {
            TextField("Search for college...", text: $viewModel.searchQuery)
              .textFieldStyle(.roundedBorder)
              .textContentType(.organizationName)
              .autocapitalization(.words)
              .accessibilityLabel("College search")
              .accessibilityHint("Type at least 3 characters to search")
              .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                // Debounce search (300ms)
                searchTask?.cancel()
                searchTask = Task {
                  try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                  if !Task.isCancelled {
                    await viewModel.performAutocompleteSearch(query: newValue)
                  }
                }
              }

            // Show character count hint if user has started typing but hasn't reached minimum
            if !viewModel.searchQuery.isEmpty && viewModel.searchQuery.count < 3 {
              Text("\(3 - viewModel.searchQuery.count) more character\(viewModel.searchQuery.count == 2 ? "" : "s") needed")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Show autocomplete dropdown if there are results or loading/error
            if viewModel.isSearching || !viewModel.searchResults.isEmpty || viewModel.searchError != nil {
              SchoolAutocompleteDropdown(
                results: viewModel.searchResults,
                isLoading: viewModel.isSearching,
                error: viewModel.searchError,
                onSelect: { college in
                  Task {
                    await viewModel.selectCollege(college)
                  }
                }
              )
            }
          }
        }
      }
    } header: {
      Text("College Information")
    } footer: {
      if viewModel.formState.isAutocompleteEnabled {
        Text("Search by college name to auto-fill school information")
          .accessibilityLabel("Search by college name to auto-fill")
      } else {
        Text("Enable database search to auto-fill school information")
          .accessibilityLabel("Enable database search to auto-fill")
      }
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
        onValidateField: viewModel.validateField,
        onNcaaLookup: nil, // NCAA lookup triggered via .onChange below
        onCharacterCountChange: viewModel.announceCharacterCountIfNeeded
      )
    }
    .onChange(of: viewModel.formState.name) { _, newName in
      // Phase 1: Trigger NCAA lookup when school name changes
      if !newName.isEmpty && viewModel.formState.division == nil {
        Task {
          await viewModel.performNcaaLookup(for: newName)
        }
      }
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
          navigationPath.append(SchoolDestination.detail(newSchool.id))
        }
      }
    } label: {
      HStack(spacing: 8) {
        if viewModel.isSubmitting {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
        }
        Text(viewModel.submitButtonTitle)
          .fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.borderedProminent)
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
