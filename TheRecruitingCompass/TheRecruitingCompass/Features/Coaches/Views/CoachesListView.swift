import SwiftUI

struct CoachesListView: View {
  private let prefilterSchoolId: Binding<String?>?

  @State private var viewModel = CoachesListViewModel()
  @State private var quickCommunicationContext: QuickCommunicationContext?
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @State private var navigationPath = NavigationPath()
  @Binding private var externalNavigationPath: NavigationPath

  init(prefilterSchoolId: Binding<String?>? = nil, navigationPath: Binding<NavigationPath>? = nil) {
    self.prefilterSchoolId = prefilterSchoolId
    self._externalNavigationPath = navigationPath ?? .constant(NavigationPath())
  }

  /// Applies an incoming school prefilter to the view model, then clears the
  /// source binding so the one-shot command can't get stuck (re-tapping "Manage
  /// Coaches" for the same school re-fires because the value changes from nil).
  private func consumePrefilterSchool() {
    guard let schoolId = prefilterSchoolId?.wrappedValue else { return }
    viewModel.filters.schoolId = schoolId
    prefilterSchoolId?.wrappedValue = nil
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
        consumePrefilterSchool()
      }
      .onChange(of: prefilterSchoolId?.wrappedValue) { _, _ in
        consumePrefilterSchool()
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
          .accessibilityLabel(String(localized: "Add new coach"))
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
    case .addSchool:
      AddSchoolView(
        schoolsService: SchoolsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyManager.familyUnitId ?? "",
        userId: authManager.user?.id ?? "",
        navigationPath: $navigationPath
      )
    case .filteredBySchool(let schoolId):
      CoachesListView(prefilterSchoolId: .constant(schoolId))
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
          ActiveFilterChips(filters: $viewModel.filters, schoolName: viewModel.schoolName(for:))
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
          variant: .full,
          showSchoolMeta: viewModel.filters.schoolId == nil,
          schoolName: viewModel.schoolName(for: coach.schoolId),
          schoolLogoUrl: viewModel.schoolLogoUrl(for: coach.schoolId),
          schoolInitials: viewModel.schoolInitials(for: coach.schoolId),
          onQuickCommunication: { context in
            quickCommunicationContext = context
          }
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
