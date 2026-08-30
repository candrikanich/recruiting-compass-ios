import SwiftUI

struct SchoolDetailView: View {
  let schoolId: String

  @State private var viewModel: SchoolDetailViewModel
  @Environment(FamilyManager.self) private var familyManager
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.filterCoachesBySchool) private var filterCoachesBySchool
  @State private var navigationDestination: NavigationDestination?
  @State private var showHomeLocationSheet = false
  @State private var showAdvanceToast = false
  @State private var advanceToastMessage: String?
  private let preferenceService: any PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = State(initialValue: SchoolsFactory.makeDetailViewModel(schoolId: schoolId))
  }

  private enum NavigationDestination: Hashable {
    case addInteraction(schoolId: String)
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.school == nil {
        ScrollView {
          LoadingStateView(message: "Loading school...")
            .padding(.top, 100)
        }
      } else if let school = viewModel.school {
        detailContent(school: school)
      } else if let error = viewModel.errorMessage {
        ScrollView {
          InlineErrorView(message: error)
            .padding(.top, 100)
        }
      }
    }
    .navigationTitle("School Details")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
      if viewModel.school != nil {
        ToolbarItem(placement: .primaryAction) {
          Button {
            Task { await viewModel.toggleFavorite() }
          } label: {
            Image(systemName: (viewModel.school?.isFavorite ?? false) ? "star.fill" : "star")
              .foregroundStyle((viewModel.school?.isFavorite ?? false) ? .yellow : .gray)
          }
          .accessibilityLabel((viewModel.school?.isFavorite ?? false) ? String(localized: "Unfavorite") : String(localized: "Favorite"))
          .accessibilityIdentifier("favorite-button")
        }
      }
    }

    .refreshable {
      await viewModel.loadSchool()
    }
    .task {
      await viewModel.loadSchool()
      await viewModel.loadHomeLocation()
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert, presenting: viewModel.errorMessage) { _ in
    } message: { message in
      Text(message)
    }
    .confirmationDialog(
      "Delete School?",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { if await viewModel.deleteSchool() { dismiss() } }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete the school and all related data. This action cannot be undone.")
    }
    .sheet(isPresented: $showHomeLocationSheet, onDismiss: {
      Task { await viewModel.loadHomeLocation() }
    }) {
      NavigationStack {
        HomeLocationView(preferenceService: preferenceService)
      }
    }
    .sheet(isPresented: Binding(
      get: { !viewModel.enrichMatches.isEmpty },
      set: { if !$0 { viewModel.enrichMatches = [] } }
    )) {
      SchoolMatchChooserSheet(
        matches: viewModel.enrichMatches,
        onSelect: { match in Task { await viewModel.confirmEnrich(match) } },
        onCancel: { viewModel.enrichMatches = [] }
      )
    }
  }

  @ViewBuilder
  private func detailContent(school: School) -> some View {
    AdaptiveDetailLayout(sidebarPlacement: .trailing) {
      VStack(spacing: 24) {
        SchoolDetailHeader(
          school: school,
          onToggleFavorite: {
            Task { await viewModel.toggleFavorite() }
          }
        )

        Divider()

        // 2. Map
        SchoolMapView(
          school: school,
          homeLocation: viewModel.homeCoordinate,
          onSetHomeLocation: { showHomeLocationSheet = true }
        )

        // 3. Information
        SchoolBasicInfoDisplaySection(
          school: school,
          onEdit: { viewModel.startEditingBasicInfo() }
        )

        // 4. College data
        CollegeDataSection(
          school: school,
          isLookingUp: viewModel.isLookingUpCollegeData,
          lookupError: viewModel.collegeDataError,
          onLookup: { await viewModel.lookupCollegeData() }
        )

        // 4b. Recruiting questionnaire — gates the completion line in outreach.
        Toggle(isOn: Binding(
          get: { school.questionnaireCompleted },
          set: { newValue in Task { await viewModel.setQuestionnaireCompleted(newValue) } }
        )) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Recruiting questionnaire completed")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Enables the \"I've completed your recruiting questionnaire\" line in coach outreach for this school.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityLabel(String(localized: "Recruiting questionnaire completed"))

        // 8. Coaching philosophy
        SchoolCoachingPhilosophySection(
          philosophy: EditableCoachingPhilosophy.from(school: school),
          onEdit: { viewModel.startEditingCoachingPhilosophy() }
        )

        // 9. Pros/cons
        SchoolProsConsSection(
          pros: school.pros,
          cons: school.cons,
          newPro: $viewModel.newPro,
          newCon: $viewModel.newCon,
          onAddPro: { await viewModel.addPro() },
          onRemovePro: { index in await viewModel.removePro(at: index) },
          onAddCon: { await viewModel.addCon() },
          onRemoveCon: { index in await viewModel.removeCon(at: index) },
          isAddingPro: viewModel.isAddingPro,
          isAddingCon: viewModel.isAddingCon
        )

        // 9b. Coach-outreach answers — reused to prefill Quick Comm ({{programNote}} / {{fitReason}}).
        SchoolNotesSection(
          title: String(localized: "Why this program"),
          notes: $viewModel.editedWhyProgram,
          onBlur: { await viewModel.saveOutreachNotes() }
        )
        SchoolNotesSection(
          title: String(localized: "Why it fits you"),
          notes: $viewModel.editedFitReason,
          onBlur: { await viewModel.saveOutreachNotes() }
        )

        // 10. Notes
        SchoolNotesSection(
          title: String(localized: "Notes"),
          notes: $viewModel.editedNotes,
          onBlur: { await viewModel.saveNotes() }
        )

        // 11. Documents
        SchoolDocumentsSection(schoolId: school.id)

        SchoolStatusHistorySection(history: viewModel.statusHistory)

        // Delete Button
        Button(role: .destructive) {
          viewModel.confirmDelete()
        } label: {
          Label("Delete School", systemImage: "trash")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("delete-school-button")
        .accessibilityLabel(String(localized: "Delete school"))
        .accessibilityHint("Permanently remove this school and all related data")
      }
    } sidebar: {
      SchoolDetailSidebar(
        school: school,
        viewModel: viewModel,
        onLogInteraction: {
          navigationDestination = .addInteraction(schoolId: schoolId)
        },
        onQuickComm: {
          let coaches = viewModel.coaches
          if coaches.count == 1, let coach = coaches.first {
            quickCommunicationContext = QuickCommunicationContext(
              coach: coach,
              schoolName: school.name
            )
          } else if coaches.count > 1 {
            showCoachPickerForQuickComm = true
          }
        },
        onManageCoaches: {
          filterCoachesBySchool(schoolId)
        },
        onAddCoach: {
          navigationDestination = .addCoach(schoolId: schoolId)
        },
        coachCount: viewModel.coaches.count
      )
    }
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .sheet(isPresented: $viewModel.isEditingCoachingPhilosophy) {
      SchoolCoachingPhilosophySheet(
        philosophy: $viewModel.editedCoachingPhilosophy,
        onSave: { await viewModel.saveCoachingPhilosophy() },
        onCancel: { viewModel.cancelEditingCoachingPhilosophy() },
        isSaving: viewModel.isSavingCoachingPhilosophy
      )
    }
    .navigationDestination(for: CoachDestination.self) { destination in
      if case .detail(let coachId) = destination {
        CoachDetailView(
          coachId: coachId,
          allCoaches: viewModel.coaches,
          allSchools: [school]
        )
      }
    }
    .navigationDestination(item: $navigationDestination) { destination in
      switch destination {
      case .addInteraction:
        if let familyUnitId = familyManager.familyUnitId, let userId = viewModel.currentUserId {
          AddInteractionView(
            interactionsService: InteractionsServiceImpl(supabaseManager: .shared),
            familyUnitId: familyUnitId,
            userId: userId,
            onLogged: { message in
              // Refresh so the status stepper reflects the auto-advance, and
              // confirm it with a toast.
              Task { await viewModel.loadSchool() }
              if let message {
                advanceToastMessage = message
                showAdvanceToast = true
              }
            }
          )
        } else {
          ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle.badge.xmark")
        }
      }
    }
    .sheet(isPresented: $viewModel.isEditingBasicInfo) {
      SchoolBasicInfoSheet(
        info: $viewModel.editedBasicInfo,
        onSave: { await viewModel.saveBasicInfo() },
        onCancel: { viewModel.cancelEditingBasicInfo() },
        isSaving: viewModel.isSavingBasicInfo
      )
    }
    .toast(
      isShowing: $showAdvanceToast,
      message: $advanceToastMessage,
      type: .success,
      duration: 3.0
    )
  }
}

#Preview {
  NavigationStack {
    SchoolDetailView(schoolId: "preview-school-1")
  }
}
