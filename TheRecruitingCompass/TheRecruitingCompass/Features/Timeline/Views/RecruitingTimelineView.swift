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

  private let phaseOrder: [(Int, TimelinePhase)] = [
    (9, .freshman),
    (10, .sophomore),
    (11, .junior),
    (12, .senior),
  ]

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
    .task { await viewModel.load() }
    .onChange(of: familyManager.selectedAthleteId) { _, _ in
      Task { await viewModel.load() }
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
    .navigationTitle("Timeline")
    .accessibilityIdentifier("recruiting_timeline_view")
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
          Task { await viewModel.load() }
        }
      )
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    if viewModel.isLoading, viewModel.tasksByGrade.isEmpty {
      loadingPlaceholders
    } else if let error = viewModel.errorMessage {
      errorBanner(message: error)
    } else {
      TimelineStatPills(
        statusScore: viewModel.statusScoreValue,
        statusLabel: viewModel.statusLabel,
        taskCompleted: viewModel.taskCompletedCount,
        taskTotal: viewModel.taskTotalCount,
        milestonesCompleted: viewModel.milestonesCompletedCount,
        milestonesTotal: viewModel.milestonesTotalCount
      )
      .padding(.horizontal)

      if viewModel.showSuccessMessage {
        Text("Great job! 🎉")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.successGreen)
          .padding(.vertical, 6)
          .accessibilityLabel("Great job")
      }

      ForEach(phaseOrder, id: \.0) { grade, phase in
        PhaseCard(
          phase: phase,
          tasks: viewModel.tasksByGrade[grade] ?? [],
          isCurrentPhase: viewModel.currentPhase == phase,
          isExpanded: viewModel.expandedPhaseGrade == grade,
          isViewingAsParent: viewModel.isViewingAsParent,
          onToggle: { viewModel.togglePhaseExpanded(grade: grade) },
          onTaskCheckboxTap: { taskId in
            Task { await viewModel.markComplete(taskId: taskId) }
          },
          onLockedTaskTap: { lockedTaskAlertTask = $0 }
        )
        .padding(.horizontal)
      }
    }
  }

  private var loadingPlaceholders: some View {
    VStack(spacing: 12) {
      ForEach(0..<4, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.tertiarySystemFill))
          .frame(height: 100)
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
}

#Preview {
  NavigationStack {
    RecruitingTimelineView()
      .environment(FamilyManager.shared)
  }
}
