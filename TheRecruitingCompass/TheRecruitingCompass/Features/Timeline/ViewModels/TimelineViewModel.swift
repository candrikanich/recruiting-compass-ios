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

  /// Top-priority "what matters now" task for the current phase, from the shared
  /// web endpoint. Drives the dashboard summary card's current-task.
  var currentTask: WhatMattersItem?

  var isViewingAsParent: Bool { familyManager.isParentViewingAthlete }
  var currentAthleteId: String? {
    if let athlete = familyManager.selectedAthlete { return athlete.userId }
    return authManager.user?.id
  }

  private let tasksService: any TasksManaging
  private let apiService: any TimelineAPIManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  var allTasks: [TaskWithStatus] {
    tasksByGrade.values.flatMap { $0 }
  }

  var taskCompletedCount: Int {
    allTasks.count(where: { $0.effectiveStatus == .completed })
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
    apiService: (any TimelineAPIManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil
  ) {
    self.tasksService = tasksService ?? TasksServiceImpl(supabaseManager: .shared)
    self.apiService = apiService ?? TimelineAPIService()
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
      let token = authManager.session?.accessToken

      async let prefsResult = preferenceService.fetchPreferences(category: .player, userId: currentAthleteId) as PlayerDetails?
      async let tasksResult = tasksService.fetchAllTasksWithStatus(athleteId: athleteId)
      async let phaseResult = apiService.fetchPhase(accessToken: token)
      async let statusResult = apiService.fetchStatus(accessToken: token)
      async let whatMattersResult = apiService.fetchWhatMattersNow(accessToken: token)

      graduationYear = try await prefsResult?.graduationYear
      tasksByGrade = try await tasksResult

      let phaseData = try await phaseResult
      currentPhase = phaseData.phase
      milestoneProgress = phaseData.milestoneProgress
      canAdvancePhase = phaseData.canAdvance

      let status = try await statusResult
      statusScore = StatusScore(score: status.score, label: status.label, breakdown: status.breakdown)

      currentTask = try await whatMattersResult.first

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

      // Invalidate TasksListViewModel's cached list (Phase 3.6) for this
      // task's grade level so it shows correctly on next visit to the
      // grade-level task list screen instead of waiting out the TTL.
      if let athleteId = currentAthleteId {
        await InMemoryCache.shared.remove(forKey: ListCacheKeys.tasks(athleteId: athleteId, gradeLevel: task.gradeLevel))
      }

      await refresh()
    } catch {
      logger.error("Failed to mark task complete: \(error.localizedDescription)")
      errorMessage = "Failed to update task. Please try again."
    }
  }

  func clearSuccessMessage() {
    showSuccessMessage = false
  }

}
