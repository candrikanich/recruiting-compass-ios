import SwiftUI

struct CoachesListView: View {
  @StateObject private var viewModel = CoachesListViewModel()
  @EnvironmentObject private var familyManager: FamilyManager

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.allCoaches.isEmpty {
        loadingView
      } else if viewModel.allCoaches.isEmpty {
        CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
      } else {
        coachListContent
      }
    }
    .navigationTitle("Coaches")
    .searchable(text: $viewModel.filters.searchText, prompt: "Search coaches...")
    .refreshable { await viewModel.loadCoaches() }
    .task { await viewModel.loadCoaches() }
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
  }

  // MARK: - Loading

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .accessibilityLabel("Loading coaches")
      Text("Loading coaches...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    HStack {
      Text("\(viewModel.resultCount) coach\(viewModel.resultCount == 1 ? "" : "es")")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if viewModel.activeFilterCount > 0 {
        Text("(\(viewModel.activeFilterCount) filter\(viewModel.activeFilterCount == 1 ? "" : "s") active)")
          .font(.caption)
          .foregroundStyle(Color.accentBlue)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  private var coachCards: some View {
    ForEach(viewModel.filteredCoaches) { coach in
      CoachCardView(
        coach: coach,
        schoolName: viewModel.schoolName(for: coach.schoolId),
        onDelete: { viewModel.confirmDelete(coach) }
      )
      .padding(.horizontal, 16)
      .padding(.vertical, 4)
    }
  }
}

#Preview {
  NavigationStack {
    CoachesListView()
      .environmentObject(FamilyManager.shared)
  }
}
