import SwiftUI

struct CoachesListView: View {
  let prefilterSchoolId: String?

  @State private var viewModel = CoachesListViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @State private var navigationPath = NavigationPath()

  init(prefilterSchoolId: String? = nil) {
    self.prefilterSchoolId = prefilterSchoolId
  }

  var body: some View {
    contentView
      .navigationTitle("Coaches")
      .searchable(
        text: $viewModel.filters.searchText,
        prompt: "Search coaches..."
      )
      .refreshable { await viewModel.loadCoaches() }
      .task {
        await viewModel.loadCoaches()
        if let schoolId = prefilterSchoolId {
          viewModel.filters.schoolId = schoolId
        }
      }
      .confirmationDialog(
        "Delete Coach",
        isPresented: $viewModel.showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          Task { await viewModel.deleteCoach() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        if let coach = viewModel.coachToDelete {
          Text("Are you sure you want to delete \(coach.fullName)? This action cannot be undone.")
        }
      }
      .alert("Error", isPresented: .constant(viewModel.deleteErrorMessage != nil)) {
        Button("OK") { viewModel.deleteErrorMessage = nil }
      } message: {
        if let error = viewModel.deleteErrorMessage {
          Text(error)
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            navigationPath.append(CoachDestination.add)
          } label: {
            Image(systemName: "plus")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Add new coach")
          .accessibilityHint("Opens form to add a new coach")
        }
      }
      .navigationDestination(for: CoachDestination.self) { destination in
        destinationView(for: destination)
      }
      .toast(
        isShowing: $viewModel.showSuccessToast,
        message: $viewModel.successMessage,
        type: .success,
        duration: 3.0
      )
  }

  // MARK: - Content View

  private var contentView: some View {
    Group {
      if viewModel.isLoading && viewModel.allCoaches.isEmpty {
        LoadingStateView(message: "Loading coaches...")
      } else if viewModel.allCoaches.isEmpty {
        CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
      } else {
        coachListContent
      }
    }
  }

  // MARK: - Destination View

  @ViewBuilder
  private func destinationView(for destination: CoachDestination) -> some View {
    switch destination {
    case .detail(let coachId):
      CoachDetailView(
        coachId: coachId,
        allCoaches: viewModel.allCoaches,
        allSchools: viewModel.allSchools
      )
    case .add:
      AddCoachView(
        coachesService: viewModel.coachesService,
        familyUnitId: familyManager.familyUnitId ?? "",
        userId: authManager.user?.id ?? "",
        navigationPath: $navigationPath
      )
    case .filteredBySchool(let schoolId):
      CoachesListView(prefilterSchoolId: schoolId)
    }
  }

  // MARK: - List Content

  private var coachListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        filterSection

        if viewModel.filters.hasActiveFilters {
          ActiveFilterChips(filters: $viewModel.filters)
            .padding(.vertical, 8)
        }

        resultsHeader

        if viewModel.filteredCoaches.isEmpty {
          CoachEmptyState(
            isFilteredEmpty: true,
            onClearFilters: { viewModel.clearFilters() }
          )
        } else {
          coachCards
        }
      }
    }
  }

  private var filterSection: some View {
    CoachFilterBar(filters: $viewModel.filters)
      .padding(.vertical, 8)
  }

  private var resultsHeader: some View {
    FilteredResultsHeader(
      resultCount: viewModel.resultCount,
      itemName: "coach",
      activeFilterCount: viewModel.activeFilterCount
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  private var coachCards: some View {
    ForEach(viewModel.filteredCoaches) { coach in
      NavigationLink(value: CoachDestination.detail(coach.id)) {
        CoachCardView(
          coach: coach,
          schoolName: viewModel.schoolName(for: coach.schoolId),
          onDelete: { viewModel.confirmDelete(coach) }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
      }
      .buttonStyle(PlainButtonStyle())
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          viewModel.confirmDelete(coach)
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    CoachesListView()
  }
  .environment(FamilyManager.shared)
  .environment(AuthManager.shared)
}
