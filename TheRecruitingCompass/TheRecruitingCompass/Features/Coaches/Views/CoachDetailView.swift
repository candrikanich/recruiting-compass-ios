import SwiftUI

struct CoachDetailView: View {
  let coachId: String
  let allCoaches: [Coach]
  let allSchools: [School]

  @State private var viewModel: CoachDetailViewModel
  @State private var quickCommunicationContext: QuickCommunicationContext?
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.dismiss) private var dismiss

  init(coachId: String, allCoaches: [Coach] = [], allSchools: [School] = []) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    _viewModel = State(initialValue: CoachDetailViewModel(
      coachId: coachId,
      allCoaches: allCoaches,
      allSchools: allSchools
    ))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        LoadingStateView(message: "Loading coach details")
          .padding(.top, 100)
      } else if let coach = viewModel.coach {
        detailContent(coach: coach)
      } else if let error = viewModel.errorMessage {
        ErrorStateView(message: error)
          .padding(.top, 100)
      }
    }
    .navigationTitle("Coach Details")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button {
            if let coach = viewModel.coach {
              quickCommunicationContext = QuickCommunicationContext(
                coach: coach,
                schoolName: viewModel.school?.name
              )
            }
          } label: {
            Label("Quick Communication", systemImage: "envelope.badge")
          }
          .disabled(viewModel.isLoading || viewModel.coach == nil)

          Button {
            viewModel.startEditing()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          .disabled(viewModel.isLoading || viewModel.isSaving)

          Button(role: .destructive) {
            viewModel.confirmDelete()
          } label: {
            Label("Delete", systemImage: "trash")
          }
          .disabled(viewModel.isLoading || viewModel.isDeleting)
        } label: {
          Image(systemName: "ellipsis.circle")
            .accessibilityLabel("Coach actions menu")
        }
      }
    }
    .sheet(isPresented: $viewModel.isEditing) {
      if viewModel.editedCoach != nil {
        CoachEditForm(
          editedCoach: viewModel.editableCoachBinding,
          validationErrors: viewModel.validationErrors,
          isSaving: viewModel.isSaving,
          onSave: { await viewModel.saveChanges() },
          onCancel: { viewModel.cancelEditing() }
        )
      }
    }
    .sheet(item: $quickCommunicationContext) { context in
      QuickCommunicationView(context: context)
    }
    .confirmationDialog("Delete Coach", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        Task {
          await viewModel.deleteCoach()
          if viewModel.deleteSuccessMessage != nil {
            dismiss()
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this coach? This action cannot be undone.")
    }
    .refreshable {
      await viewModel.loadDetails()
    }
    .task {
      await viewModel.loadCoach()
      await viewModel.loadDetails()
    }
  }

  // MARK: - Content

  private func detailContent(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      CoachDetailHeader(coach: coach, school: viewModel.school)
      ContactInfoSection(coach: coach)

      if let stats = viewModel.stats {
        CoachStatsGrid(stats: stats)
      }

      CoachStatisticsSection(coach: coach)
      recentInteractionsSection
      sharedNotesSection
      privateNotesSection
    }
    .padding()
  }


  private var recentInteractionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Recent Interactions")

      if viewModel.recentInteractions.isEmpty {
        Text("No interactions yet")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
          .padding(.vertical, 8)
      } else {
        VStack(spacing: 0) {
          ForEach(viewModel.recentInteractions) { interaction in
            RecentInteractionRow(interaction: interaction)
            if interaction.id != viewModel.recentInteractions.last?.id {
              Divider()
                .padding(.vertical, 4)
                .accessibilityHidden(true)
            }
          }
        }
      }
    }
  }

  private var sharedNotesSection: some View {
    NotesSection(
      title: "Shared Notes",
      notes: viewModel.coach?.notes ?? "",
      isEditing: viewModel.isEditingSharedNotes,
      editedNotes: $viewModel.editedSharedNotes,
      onEdit: { viewModel.startEditingSharedNotes() },
      onSave: { await viewModel.saveSharedNotes() },
      onCancel: { viewModel.cancelEditingSharedNotes() },
      isPrivate: false,
      isSaving: viewModel.isSaving
    )
  }

  private var privateNotesSection: some View {
    NotesSection(
      title: "Private Notes",
      notes: viewModel.privateNoteForCurrentUser ?? "",
      isEditing: viewModel.isEditingPrivateNotes,
      editedNotes: $viewModel.editedPrivateNotes,
      onEdit: { viewModel.startEditingPrivateNotes() },
      onSave: { await viewModel.savePrivateNotes() },
      onCancel: { viewModel.cancelEditingPrivateNotes() },
      isPrivate: true,
      isSaving: viewModel.isSaving
    )
  }

}

#Preview {
  NavigationStack {
    CoachDetailView(
      coachId: "1",
      allCoaches: [
        Coach(
          id: "1",
          firstName: "John",
          lastName: "Smith",
          email: "john@university.edu",
          phone: "555-0123",
          position: "head",
          schoolId: "school-1",
          twitterHandle: "@coachsmith",
          instagramHandle: "@coachsmith",
          notes: "Great recruiter, very responsive",
          privateNotes: nil,
          responsivenessScore: 85,
          lastContactDate: "2026-01-15T10:00:00Z",
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2026-01-15T10:00:00Z"
        )
      ],
      allSchools: [
        School(
          id: "school-1",
          userId: "user-1",
          name: "State University",
          location: "State College, PA",
          city: "State College",
          state: "PA",
          division: "D1",
          conference: "Big Ten",
          ranking: 25,
          isFavorite: false,
          website: nil,
          faviconUrl: nil,
          twitterHandle: nil,
          instagramHandle: nil,
          ncaaId: nil,
          status: "interested",
          statusChangedAt: nil,
          priorityTier: "A",
          notes: nil,
          privateNotes: nil,
          pros: [],
          cons: [],
          offerDetails: nil,
          academicInfo: nil,
          amenities: nil,
          coachingPhilosophy: nil,
          coachingStyle: nil,
          recruitingApproach: nil,
          communicationStyle: nil,
          successMetrics: nil,
          fitScore: nil,
          fitTier: nil,
          familyUnitId: "family-1",
          createdBy: nil,
          updatedBy: nil,
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2025-01-01T00:00:00Z"
        )
      ]
    )
  }
}
