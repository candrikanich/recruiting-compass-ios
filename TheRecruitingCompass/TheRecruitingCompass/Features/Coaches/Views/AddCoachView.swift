//
//  AddCoachView.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 5: Main View - Two-step form flow for adding a coach
//

import SwiftUI

struct AddCoachView: View {
  @StateObject private var viewModel: AddCoachViewModel
  @Environment(\.dismiss) private var dismiss
  @Binding var navigationPath: NavigationPath

  init(
    coachesService: CoachesManaging,
    familyUnitId: String,
    userId: String,
    navigationPath: Binding<NavigationPath>
  ) {
    _viewModel = StateObject(wrappedValue: AddCoachViewModel(
      coachesService: coachesService,
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
      schoolSelectionSection

      if viewModel.isFormVisible {
        coachFormSection
        actionsSection
      } else {
        infoPromptSection
      }
    }
    .navigationTitle("Add Coach")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Back") {
            dismiss()
          }
          .accessibilityLabel("Back to coaches list")
        }
      }
      .task {
        await viewModel.loadSchools()
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

  private var schoolSelectionSection: some View {
    Section {
      if viewModel.isLoadingSchools {
        LoadingStateView(message: "Loading schools...")
      } else if viewModel.schools.isEmpty {
        EmptyStateView(
          icon: "building.2.fill",
          title: "No Schools Found",
          message: "You need to add a school before adding a coach",
          actionTitle: "Add School"
        ) {
          // TODO: Navigate to Add School
          // This will be implemented in Phase 6 (Integration & Navigation)
        }
      } else {
        SchoolPicker(
          selectedSchoolId: $viewModel.formState.selectedSchoolId,
          schools: viewModel.schools,
          isDisabled: viewModel.isSubmitting
        )
        .onChange(of: viewModel.formState.selectedSchoolId) {
          announceSchoolSelection()
        }
      }
    }
  }

  private var coachFormSection: some View {
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
      CoachFormView(
        formState: $viewModel.formState,
        formErrors: $viewModel.formErrors,
        isDisabled: viewModel.isSubmitting,
        onValidateField: viewModel.validateField,
        onValidateRole: viewModel.validateRole
      )
    }
  }

  private var actionsSection: some View {
    Section {
      submitButton
      cancelButton
    }
  }

  private var infoPromptSection: some View {
    Section {
      infoPrompt
    }
  }

  // MARK: - Info Prompt (Select School)

  private var infoPrompt: some View {
    HStack(spacing: 12) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(.blue)
        .accessibilityHidden(true)

      Text("Please select a school to continue")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Please select a school to continue adding a coach")
  }

  // MARK: - Submit Button

  private var submitButton: some View {
    Button {
      Task {
        if let newCoach = await viewModel.submitCoach() {
          // Navigate to coach detail
          navigationPath.append(CoachDestination.detail(newCoach.id))
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
        : "Create new coach"
    )
  }

  // MARK: - Cancel Button

  private var cancelButton: some View {
    Button("Cancel", role: .cancel) {
      dismiss()
    }
    .frame(minHeight: 44)
    .accessibilityLabel("Cancel adding coach")
    .accessibilityHint("Return to coaches list without saving")
  }

  // MARK: - Accessibility Announcements

  private func announceSchoolSelection() {
    guard let schoolId = viewModel.formState.selectedSchoolId,
          let school = viewModel.schools.first(where: { $0.id == schoolId }) else {
      return
    }

    let announcement = "School selected. \(school.name). Coach form now available."
    UIAccessibility.post(notification: .announcement, argument: announcement)
  }
}

// Preview requires service injection - see actual usage in CoachesListView navigation
