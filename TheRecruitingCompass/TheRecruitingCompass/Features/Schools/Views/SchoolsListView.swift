import SwiftUI

struct SchoolsListView: View {
  @State private var viewModel = SchoolsListViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @State private var showAddSchool = false

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.allSchools.isEmpty {
        LoadingStateView(message: "Loading schools...")
      } else if viewModel.allSchools.isEmpty {
        SchoolEmptyState(isFiltered: false, onClearFilters: {})
      } else {
        schoolListContent
      }
    }
    .navigationTitle("Schools")
    .searchable(
      text: $viewModel.filters.searchText,
      prompt: "Search schools..."
    )
    .refreshable { await viewModel.loadSchools() }
    .task { await viewModel.loadSchools() }
    .confirmationDialog(
      "Delete School",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteSchool() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let school = viewModel.schoolToDelete {
        Text("Are you sure you want to delete \(school.name)? This action cannot be undone.")
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
          showAddSchool = true
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Add new school")
        .accessibilityHint("Opens form to add a new school")
      }
    }
    .navigationDestination(for: SchoolDestination.self) { destination in
      switch destination {
      case .detail(let schoolId):
        SchoolDetailView(schoolId: schoolId)
      case .add:
        Text("Add School")
      }
    }
    .sheet(isPresented: $showAddSchool) {
      Text("Add School Form")
    }
    .toast(
      isShowing: $viewModel.showSuccessToast,
      message: $viewModel.successMessage,
      type: .success,
      duration: 3.0
    )
  }

  // MARK: - List Content

  private var schoolListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        if !viewModel.allSchools.isEmpty {
          SchoolAnalyticsCards(analytics: viewModel.analytics)
            .padding(.bottom, 8)
        }

        SchoolFilterBar(
          filters: $viewModel.filters,
          availableStates: viewModel.availableStates,
          hasHomeLocation: viewModel.homeLocation != nil
        )
        .padding(.bottom, 8)

        if viewModel.activeFilterCount > 0 {
          SchoolActiveFilterChips(
            filters: $viewModel.filters,
            onClearAll: { viewModel.clearFilters() }
          )
          .padding(.bottom, 8)
        }

        if viewModel.showWarningBanner {
          WarningBanner(
            title: "Large School List",
            message: "You're tracking \(viewModel.allSchools.count) schools. Consider using filters to focus on your top choices."
          )
          .padding(.horizontal)
          .padding(.bottom, 8)
        }

        FilteredResultsHeader(
          resultCount: viewModel.resultCount,
          itemName: "school",
          activeFilterCount: viewModel.activeFilterCount
        )
        .padding(.horizontal)
        .padding(.bottom, 12)

        if viewModel.filteredSchools.isEmpty {
          SchoolEmptyState(
            isFiltered: true,
            onClearFilters: { viewModel.clearFilters() }
          )
        } else {
          schoolCards
        }
      }
    }
  }

  // MARK: - School Cards

  private var schoolCards: some View {
    ForEach(viewModel.filteredSchools) { school in
      NavigationLink(value: SchoolDestination.detail(school.id)) {
        SchoolCardView(
          school: school,
          onToggleFavorite: {
            Task { await viewModel.toggleFavorite(school: school) }
          },
          onDelete: {
            viewModel.confirmDelete(school: school)
          }
        )
        .padding(.horizontal)
        .padding(.bottom, 12)
      }
      .buttonStyle(.plain)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          viewModel.confirmDelete(school: school)
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .accessibilityLabel("Delete \(school.name)")
      }
    }
  }
}

#Preview {
  NavigationStack {
    SchoolsListView()
  }
  .environment(FamilyManager.shared)
}
