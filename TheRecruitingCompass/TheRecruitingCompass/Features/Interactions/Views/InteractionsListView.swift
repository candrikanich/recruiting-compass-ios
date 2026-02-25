import SwiftUI

struct InteractionsListView: View {
  @State private var viewModel = InteractionsListViewModel()
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.allInteractions.isEmpty {
        LoadingStateView(message: "Loading interactions...")
      } else if viewModel.allInteractions.isEmpty {
        InteractionEmptyState(isFilteredEmpty: false, onClearFilters: nil)
      } else {
        interactionListContent
      }
    }
    .navigationTitle(viewModel.isAthlete ? "My Interactions" : "Interactions")
    .searchable(
      text: $viewModel.filters.searchText,
      prompt: "Subject, content..."
    )
    .refreshable { await viewModel.loadInteractions() }
    .task { await viewModel.loadInteractions() }
    .confirmationDialog(
      "Delete Interaction",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteInteraction() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let interaction = viewModel.interactionToDelete {
        let subject = interaction.subject ?? interaction.type.displayName
        Text("Are you sure you want to delete \"\(subject)\"? This action cannot be undone.")
      }
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.deleteErrorMessage != nil },
      set: { if !$0 { viewModel.deleteErrorMessage = nil } }
    )) {
      Button("OK") { viewModel.deleteErrorMessage = nil }
    } message: {
      if let error = viewModel.deleteErrorMessage {
        Text(error)
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          // TODO: Navigate to add interaction
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Log new interaction")
        .accessibilityHint("Opens form to log a new interaction")
      }
    }
    .toast(
      isShowing: $viewModel.showSuccessToast,
      message: $viewModel.successMessage,
      type: .success,
      duration: 3.0
    )
  }

  // MARK: - List Content

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

  private var filterSection: some View {
    InteractionFilterBar(
      filters: $viewModel.filters,
      showLoggedByFilter: viewModel.isParent,
      linkedAthletes: familyManager.athletes,
      currentUserId: familyManager.currentMember?.userId
    )
    .padding(.vertical, 8)
  }

  private var resultsHeader: some View {
    FilteredResultsHeader(
      resultCount: viewModel.resultCount,
      itemName: "interaction",
      activeFilterCount: viewModel.activeFilterCount
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  private var interactionCards: some View {
    ForEach(viewModel.filteredInteractions) { interaction in
      Button {
        // TODO: Navigate to interaction detail
      } label: {
        InteractionCard(
          interaction: interaction,
          schoolName: viewModel.schoolName(for: interaction.schoolId),
          coachName: viewModel.coachName(for: interaction.coachId)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
      }
      .buttonStyle(PlainButtonStyle())
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          viewModel.confirmDelete(interaction)
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    InteractionsListView()
  }
  .environment(FamilyManager.shared)
}
