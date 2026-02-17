import SwiftUI

struct TasksListView: View {
  @State private var viewModel = TasksListViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @State private var lockedTaskAlertTask: TaskWithStatus?
  @State private var successMessageDismissWork: Task<Void, Never>?

  private var headerTitle: String {
    if viewModel.isViewingAsParent, let athlete = familyManager.selectedAthlete {
      return "\(athlete.user?.fullName ?? "Athlete")'s Tasks"
    }
    return "My Tasks"
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        parentBannerIfNeeded
        Text(headerTitle)
          .font(.title2.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
        mainContent
      }
      .padding(.vertical, 16)
    }
    .refreshable { await viewModel.refresh() }
    .task { await viewModel.loadTasks() }
    .onChange(of: viewModel.showSuccessMessage) { _, show in
      if show {
        successMessageDismissWork = Task {
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          await MainActor.run { viewModel.clearSuccessMessage() }
        }
      }
    }
    .alert("Complete Prerequisites First", isPresented: Binding(
      get: { lockedTaskAlertTask != nil },
      set: { if !$0 { lockedTaskAlertTask = nil } }
    )) {
      Button("OK", role: .cancel) { lockedTaskAlertTask = nil }
    } message: {
      if let task = lockedTaskAlertTask {
        Text("Complete these tasks first: \(task.prerequisiteTasks.map(\.title).joined(separator: ", "))")
      }
    }
    .navigationTitle("Tasks")
    .accessibilityIdentifier("tasks_list_view")
  }

  @ViewBuilder
  private var parentBannerIfNeeded: some View {
    if viewModel.isViewingAsParent {
      TasksParentBanner(
        athleteName: familyManager.selectedAthlete?.user?.fullName ?? "Athlete",
        onDismiss: { familyManager.clearAthleteSelection() }
      )
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    if viewModel.isLoading, viewModel.tasks.isEmpty {
      loadingPlaceholders
    } else if let error = viewModel.errorMessage {
      errorBanner(message: error)
    } else {
      TasksProgressCard(
        completed: viewModel.progressCompleted,
        total: viewModel.progressTotal,
        percentage: viewModel.progressPercentage
      )
      .padding(.horizontal)

      TasksFilterBar(statusFilter: Binding(
        get: { viewModel.statusFilter },
        set: { viewModel.setStatusFilter($0) }
      ), urgencyFilter: Binding(
        get: { viewModel.urgencyFilter },
        set: { viewModel.setUrgencyFilter($0) }
      ))
      .padding(.top, 4)

      if viewModel.showSuccessMessage {
        Text("Great job! 🎉")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.successGreen)
          .padding(.vertical, 6)
          .accessibilityLabel("Great job")
      }

      if viewModel.filteredTasks.isEmpty {
        emptyState
      } else {
        ForEach(viewModel.filteredTasks) { task in
          taskCardRow(task)
        }
      }
    }
  }

  private func taskCardRow(_ task: TaskWithStatus) -> some View {
    TaskCard(
      task: task,
      isExpanded: viewModel.expandedTaskId == task.id,
      isViewingAsParent: viewModel.isViewingAsParent,
      onToggleExpand: { viewModel.toggleExpanded(taskId: task.id) },
      onCheckboxTap: { Task { await viewModel.markComplete(taskId: task.id) } },
      onLockedCheckboxTap: task.isLocked ? { lockedTaskAlertTask = task } : nil
    )
    .padding(.horizontal)
  }

  private var loadingPlaceholders: some View {
    VStack(spacing: 12) {
      ForEach(0..<5, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.tertiarySystemFill))
          .frame(height: 80)
      }
    }
    .padding(.horizontal)
  }

  private func errorBanner(message: String) -> some View {
    VStack(spacing: 8) {
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
      Button("Retry") {
        Task { await viewModel.refresh() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.errorRed.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
  }

  private var emptyState: some View {
    Text("No tasks available for this grade level")
      .font(.body)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 40)
      .accessibilityLabel("No tasks available for this grade level")
  }
}

#Preview {
  NavigationStack {
    TasksListView()
      .environment(FamilyManager.shared)
  }
}
