import SwiftUI

struct CoachesListView: View {
  let prefilterSchoolId: String?

  @State private var viewModel = CoachesListViewModel()
  @State private var quickCommunicationContext: QuickCommunicationContext?
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @State private var navigationPath = NavigationPath()
  @Binding private var externalNavigationPath: NavigationPath

  init(prefilterSchoolId: String? = nil, navigationPath: Binding<NavigationPath>? = nil) {
    self.prefilterSchoolId = prefilterSchoolId
    self._externalNavigationPath = navigationPath ?? .constant(NavigationPath())
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
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
      .alert("Error", isPresented: $viewModel.isShowingDeleteError) {
        Button("OK") { viewModel.deleteErrorMessage = nil }
      } message: {
        if let error = viewModel.deleteErrorMessage {
          Text(error)
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
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
    }
    .sheet(item: $quickCommunicationContext) { context in
      QuickCommunicationView(context: context)
    }
    .toast(
        isShowing: $viewModel.showSuccessToast,
        message: $viewModel.successMessage,
        type: .success,
        duration: 3.0
      )
    .onChange(of: externalNavigationPath) { _, newPath in
      guard !newPath.isEmpty else { return }
      navigationPath = newPath
      externalNavigationPath = NavigationPath()
    }
  }

  // MARK: - Content View

  @ViewBuilder
  private var contentView: some View {
    VStack(spacing: 0) {
      if let loadError = viewModel.errorMessage {
        ErrorBanner(message: loadError) { viewModel.errorMessage = nil }
          .padding(.horizontal)
      }
      if viewModel.isLoading && viewModel.allCoaches.isEmpty {
        LoadingStateView(message: "Loading coaches...")
      } else if viewModel.allSchools.isEmpty {
        CoachEmptyState(
          isFilteredEmpty: false,
          noSchools: true,
          onClearFilters: nil
        )
      } else if viewModel.allCoaches.isEmpty {
        CoachEmptyState(
          isFilteredEmpty: false,
          noSchools: false,
          onClearFilters: nil,
          onAddCoach: { navigationPath.append(CoachDestination.add) }
        )
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

  @ViewBuilder
  private var coachListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        if !viewModel.allCoaches.isEmpty {
          CoachAnalyticsCards(analytics: viewModel.analytics)
            .padding(.bottom, 8)
        }

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

  @ViewBuilder
  private var filterSection: some View {
    CoachFilterBar(filters: $viewModel.filters)
      .padding(.vertical, 8)
  }

  @ViewBuilder
  private var resultsHeader: some View {
    FilteredResultsHeader(
      resultCount: viewModel.resultCount,
      itemName: "coach",
      itemNamePlural: "coaches",
      activeFilterCount: viewModel.activeFilterCount
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var coachCards: some View {
    ForEach(viewModel.filteredCoaches) { coach in
      NavigationLink(value: CoachDestination.detail(coach.id)) {
        CoachCardView(
          coach: coach,
          schoolName: viewModel.schoolName(for: coach.schoolId),
          schoolLogoUrl: viewModel.schoolLogoUrl(for: coach.schoolId),
          schoolInitials: viewModel.schoolInitials(for: coach.schoolId),
          onQuickCommunication: { context in
            quickCommunicationContext = context
          },
          onDelete: { viewModel.confirmDelete(coach) }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
      .contextMenu {
        Button {
          quickCommunicationContext = QuickCommunicationContext(
            coach: coach,
            schoolName: viewModel.schoolName(for: coach.schoolId)
          )
        } label: {
          Label("Quick Communication", systemImage: "envelope.badge")
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
