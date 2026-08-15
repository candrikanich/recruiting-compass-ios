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
  private let preferenceService: any PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = State(initialValue: SchoolDetailViewModel(schoolId: schoolId))
  }

  private enum NavigationDestination: Hashable {
    case addInteraction(schoolId: String)
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading && viewModel.school == nil {
        LoadingStateView(message: "Loading school...")
          .padding(.top, 100)
      } else if let school = viewModel.school {
        detailContent(school: school)
      } else if let error = viewModel.errorMessage {
        InlineErrorView(message: error)
          .padding(.top, 100)
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
    VStack(spacing: 0) {
      SchoolDetailHeader(
        school: school,
        onToggleFavorite: {
          Task { await viewModel.toggleFavorite() }
        }
      )

      Divider()

      VStack(spacing: 24) {
        // 1. Recruiting status
        SchoolRecruitingStatusAndTierSection(
          currentStatus: SchoolStatus(rawValue: school.status) ?? .interested,
          isUpdatingStatus: viewModel.isUpdatingStatus,
          onStatusChange: { await viewModel.updateStatus(to: $0) }
        )

        // 2. Map
        SchoolMapView(
          school: school,
          homeLocation: viewModel.homeCoordinate,
          onSetHomeLocation: { showHomeLocationSheet = true }
        )
        .padding(.horizontal)

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
        .padding(.horizontal)

        // 5. School Fit (Personal + Academic)
        SchoolFitSection(
          personalFit: viewModel.personalFit,
          academicFit: viewModel.academicFit,
          isEnriching: viewModel.isEnriching,
          enrichError: viewModel.enrichError,
          onLookup: { Task { await viewModel.lookupAcademicData() } }
        )

        // 6. Quick actions
        SchoolQuickActions(
          onLogInteraction: {
            navigationDestination = .addInteraction(schoolId: schoolId)
          },
          onSendEmail: {
            if let firstCoach = viewModel.coaches.first,
               let email = firstCoach.email,
               let url = URL(string: "mailto:\(email)") {
              openURL(url)
            }
          },
          onManageCoaches: {
            filterCoachesBySchool(schoolId)
          }
        )
        .padding(.horizontal)

        // 7. Coaches
        SchoolCoachesPanel(
          coaches: viewModel.coaches,
          isLoading: viewModel.isLoadingCoaches,
          onSeeAll: {
            filterCoachesBySchool(schoolId)
          }
        )
        .padding(.horizontal)

        // 8. Coaching philosophy
        SchoolCoachingPhilosophySection(
          philosophy: EditableCoachingPhilosophy.from(school: school),
          onEdit: { viewModel.startEditingCoachingPhilosophy() }
        )
        .padding(.horizontal)

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
        .padding(.horizontal)

        // 10. Notes
        SchoolNotesSection(
          title: String(localized: "Notes"),
          notes: $viewModel.editedNotes,
          onBlur: { await viewModel.saveNotes() }
        )
        .padding(.horizontal)

        // 11. Documents
        SchoolDocumentsSection(schoolId: school.id)
          .padding(.horizontal)

        SchoolStatusHistorySection(history: viewModel.statusHistory)
          .padding(.horizontal)

        // Attribution
        SchoolAttributionSection(
          createdBy: school.createdBy,
          createdAt: school.createdAt,
          updatedBy: school.updatedBy,
          updatedAt: school.updatedAt
        )

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
        .padding(.horizontal)
        .padding(.bottom, 24)
        .accessibilityLabel(String(localized: "Delete school"))
        .accessibilityHint("Permanently remove this school and all related data")
      }
      .padding(.vertical)
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
            userId: userId
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
  }
}

#Preview {
  NavigationStack {
    SchoolDetailView(schoolId: "preview-school-1")
  }
}
