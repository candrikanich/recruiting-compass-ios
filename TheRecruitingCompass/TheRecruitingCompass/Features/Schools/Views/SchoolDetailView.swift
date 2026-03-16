import SwiftUI
import CoreLocation

struct SchoolDetailView: View {
  let schoolId: String

  @State private var viewModel: SchoolDetailViewModel
  @Environment(FamilyManager.self) private var familyManager
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var navigationDestination: NavigationDestination?

  private var showErrorAlert: Binding<Bool> {
    Binding(
      get: { viewModel.errorMessage != nil && !viewModel.showDeleteConfirmation },
      set: { if !$0 { viewModel.errorMessage = nil; viewModel.activeAlert = nil } }
    )
  }

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
          .accessibilityLabel((viewModel.school?.isFavorite ?? false) ? "Unfavorite" : "Favorite")
          .accessibilityIdentifier("favorite-button")
        }
      }
    }

    .refreshable {
      await viewModel.loadSchool()
    }
    .task {
      await viewModel.loadSchool()
    }
    .alert("Error", isPresented: showErrorAlert, presenting: viewModel.errorMessage) { _ in
      Button("OK") { viewModel.errorMessage = nil; viewModel.activeAlert = nil }
    } message: { message in
      Text(message)
    }
    .confirmationDialog(
      "Delete School?",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteSchool { dismiss() } }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete the school and all related data. This action cannot be undone.")
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
        // 1. Recruiting status
        SchoolRecruitingStatusAndTierSection(
          currentStatus: SchoolStatus(rawValue: school.status) ?? .interested,
          isUpdatingStatus: viewModel.isUpdatingStatus,
          onStatusChange: { await viewModel.updateStatus(to: $0) }
        )

        // 2. Map
        SchoolMapView(
          school: school,
          homeLocation: homeLocation
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

        // 5. School Fit analysis
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

        if let recommendation = viewModel.divisionRecommendation {
          DivisionRecommendationBanner(recommendation: recommendation)
            .padding(.horizontal)
        }

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
            navigationDestination = .coaches(schoolId: schoolId)
          }
        )
        .padding(.horizontal)

        // 7. Coaches
        SchoolCoachesPanel(
          coaches: viewModel.coaches,
          isLoading: viewModel.isLoadingCoaches,
          onSeeAll: {
            navigationDestination = .coaches(schoolId: schoolId)
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
          title: "Notes",
          notes: $viewModel.editedNotes,
          isPrivate: false,
          onBlur: { await viewModel.saveNotes() }
        )
        .padding(.horizontal)

        // 11. Private notes
        SchoolNotesSection(
          title: "Private Notes",
          notes: $viewModel.editedPrivateNotes,
          isPrivate: true,
          onBlur: { await viewModel.savePrivateNotes() }
        )
        .padding(.horizontal)

        // 12. Documents
        SchoolDocumentsSection()
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
