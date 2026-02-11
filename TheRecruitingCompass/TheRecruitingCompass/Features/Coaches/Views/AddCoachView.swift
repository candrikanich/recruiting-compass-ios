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

  var body: some View {
    Form {
      Form {
        // MARK: - Section 1: School Selection (Step 1)
        Section {
          if viewModel.isLoadingSchools {
            loadingSchoolsView
          } else if viewModel.schools.isEmpty {
            emptySchoolsView
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

        // MARK: - Section 2: Coach Form (Step 2 - Conditional)
        if viewModel.isFormVisible {
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

          // MARK: - Section 3: Actions
          Section {
            submitButton
            cancelButton
          }
        } else {
          // Prompt to select school
          Section {
            infoPrompt
          }
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
      .alert("Error", isPresented: .constant(viewModel.submitError != nil)) {
        Button("OK") {
          viewModel.submitError = nil
        }
      } message: {
        if let error = viewModel.submitError {
          Text(error)
        }
      }
    }
  }

  // MARK: - Loading Schools View

  private var loadingSchoolsView: some View {
    HStack {
      ProgressView()
        .accessibilityLabel("Loading schools")

      Text("Loading schools...")
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Empty Schools View

  private var emptySchoolsView: some View {
    VStack(spacing: 16) {
      Image(systemName: "building.2.fill")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      VStack(spacing: 4) {
        Text("No Schools Found")
          .font(.headline)
          .foregroundStyle(.primary)

        Text("You need to add a school before adding a coach")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        // TODO: Navigate to Add School
        // This will be implemented in Phase 6 (Integration & Navigation)
      } label: {
        Label("Add School", systemImage: "plus.circle.fill")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel("Add a school")
      .accessibilityHint("Navigate to add school page")
    }
    .padding()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No schools found. Add a school first.")
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
