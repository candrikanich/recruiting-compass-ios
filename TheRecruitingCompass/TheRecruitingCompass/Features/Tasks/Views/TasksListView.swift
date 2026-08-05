import SwiftUI

struct TasksListView: View {
  @State private var viewModel = TasksListViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @State private var lockedTaskAlertTask: TaskWithStatus?
  @State private var successMessageDismissWork: Task<Void, Never>?

  private var statusFilterBinding: Binding<TaskStatusFilter> {
    Binding(
      get: { viewModel.statusFilter },
      set: { viewModel.setStatusFilter($0) }
    )
  }

  private var urgencyFilterBinding: Binding<TaskUrgencyFilter> {
    Binding(
      get: { viewModel.urgencyFilter },
      set: { viewModel.setUrgencyFilter($0) }
    )
  }

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
        athleteSwitcherIfNeeded
        mainContent
      }
      .padding(.vertical, 16)
    }
    .refreshable { await viewModel.refresh() }
    .task { await viewModel.loadTasks() }
    .onChange(of: viewModel.showSuccessMessage) { _, show in
      if show {
        successMessageDismissWork?.cancel()
        successMessageDismissWork = Task {
          try? await Task.sleep(for: .seconds(3))
          guard !Task.isCancelled else { return }
          viewModel.clearSuccessMessage()
        }
      }
    }
    .alert("Complete Prerequisites First", isPresented: Binding(
      get: { lockedTaskAlertTask != nil },
      set: { if !$0 { lockedTaskAlertTask = nil } }
    )) {
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
  private var athleteSwitcherIfNeeded: some View {
    if viewModel.isViewingAsParent, !familyManager.athletes.isEmpty {
      AthleteSelector(
        athletes: familyManager.athletes,
        selectedAthleteId: familyManager.selectedAthleteId,
        onSelect: { athleteId in
          familyManager.selectAthlete(athleteId)
          Task { await viewModel.loadTasks() }
        }
      )
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    if viewModel.isLoading, viewModel.tasks.isEmpty {
      LoadingStateView(message: "Loading tasks...")
    } else if let error = viewModel.errorMessage {
      InlineErrorView(message: error, onRetry: { Task { await viewModel.refresh() } })
        .padding(.horizontal)
    } else {
      TasksProgressCard(
        completed: viewModel.progressCompleted,
        total: viewModel.progressTotal,
        percentage: viewModel.progressPercentage
      )
      .padding(.horizontal)

      TasksFilterBar(statusFilter: statusFilterBinding, urgencyFilter: urgencyFilterBinding)
      .padding(.top, 4)

      if viewModel.showSuccessMessage {
        Text("Great job! 🎉")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.successGreen)
          .padding(.vertical, 6)
          .accessibilityLabel(String(localized: "Great job"))
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

  @ViewBuilder
  private var emptyState: some View {
    ContentUnavailableView(
      "No Tasks",
      systemImage: "checkmark.circle",
      description: Text("No tasks available for this grade level")
    )
  }
}

#Preview {
  NavigationStack {
    TasksListView()
      .environment(FamilyManager.shared)
  }
}
