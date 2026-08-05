import SwiftUI

struct InteractionsListView: View {
  @State private var viewModel = InteractionsListViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @State private var navigationPath = NavigationPath()
  @Binding private var externalNavigationPath: NavigationPath

  init(navigationPath: Binding<NavigationPath>? = nil) {
    self._externalNavigationPath = navigationPath ?? .constant(NavigationPath())
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
      contentView
        .navigationTitle(viewModel.isAthlete ? "My Interactions" : "Interactions")
        .searchable(text: $viewModel.filters.searchText, prompt: "Subject, content...")
        .refreshable { await viewModel.loadInteractions() }
        .task { await viewModel.loadInteractions() }
        .confirmationDialog("Delete Interaction", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
          Button("Delete", role: .destructive) { Task { await viewModel.deleteInteraction() } }
          Button("Cancel", role: .cancel) {}
        } message: {
          if let interaction = viewModel.interactionToDelete {
            let subject = interaction.subject ?? interaction.type.displayName
            Text("Are you sure you want to delete \"\(subject)\"? This action cannot be undone.")
          }
        }
        .alert("Error", isPresented: $viewModel.isShowingDeleteError) {
        } message: {
          if let error = viewModel.deleteErrorMessage { Text(error) }
        }
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              navigationPath.append(InteractionDestination.add)
            } label: {
              Image(systemName: "plus")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "Log new interaction"))
            .accessibilityHint("Opens form to log a new interaction")
          }
        }
        .navigationDestination(for: InteractionDestination.self) { destination in
          destinationView(for: destination)
        }
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

  @ViewBuilder
  private func destinationView(for destination: InteractionDestination) -> some View {
    switch destination {
    case .add, .addWithSchool:
      if let familyUnitId = familyManager.currentMember?.familyUnitId,
         let userId = authManager.user?.id {
        AddInteractionView(
          interactionsService: viewModel.interactionsService,
          familyUnitId: familyUnitId,
          userId: userId
        )
      } else {
        ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle.badge.xmark")
      }
    case .detail(let interactionId):
      if let familyUnitId = familyManager.currentMember?.familyUnitId {
        InteractionDetailView(
          interactionId: interactionId,
          familyUnitId: familyUnitId,
          interactionsService: viewModel.interactionsService
        )
      } else {
        ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle.badge.xmark")
      }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    VStack(spacing: 0) {
      if let loadError = viewModel.errorMessage {
        ErrorBanner(message: loadError) { viewModel.errorMessage = nil }
          .padding(.horizontal)
      }
      if viewModel.isLoading && viewModel.allInteractions.isEmpty {
        LoadingStateView(message: "Loading interactions...")
      } else if viewModel.allInteractions.isEmpty && viewModel.allCoaches.isEmpty {
        InteractionEmptyState(
          isFilteredEmpty: false,
          noCoaches: true,
          onClearFilters: nil
        )
      } else if viewModel.allInteractions.isEmpty {
        InteractionEmptyState(
          isFilteredEmpty: false,
          noCoaches: false,
          onClearFilters: nil,
          onAddInteraction: { navigationPath.append(InteractionDestination.add) }
        )
      } else {
        interactionListContent
      }
    }
  }

  // MARK: - List Content

  @ViewBuilder
  private var interactionListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // Privacy Notice (Athletes only)
        if viewModel.isAthlete {
          InteractionPrivacyNotice()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }

        // Analytics Dashboard
        if !viewModel.filteredInteractions.isEmpty {
          InteractionAnalyticsCards(analytics: viewModel.analytics)
            .padding(.bottom, 8)
        }

        // Filter Bar
        filterSection

        // Active Filter Chips
        if viewModel.filters.hasActiveFilters {
          InteractionActiveFilterChips(
            filters: $viewModel.filters,
            linkedAthletes: familyManager.athletes,
            currentUserId: familyManager.currentMember?.userId
          )
          .padding(.vertical, 8)
        }

        // Results Header
        resultsHeader

        // Empty State or Interaction Cards
        if viewModel.filteredInteractions.isEmpty {
          InteractionEmptyState(
            isFilteredEmpty: true,
            onClearFilters: { viewModel.clearFilters() }
          )
        } else {
          interactionCards
        }
      }
    }
  }

  @ViewBuilder
  private var filterSection: some View {
    InteractionFilterBar(
      filters: $viewModel.filters,
      showLoggedByFilter: viewModel.isParent,
      linkedAthletes: familyManager.athletes,
      currentUserId: familyManager.currentMember?.userId
    )
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var resultsHeader: some View {
    FilteredResultsHeader(
      resultCount: viewModel.resultCount,
      itemName: "interaction",
      activeFilterCount: viewModel.activeFilterCount
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var interactionCards: some View {
    ForEach(viewModel.filteredInteractions) { interaction in
      Button {
        navigationPath.append(InteractionDestination.detail(interaction.id))
      } label: {
        InteractionCard(
          interaction: interaction,
          schoolName: viewModel.schoolName(for: interaction.schoolId),
          coachName: viewModel.coachName(for: interaction.coachId),
          onDelete: { viewModel.confirmDelete(interaction) }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  InteractionsListView()
  .environment(FamilyManager.shared)
  .environment(AuthManager.shared)
}
