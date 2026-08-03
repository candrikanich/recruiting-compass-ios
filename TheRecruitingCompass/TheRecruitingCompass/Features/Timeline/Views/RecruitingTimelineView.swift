import SwiftUI

struct RecruitingTimelineView: View {
  @State private var viewModel = TimelineViewModel()
  @Environment(FamilyManager.self) private var familyManager
  @State private var lockedTaskAlertTask: TaskWithStatus?

  private var headerTitle: String {
    if viewModel.isViewingAsParent, let athlete = familyManager.selectedAthlete {
      return "\(athlete.user?.fullName ?? "Athlete")'s Timeline"
    }
    return "Recruiting Timeline"
  }

  private var showLockedTaskAlert: Binding<Bool> {
    Binding(
      get: { lockedTaskAlertTask != nil },
      set: { if !$0 { lockedTaskAlertTask = nil } }
    )
  }

  private let phaseOrder: [(Int, TimelinePhase)] = [
    (9, .freshman),
    (10, .sophomore),
    (11, .junior),
    (12, .senior)
  ]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        TimelineParentBanner(
          isViewingAsParent: viewModel.isViewingAsParent,
          athleteName: familyManager.selectedAthlete?.user?.fullName ?? "Athlete",
          onDismiss: { familyManager.clearAthleteSelection() }
        )
        Text(headerTitle)
          .font(.title2.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
        TimelineAthleteSwitcher(
          isViewingAsParent: viewModel.isViewingAsParent,
          athletes: familyManager.athletes,
          selectedAthleteId: familyManager.selectedAthleteId,
          onSelect: { athleteId in
            familyManager.selectAthlete(athleteId)
            Task { await viewModel.load() }
          }
        )
        TimelineMainContent(
          isLoading: viewModel.isLoading,
          tasksByGrade: viewModel.tasksByGrade,
          errorMessage: viewModel.errorMessage,
          statusScoreValue: viewModel.statusScoreValue,
          statusLabel: viewModel.statusLabel,
          taskCompletedCount: viewModel.taskCompletedCount,
          taskTotalCount: viewModel.taskTotalCount,
          milestonesCompletedCount: viewModel.milestonesCompletedCount,
          milestonesTotalCount: viewModel.milestonesTotalCount,
          showSuccessMessage: viewModel.showSuccessMessage,
          currentPhase: viewModel.currentPhase,
          expandedPhaseGrade: viewModel.expandedPhaseGrade,
          isViewingAsParent: viewModel.isViewingAsParent,
          phaseOrder: phaseOrder,
          onTogglePhase: { grade in viewModel.togglePhaseExpanded(grade: grade) },
          onTaskCheckboxTap: { taskId in Task { await viewModel.markComplete(taskId: taskId) } },
          onLockedTaskTap: { lockedTaskAlertTask = $0 },
          onRetry: { Task { await viewModel.refresh() } }
        )
      }
      .padding(.vertical, 16)
    }
    .refreshable { await viewModel.refresh() }
    .task { await viewModel.load() }
    .onChange(of: familyManager.selectedAthleteId) { _, _ in
      Task { await viewModel.load() }
    }
    .alert("Complete Prerequisites First", isPresented: showLockedTaskAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      if let task = lockedTaskAlertTask {
        Text("Complete these tasks first: \(task.prerequisiteTasks.map(\.title).joined(separator: ", "))")
      }
    }
    .navigationTitle("Timeline")
    .accessibilityIdentifier("recruiting_timeline_view")
  }
}

// MARK: - Private Subviews

private struct TimelineParentBanner: View {
  let isViewingAsParent: Bool
  let athleteName: String
  let onDismiss: () -> Void

  var body: some View {
    if isViewingAsParent {
      TasksParentBanner(
        athleteName: athleteName,
        onDismiss: onDismiss
      )
    }
  }
}

private struct TimelineAthleteSwitcher: View {
  let isViewingAsParent: Bool
  let athletes: [FamilyMember]
  let selectedAthleteId: String?
  let onSelect: (String) -> Void

  var body: some View {
    if isViewingAsParent, !athletes.isEmpty {
      AthleteSelector(
        athletes: athletes,
        selectedAthleteId: selectedAthleteId,
        onSelect: onSelect
      )
      .padding(.horizontal)
    }
  }
}

private struct TimelineMainContent: View {
  let isLoading: Bool
  let tasksByGrade: [Int: [TaskWithStatus]]
  let errorMessage: String?
  let statusScoreValue: Int
  let statusLabel: StatusLabel?
  let taskCompletedCount: Int
  let taskTotalCount: Int
  let milestonesCompletedCount: Int
  let milestonesTotalCount: Int
  let showSuccessMessage: Bool
  let currentPhase: TimelinePhase?
  let expandedPhaseGrade: Int?
  let isViewingAsParent: Bool
  let phaseOrder: [(Int, TimelinePhase)]
  let onTogglePhase: (Int) -> Void
  let onTaskCheckboxTap: (String) -> Void
  let onLockedTaskTap: (TaskWithStatus) -> Void
  let onRetry: () -> Void

  private var allTasksEmpty: Bool {
    phaseOrder.allSatisfy { grade, _ in (tasksByGrade[grade] ?? []).isEmpty }
  }

  var body: some View {
    if isLoading, tasksByGrade.isEmpty {
      LoadingStateView(message: "Loading timeline...")
        .padding(.horizontal)
    } else if let error = errorMessage {
      InlineErrorView(message: error, onRetry: onRetry)
        .padding(.horizontal)
    } else if allTasksEmpty {
      ContentUnavailableView(
        "No Timeline Tasks",
        systemImage: "calendar",
        description: Text("Tasks for your recruiting phases will appear here.")
      )
    } else {
      TimelineStatPills(
        statusScore: statusScoreValue,
        statusLabel: statusLabel,
        taskCompleted: taskCompletedCount,
        taskTotal: taskTotalCount,
        milestonesCompleted: milestonesCompletedCount,
        milestonesTotal: milestonesTotalCount
      )
      .padding(.horizontal)

      if showSuccessMessage {
        Text("Great job! 🎉")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.successGreen)
          .padding(.vertical, 6)
          .accessibilityLabel("Great job")
      }

      ForEach(phaseOrder, id: \.0) { grade, phase in
        PhaseCard(
          phase: phase,
          tasks: tasksByGrade[grade] ?? [],
          isCurrentPhase: currentPhase == phase,
          isExpanded: expandedPhaseGrade == grade,
          isViewingAsParent: isViewingAsParent,
          onToggle: { onTogglePhase(grade) },
          onTaskCheckboxTap: { taskId in onTaskCheckboxTap(taskId) },
          onLockedTaskTap: { task in onLockedTaskTap(task) }
        )
        .padding(.horizontal)
      }
    }
  }
}

#Preview {
  NavigationStack {
    RecruitingTimelineView()
      .environment(FamilyManager.shared)
  }
}
