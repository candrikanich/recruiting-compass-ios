import SwiftUI
import CoreLocation

struct SchoolDetailView: View {
  let schoolId: String

  @State private var viewModel: SchoolDetailViewModel
  @Environment(FamilyManager.self) private var familyManager
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var navigationDestination: NavigationDestination?

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = State(initialValue: SchoolDetailViewModel(schoolId: schoolId))
  }

  private enum NavigationDestination: Hashable {
    case coaches(schoolId: String)
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
        ErrorStateView(message: error)
          .padding(.top, 100)
      }
    }
    .navigationTitle("School Details")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable {
      await viewModel.loadSchool()
    }
    .task {
      await viewModel.loadSchool()
    }
    .alert(item: $viewModel.activeAlert) { alert in
      switch alert {
      case .error(let message):
        return Alert(
          title: Text("Error"),
          message: Text(message),
          dismissButton: .default(Text("OK"))
        )
      case .deleteError(let message):
        return Alert(
          title: Text("Delete Failed"),
          message: Text(message),
          dismissButton: .default(Text("OK"))
        )
      case .deleteConfirmation:
        return Alert(
          title: Text("Delete School?"),
          message: Text("This will permanently delete the school and all related data. This action cannot be undone."),
          primaryButton: .destructive(Text("Delete")) {
            Task {
              await viewModel.deleteSchool {
                dismiss()
              }
            }
          },
          secondaryButton: .cancel()
        )
      }
    }
  }

  private var homeLocation: CLLocationCoordinate2D? {
    guard let lat = familyManager.familyUnit?.homeLatitude,
          let lon = familyManager.familyUnit?.homeLongitude else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
        SchoolStatusPickerSection(
          currentStatus: SchoolStatus(rawValue: school.status) ?? .interested,
          isUpdating: viewModel.isUpdatingStatus,
          onStatusChange: { newStatus in
            await viewModel.updateStatus(to: newStatus)
          }
        )

        PriorityTierSelector(
          selectedTier: school.priorityTier.flatMap { PriorityTier(rawValue: $0) },
          isUpdating: viewModel.isUpdatingPriorityTier,
          onSelect: { tier in
            await viewModel.updatePriorityTier(tier)
          }
        )

        SchoolStatusHistorySection(history: viewModel.statusHistory)
          .padding(.horizontal)

        // MARK: - Phase 2 Sections

        SchoolNotesSection(
          title: "Notes",
          notes: school.notes ?? "",
          isPrivate: false,
          isEditing: viewModel.isEditingNotes,
          editedNotes: $viewModel.editedNotes,
          onEdit: { viewModel.startEditingNotes() },
          onSave: { await viewModel.saveNotes() },
          onCancel: { viewModel.cancelEditingNotes() },
          isSaving: viewModel.isSavingNotes
        )
        .padding(.horizontal)

        SchoolNotesSection(
          title: "Private Notes",
          notes: viewModel.privateNoteForCurrentUser,
          isPrivate: true,
          isEditing: viewModel.isEditingPrivateNotes,
          editedNotes: $viewModel.editedPrivateNotes,
          onEdit: { viewModel.startEditingPrivateNotes() },
          onSave: { await viewModel.savePrivateNotes() },
          onCancel: { viewModel.cancelEditingPrivateNotes() },
          isSaving: viewModel.isSavingPrivateNotes
        )
        .padding(.horizontal)

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

        SchoolBasicInfoDisplaySection(
          school: school,
          onEdit: { viewModel.startEditingBasicInfo() }
        )

        // MARK: - Phase 3 Sections

        // Fit Score Section
        if let fitScore = viewModel.fitScore {
          FitScoreSection(fitScore: fitScore)
            .padding(.horizontal)
        } else if viewModel.isLoadingFitScore {
          HStack {
            Spacer()
            ProgressView("Calculating fit score...")
              .padding()
              .accessibilityLabel("Calculating fit score, please wait")
            Spacer()
          }
        }

        // Division Recommendation Banner
        if let recommendation = viewModel.divisionRecommendation {
          DivisionRecommendationBanner(recommendation: recommendation)
            .padding(.horizontal)
        }

        // Map View
        SchoolMapView(
          school: school,
          homeLocation: homeLocation
        )
        .padding(.horizontal)

        // College Data Section
        CollegeDataSection(
          school: school,
          isLookingUp: viewModel.isLookingUpCollegeData,
          lookupError: viewModel.collegeDataError,
          onLookup: { await viewModel.lookupCollegeData() }
        )
        .padding(.horizontal)

        // MARK: - Phase 4 Sections

        // Coaches Panel
        SchoolCoachesPanel(
          coaches: viewModel.coaches,
          isLoading: viewModel.isLoadingCoaches,
          onSeeAll: {
            navigationDestination = .coaches(schoolId: schoolId)
          }
        )
        .padding(.horizontal)

        // Quick Actions
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
            navigationDestination = .coaches(schoolId: schoolId)
          }
        )
        .padding(.horizontal)

        // Coaching Philosophy
        SchoolCoachingPhilosophySection(
          philosophy: EditableCoachingPhilosophy.from(school: school),
          onEdit: { viewModel.startEditingCoachingPhilosophy() }
        )
        .padding(.horizontal)

        // Documents
        SchoolDocumentsSection()
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
        .accessibilityLabel("Delete school")
        .accessibilityHint("Permanently remove this school and all related data")
      }
      .padding(.vertical)
    }
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
      case .coaches(let schoolId):
        CoachesListView(prefilterSchoolId: schoolId)
      case .addInteraction(let schoolId):
        Text("Add Interaction for School: \(schoolId)")
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
