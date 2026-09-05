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
  @State private var quickCommunicationContext: QuickCommunicationContext?
  @State private var showCoachPickerForQuickComm = false
  @State private var showAddCoach = false
  @State private var realtimeService: SchoolDetailRealtimeService?
  private let preferenceService: any PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = State(initialValue: SchoolsFactory.makeDetailViewModel(schoolId: schoolId))
  }

  private enum NavigationDestination: Hashable {
    case addInteraction(schoolId: String)
    case coachDetail(coachId: String)
  }

  var body: some View {
    Group {
      if let school = viewModel.school {
        detailContent(school: school)
      } else if let error = viewModel.errorMessage {
        ScrollView {
          InlineErrorView(message: error)
            .padding(.top, 100)
        }
      } else {
        ScrollView {
          LoadingStateView(message: "Loading school...")
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
      await subscribeRealtime()
    }
    .onDisappear {
      let service = realtimeService
      realtimeService = nil
      Task { await service?.unsubscribe() }
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

  private func subscribeRealtime() async {
    guard realtimeService == nil else { return }
    let service = SchoolDetailRealtimeService()
    realtimeService = service
    do {
      try await service.subscribe(schoolId: schoolId) { [viewModel] in
        Task { await viewModel.loadSchool() }
      }
    } catch {
      // Non-fatal — page still works with pull-to-refresh
    }
  }

  @ViewBuilder
  private func detailContent(school: School) -> some View {
    AdaptiveDetailLayout(sidebarPlacement: .trailing) {
      VStack(spacing: 24) {
        headerSection(school: school)
        Divider()
        mapSection(school: school)
        contactSocialSection(school: school)
        collegeDataSection(school: school)
        questionnaireToggle(school: school)
        coachingPhilosophySection(school: school)
        prosConsSection(school: school)
        outreachNotesSection(school: school)
        notesSection
        documentsSection(school: school)
        statusHistorySection
        deleteButton
      }
    } sidebar: {
      sidebar(school: school)
    } compact: {
      VStack(spacing: 24) {
        headerSection(school: school)
        Divider()
        statusSection(school: school)
        mapSection(school: school)
        contactSocialSection(school: school)
        collegeDataSection(school: school)
        quickActionsSection(school: school)
        coachesSection(school: school)
        questionnaireToggle(school: school)
        outreachNotesSection(school: school)
        schoolFitSection
        prosConsSection(school: school)
        notesSection
        coachingPhilosophySection(school: school)
        documentsSection(school: school)
        attributionSection(school: school)
        statusHistorySection
        deleteButton
      }
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
    .navigationDestination(item: $navigationDestination) { destination in
      switch destination {
      case .coachDetail(let coachId):
        CoachDetailView(
          coachId: coachId,
          allCoaches: viewModel.coaches,
          allSchools: [school]
        )
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
    .sheet(item: $quickCommunicationContext) { context in
      QuickCommunicationView(context: context)
    }
    .confirmationDialog("Select Coach", isPresented: $showCoachPickerForQuickComm) {
      ForEach(viewModel.coaches) { coach in
        Button(coach.fullName) {
          quickCommunicationContext = QuickCommunicationContext(
            coach: coach,
            schoolName: viewModel.school?.name
          )
        }
      }
    }
    .sheet(isPresented: $showAddCoach) {
      NavigationStack {
        AddCoachView(
          coachesService: CoachesServiceImpl(supabaseManager: .shared),
          familyUnitId: familyManager.familyUnitId ?? "",
          userId: viewModel.currentUserId ?? "",
          navigationPath: .constant(NavigationPath()),
          preselectedSchoolId: schoolId
        )
      }
    }
  }

  // MARK: - Sections (shared between the iPad two-column layout and the
  // single-column iPhone order)

  @ViewBuilder
  private func headerSection(school: School) -> some View {
    SchoolDetailHeader(
      school: school,
      onToggleFavorite: {
        Task { await viewModel.toggleFavorite() }
      }
    )
  }

  @ViewBuilder
  private func statusSection(school: School) -> some View {
    SchoolRecruitingStatusAndTierSection(
      currentStatus: SchoolStatus(rawValue: school.status) ?? .interested,
      isUpdatingStatus: viewModel.isUpdatingStatus,
      onStatusChange: { await viewModel.updateStatus(to: $0) }
    )
  }

  @ViewBuilder
  private func mapSection(school: School) -> some View {
    SchoolMapView(
      school: school,
      homeLocation: viewModel.homeCoordinate,
      onSetHomeLocation: { showHomeLocationSheet = true }
    )
  }

  @ViewBuilder
  private func contactSocialSection(school: School) -> some View {
    SchoolBasicInfoDisplaySection(
      school: school,
      onEdit: { viewModel.startEditingBasicInfo() }
    )
  }

  @ViewBuilder
  private func collegeDataSection(school: School) -> some View {
    CollegeDataSection(
      school: school,
      isLookingUp: viewModel.isLookingUpCollegeData,
      lookupError: viewModel.collegeDataError,
      onLookup: { await viewModel.lookupCollegeData() }
    )
  }

  private func onQuickComm(school: School) {
    let coaches = viewModel.coaches
    if coaches.count == 1, let coach = coaches.first {
      quickCommunicationContext = QuickCommunicationContext(
        coach: coach,
        schoolName: school.name
      )
    } else if coaches.count > 1 {
      showCoachPickerForQuickComm = true
    }
  }

  @ViewBuilder
  private func quickActionsSection(school: School) -> some View {
    SchoolQuickActions(
      onLogInteraction: { navigationDestination = .addInteraction(schoolId: schoolId) },
      onQuickComm: { onQuickComm(school: school) },
      onManageCoaches: { filterCoachesBySchool(schoolId) },
      coachCount: viewModel.coaches.count
    )
  }

  @ViewBuilder
  private func coachesSection(school: School) -> some View {
    SchoolCoachesPanel(
      coaches: viewModel.coaches,
      isLoading: viewModel.isLoadingCoaches,
      onSeeAll: { filterCoachesBySchool(schoolId) },
      onAddCoach: { showAddCoach = true },
      onSelectCoach: { coachId in navigationDestination = .coachDetail(coachId: coachId) },
      schoolName: school.name,
      onQuickCommunication: { context in quickCommunicationContext = context }
    )
  }

  @ViewBuilder
  private func questionnaireToggle(school: School) -> some View {
    // Gates the completion line in outreach.
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
  }

  @ViewBuilder
  private func outreachNotesSection(school: School) -> some View {
    // Coach-outreach answers — reused to prefill Quick Comm ({{programNote}} / {{fitReason}}).
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
  }

  @ViewBuilder
  private var schoolFitSection: some View {
    SchoolFitSection(
      personalFit: viewModel.personalFit,
      academicFit: viewModel.academicFit,
      isEnriching: viewModel.isEnriching,
      enrichError: viewModel.enrichError,
      onLookup: { Task { await viewModel.lookupAcademicData() } }
    )
  }

  @ViewBuilder
  private func prosConsSection(school: School) -> some View {
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
  }

  @ViewBuilder
  private var notesSection: some View {
    SchoolNotesSection(
      title: String(localized: "Notes"),
      notes: $viewModel.editedNotes,
      onBlur: { await viewModel.saveNotes() }
    )
  }

  @ViewBuilder
  private func coachingPhilosophySection(school: School) -> some View {
    SchoolCoachingPhilosophySection(
      philosophy: EditableCoachingPhilosophy.from(school: school),
      onEdit: { viewModel.startEditingCoachingPhilosophy() }
    )
  }

  @ViewBuilder
  private func documentsSection(school: School) -> some View {
    SchoolDocumentsSection(schoolId: school.id)
  }

  @ViewBuilder
  private func attributionSection(school: School) -> some View {
    SchoolAttributionSection(
      createdBy: school.createdBy,
      createdAt: school.createdAt,
      updatedBy: school.updatedBy,
      updatedAt: school.updatedAt
    )
  }

  @ViewBuilder
  private var statusHistorySection: some View {
    SchoolStatusHistorySection(history: viewModel.statusHistory)
  }

  @ViewBuilder
  private var deleteButton: some View {
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

  @ViewBuilder
  private func sidebar(school: School) -> some View {
    SchoolDetailSidebar(
      school: school,
      viewModel: viewModel,
      onLogInteraction: { navigationDestination = .addInteraction(schoolId: schoolId) },
      onQuickComm: { onQuickComm(school: school) },
      onManageCoaches: { filterCoachesBySchool(schoolId) },
      onAddCoach: { showAddCoach = true },
      onSelectCoach: { coachId in navigationDestination = .coachDetail(coachId: coachId) },
      onQuickCommunication: { context in quickCommunicationContext = context },
      coachCount: viewModel.coaches.count
    )
  }
}

#Preview {
  NavigationStack {
    SchoolDetailView(schoolId: "preview-school-1")
  }
}
