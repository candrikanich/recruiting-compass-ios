import SwiftUI

/// Unified Deadlines page: user-created deadlines merged with NCAA
/// recruiting-calendar milestones, grouped by month, split into
/// Upcoming / Past. System items are read-only; user items support
/// swipe-to-delete.
struct DeadlinesListView: View {
  @State private var viewModel = DeadlinesListViewModel()
  @State private var deadlineToDelete: Deadline?
  @State private var isPastExpanded = false

  private var showDeleteConfirmation: Binding<Bool> {
    Binding(
      get: { deadlineToDelete != nil },
      set: { if !$0 { deadlineToDelete = nil } }
    )
  }

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isLoading && viewModel.deadlines.isEmpty && viewModel.milestones.isEmpty {
          loadingState
        } else if viewModel.unifiedDeadlines.isEmpty {
          emptyState
        } else {
          content
        }
      }
      .navigationTitle("Deadlines")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            viewModel.showAddSheet = true
          } label: {
            Image(systemName: "plus")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel(String(localized: "Add deadline"))
          .accessibilityHint("Opens form to create a new deadline")
        }
      }
      .task { await viewModel.loadDeadlines() }
      .refreshable { await viewModel.loadDeadlines() }
      .alert("Error", isPresented: $viewModel.isShowingErrorAlert, presenting: viewModel.errorMessage) { _ in
        Button("Retry") { Task { await viewModel.loadDeadlines() } }
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      } message: { error in
        Text(error)
      }
      .sheet(isPresented: $viewModel.showAddSheet) {
        AddDeadlineSheet(
          onSave: { label, date, category in
            let saved = await viewModel.addDeadline(label: label, date: date, category: category)
            if saved { viewModel.showAddSheet = false }
            return saved
          },
          onCancel: { viewModel.showAddSheet = false }
        )
      }
      .confirmationDialog("Remove Deadline?", isPresented: showDeleteConfirmation, titleVisibility: .visible) {
        if let deadlineToDelete {
          Button("Remove", role: .destructive) {
            Task { await viewModel.removeDeadline(deadlineToDelete) }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        if let deadlineToDelete {
          Text("Remove \"\(deadlineToDelete.label)\"? This cannot be undone.")
        }
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    List {
      if !viewModel.groupedUpcoming.isEmpty {
        Section("Upcoming") {
          ForEach(viewModel.groupedUpcoming, id: \.month) { group in
            monthGroup(group)
          }
        }
      }

      if !viewModel.groupedPast.isEmpty {
        Section {
          if isPastExpanded {
            ForEach(viewModel.groupedPast, id: \.month) { group in
              monthGroup(group)
            }
          }
        } header: {
          Button {
            withAnimation { isPastExpanded.toggle() }
          } label: {
            HStack {
              Text("Past")
              Spacer()
              Image(systemName: isPastExpanded ? "chevron.up" : "chevron.down")
            }
          }
          .accessibilityLabel(String(localized: "Past deadlines"))
          .accessibilityHint(isPastExpanded ? "Collapses past deadlines" : "Expands past deadlines")
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  @ViewBuilder
  private func monthGroup(_ group: (month: String, items: [UnifiedDeadline])) -> some View {
    ForEach(group.items) { item in
      row(item)
    }
  }

  @ViewBuilder
  private func row(_ item: UnifiedDeadline) -> some View {
    DeadlineRow(deadline: item)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        if let userDeadline = item.userDeadline {
          Button(role: .destructive) {
            deadlineToDelete = userDeadline
          } label: {
            Label("Remove", systemImage: "trash")
          }
        }
      }
  }

  // MARK: - States

  @ViewBuilder
  private var loadingState: some View {
    LoadingStateView(message: "Loading deadlines...")
      .accessibilityLabel(String(localized: "Loading deadlines"))
  }

  @ViewBuilder
  private var emptyState: some View {
    EmptyStateView(
      icon: "calendar.badge.exclamationmark",
      title: String(localized: "No Deadlines Yet"),
      message: String(localized: "Track application, visit, and recruiting deadlines."),
      actionTitle: String(localized: "Add Your First Deadline"),
      actionHint: String(localized: "Opens the form to create a deadline")
    ) {
      viewModel.showAddSheet = true
    }
    .frame(maxHeight: .infinity)
  }
}
