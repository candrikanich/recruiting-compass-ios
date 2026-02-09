import SwiftUI

struct SchoolsListView: View {
  @StateObject private var viewModel = SchoolsListViewModel()
  @EnvironmentObject private var familyManager: FamilyManager
  @State private var showAddSchool = false

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.allSchools.isEmpty {
        loadingView
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
        Text("School Detail: \(schoolId)")
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

  // MARK: - Loading

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .accessibilityLabel("Loading schools")
      Text("Loading schools...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - List Content

  private var schoolListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
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
          warningBanner
            .padding(.horizontal)
            .padding(.bottom, 8)
        }

        resultsHeader
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

  // MARK: - Warning Banner

  private var warningBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.orange)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("Large School List")
          .font(.subheadline)
          .fontWeight(.semibold)

        Text("You're tracking \(viewModel.allSchools.count) schools. Consider using filters to focus on your top choices.")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(12)
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Warning: You're tracking \(viewModel.allSchools.count) schools. Consider using filters.")
  }

  // MARK: - Results Header

  private var resultsHeader: some View {
    HStack {
      Text("\(viewModel.resultCount) \(viewModel.resultCount == 1 ? "school" : "schools")")
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)

      if viewModel.activeFilterCount > 0 {
        Text("(\(viewModel.activeFilterCount) \(viewModel.activeFilterCount == 1 ? "filter" : "filters") active)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(viewModel.resultCount) schools, \(viewModel.activeFilterCount) filters active")
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
      .environmentObject(FamilyManager.shared)
  }
}
