import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TimelineViewModel")

@Observable
@MainActor
final class TimelineViewModel {

  nonisolated deinit {}
  var tasksByGrade: [Int: [TaskWithStatus]] = [:]
  var currentPhase: TimelinePhase = .freshman
  var statusScore: StatusScore?
  var milestoneProgress: MilestoneProgress?
  var canAdvancePhase = false
  var graduationYear: Int?
  var isLoading = false
  var errorMessage: String?
  var expandedPhaseGrade: Int? = 9
  var showSuccessMessage = false

  var isViewingAsParent: Bool { familyManager.isParentViewingAthlete }
  var currentAthleteId: String? {
    if let athlete = familyManager.selectedAthlete { return athlete.userId }
    return authManager.user?.id
  }

  private let tasksService: any TasksManaging
  private let phaseService: any TimelinePhaseManaging
  private let statusService: any TimelineStatusManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  var allTasks: [TaskWithStatus] {
    tasksByGrade.values.flatMap { $0 }
  }

  var taskCompletedCount: Int {
    allTasks.filter { $0.effectiveStatus == .completed }.count
  }

  var taskTotalCount: Int {
    allTasks.count
  }

  var milestonesCompletedCount: Int {
    milestoneProgress?.completedCount ?? 0
  }

  var milestonesTotalCount: Int {
    milestoneProgress?.totalCount ?? 0
  }

  var statusLabel: StatusLabel? { statusScore?.label }
  var statusScoreValue: Int { statusScore?.score ?? 0 }

  init(
    tasksService: (any TasksManaging)? = nil,
    phaseService: (any TimelinePhaseManaging)? = nil,
    statusService: (any TimelineStatusManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil
  ) {
    self.tasksService = tasksService ?? TasksServiceImpl(supabaseManager: .shared)
    self.phaseService = phaseService ?? TimelinePhaseService()
    self.statusService = statusService ?? TimelineStatusService()
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? .shared
  }

  func load() async {
    guard let athleteId = currentAthleteId else {
      errorMessage = "Unable to load timeline."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let prefs: PlayerDetails? = try await preferenceService.fetchPreferences(category: .player)
      let tasksByGradeResult = try await tasksService.fetchAllTasksWithStatus(athleteId: athleteId)
      graduationYear = prefs?.graduationYear
      tasksByGrade = tasksByGradeResult

      let completedTaskIds = allTasksFrom(tasksByGradeResult)
        .filter { $0.effectiveStatus == .completed }
        .map(\.id)
      let allRequiredTaskIds = allTasksFrom(tasksByGradeResult)
        .filter(\.required)
        .map(\.id)

      async let phaseResult = phaseService.fetchPhaseAndMilestoneProgress(
        graduationYear: graduationYear,
        completedTaskIds: completedTaskIds,
        athleteId: athleteId
      )
      async let statusResult = statusService.fetchStatusScore(
        athleteId: athleteId,
        completedTaskIds: completedTaskIds,
        allRequiredTaskIds: allRequiredTaskIds
      )

      let (phaseData, status) = try await (phaseResult, statusResult)
      currentPhase = phaseData.phase
      milestoneProgress = phaseData.milestoneProgress
      canAdvancePhase = phaseData.canAdvance
      statusScore = status

      if expandedPhaseGrade == nil {
        expandedPhaseGrade = currentPhase.gradeLevel
      }

      logger.info("Timeline loaded: phase=\(phaseData.phase.rawValue), status=\(status.score)/100")
    } catch {
      logger.error("Failed to load timeline: \(error.localizedDescription)")
      errorMessage = "Failed to load timeline. Please try again."
    }
  }

  func refresh() async {
    await load()
  }

  func setExpandedPhase(grade: Int?) {
    expandedPhaseGrade = grade
  }

  func togglePhaseExpanded(grade: Int) {
    if expandedPhaseGrade == grade {
      expandedPhaseGrade = nil
    } else {
      expandedPhaseGrade = grade
    }
  }

  func markComplete(taskId: String) async {
    guard !isViewingAsParent else { return }
    guard let userId = authManager.user?.id else { return }

    guard let task = allTasks.first(where: { $0.id == taskId }), !task.isLocked else { return }

    do {
      _ = try await tasksService.updateTaskStatus(taskId: taskId, status: .completed, userId: userId)
      showSuccessMessage = true
      await refresh()
    } catch {
      logger.error("Failed to mark task complete: \(error.localizedDescription)")
      errorMessage = "Failed to update task. Please try again."
    }
  }

  func clearSuccessMessage() {
    showSuccessMessage = false
  }

  private func allTasksFrom(_ dict: [Int: [TaskWithStatus]]) -> [TaskWithStatus] {
    dict.values.flatMap { $0 }
  }


}
