import SwiftUI
import CoreLocation

struct SchoolDetailView: View {
  let schoolId: String

  @StateObject private var viewModel: SchoolDetailViewModel
  @EnvironmentObject private var familyManager: FamilyManager
  @Environment(\.dismiss) private var dismiss

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = StateObject(wrappedValue: SchoolDetailViewModel(schoolId: schoolId))
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
    .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") { viewModel.errorMessage = nil }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
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
        statusPickerSection(school: school)

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

        basicInfoSection(school: school)

        // MARK: - Phase 3 Sections

        // Fit Score Section
        if let fitScore = viewModel.fitScore {
          FitScoreSection(fitScore: fitScore)
            .padding(.horizontal)
        } else if viewModel.isLoadingFitScore {
          ProgressView("Calculating fit score...")
            .padding()
            .accessibilityLabel("Calculating fit score")
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
            // TODO: Navigate to coaches list filtered by school
          }
        )
        .padding(.horizontal)

        // Quick Actions
        SchoolQuickActions(
          onLogInteraction: {
            // TODO: Navigate to add interaction
          },
          onSendEmail: {
            // TODO: Show email composer or alert
          },
          onManageCoaches: {
            // TODO: Navigate to coaches list
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
            .cornerRadius(12)
        }
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
    .confirmationDialog(
      "Delete School?",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task {
          await viewModel.deleteSchool {
            dismiss()
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete the school and all related data. This action cannot be undone.")
    }
    .alert("Delete Failed", isPresented: .constant(viewModel.deleteErrorMessage != nil)) {
      Button("OK") { viewModel.deleteErrorMessage = nil }
    } message: {
      if let error = viewModel.deleteErrorMessage {
        Text(error)
      }
    }
  }

  @ViewBuilder
  private func basicInfoSection(school: School) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Information")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button("Edit") {
          viewModel.startEditingBasicInfo()
        }
        .accessibilityLabel("Edit school information")
      }

      if let info = school.academicInfo {
        VStack(alignment: .leading, spacing: 8) {
          if let address = info.address {
            InfoRow(label: "Campus Address", value: address)
          }

          if let facility = info.baseballFacilityAddress {
            InfoRow(label: "Baseball Facility", value: facility)
          }

          if let mascot = info.mascot {
            InfoRow(label: "Mascot", value: mascot)
          }

          if let size = info.undergradSize {
            InfoRow(label: "Undergrad Size", value: size)
          }
        }
      }

      if let website = school.website {
        Link(destination: URL(string: "https://\(website)")!) {
          Label("Visit Website", systemImage: "safari")
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
    .padding(.horizontal)
    .sheet(isPresented: $viewModel.isEditingBasicInfo) {
      SchoolBasicInfoSheet(
        info: $viewModel.editedBasicInfo,
        onSave: { await viewModel.saveBasicInfo() },
        onCancel: { viewModel.cancelEditingBasicInfo() },
        isSaving: viewModel.isSavingBasicInfo
      )
    }
  }

  @ViewBuilder
  private func statusPickerSection(school: School) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recruiting Status")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      HStack {
        Menu {
          ForEach(SchoolStatus.allCases, id: \.self) { status in
            Button {
              Task { await viewModel.updateStatus(to: status) }
            } label: {
              HStack {
                Text(status.displayName)
                if status.rawValue == school.status {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack {
            Text((SchoolStatus(rawValue: school.status) ?? .interested).displayName)
              .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(Color(.systemGray6))
          .cornerRadius(8)
        }
        .disabled(viewModel.isUpdatingStatus)

        if viewModel.isUpdatingStatus {
          ProgressView()
            .accessibilityLabel("Updating status")
        }
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Recruiting status: \((SchoolStatus(rawValue: school.status) ?? .interested).displayName)")
    .accessibilityHint("Double tap to change status")
  }
}

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .top) {
      Text(label + ":")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.subheadline)
        .multilineTextAlignment(.trailing)
    }
  }
}

#Preview {
  NavigationStack {
    SchoolDetailView(schoolId: "preview-school-1")
  }
}
