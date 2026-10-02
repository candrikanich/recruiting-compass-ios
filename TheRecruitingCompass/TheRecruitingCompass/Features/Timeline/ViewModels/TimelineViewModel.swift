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
  /// Sourced from the same player-preferences fetch as `graduationYear` — mirrors
  /// `DashboardViewModel.athleteSport`/`athleteGender`. Drives the Guidance tab's
  /// sport-aware calendar widget.
  var athleteSport: String?
  var athleteGender: String?
  var isLoading = false
  var errorMessage: String?
  var expandedPhaseGrade: Int?
  var showSuccessMessage = false

  /// Top-priority "what matters now" task for the current phase, from the shared
  /// web endpoint. Drives the dashboard summary card's current-task.
  var currentTask: WhatMattersItem?

  /// Top-5 "what matters now" items, server-ranked, for the guidance widget.
  var whatMattersItems: [WhatMattersItem] = []

  var isViewingAsParent: Bool { familyManager.isParentViewingAthlete }
  var currentAthleteId: String? {
    if let athlete = familyManager.selectedAthlete { return athlete.userId }
    return authManager.user?.id
  }

  @ObservationIgnored private var inFlightLoad: (key: String, task: Task<Void, Never>)?

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
    await coalescing("full:\(athleteId)") { await self.performLoad(athleteId: athleteId) }
  }

  /// Phase, status score and top priority only — what the dashboard card shows. Skips the task list
  /// and player preferences, which only the Timeline screen reads.
  func loadSummary() async {
    guard let athleteId = currentAthleteId else {
      errorMessage = "Unable to load timeline."
      return
    }
    await coalescing("summary:\(athleteId)") { await self.performSummaryLoad() }
  }

  /// Joins a load already in flight for the same key instead of starting a second one. The dashboard
  /// asks twice at launch: from `.task`, then again when the family finishes loading.
  private func coalescing(_ key: String, _ operation: @escaping @MainActor () async -> Void) async {
    if let inFlightLoad, inFlightLoad.key == key {
      await inFlightLoad.task.value
      return
    }
    let task = Task { await operation() }
    inFlightLoad = (key, task)
    await task.value
    if inFlightLoad?.key == key { inFlightLoad = nil }
  }

  private func performLoad(athleteId: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let prefsResult = preferenceService.fetchPreferences(category: .player, userId: athleteId) as PlayerDetails?
      async let tasksResult = tasksService.fetchAllTasksWithStatus(athleteId: athleteId)
      async let summaryResult: Void = fetchSummary()

      let prefs = try await prefsResult
      graduationYear = prefs?.graduationYear
      athleteSport = prefs?.primarySport
      athleteGender = prefs?.gender
      tasksByGrade = try await tasksResult.mapValues { TimelineTaskSort.sorted($0) }
      try await summaryResult

      if expandedPhaseGrade == nil {
        expandedPhaseGrade = currentPhase.gradeLevel
      }
    } catch {
      logger.error("Failed to load timeline: \(error.localizedDescription)")
      errorMessage = "Failed to load timeline. Please try again."
    }
  }

  private func performSummaryLoad() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await fetchSummary()
    } catch {
      logger.error("Failed to load timeline summary: \(error.localizedDescription)")
      errorMessage = "Failed to load timeline. Please try again."
    }
  }

  private func fetchSummary() async throws {
    let token = authManager.session?.accessToken

    async let phaseResult = apiService.fetchPhase(accessToken: token)
    async let statusResult = apiService.fetchStatus(accessToken: token)
    async let whatMattersResult = apiService.fetchWhatMattersNow(accessToken: token)

    let phaseData = try await phaseResult
    currentPhase = phaseData.phase
    milestoneProgress = phaseData.milestoneProgress
    canAdvancePhase = phaseData.canAdvance

    let status = try await statusResult
    statusScore = StatusScore(score: status.score, label: status.label, breakdown: status.breakdown)

    // Non-fatal: a missing/failing what-matters-now endpoint must degrade to
    // "no pending priorities", not abort the whole timeline load. The card
    // already renders on statusScore alone.
    do {
      let items = try await whatMattersResult
      whatMattersItems = Array(items.prefix(5))
      currentTask = items.first
    } catch {
      logger.error("what-matters-now failed (non-fatal): \(error.localizedDescription)")
      whatMattersItems = []
      currentTask = nil
    }

    logger.info("Timeline loaded: phase=\(phaseData.phase.rawValue), status=\(status.score)/100")
  }

  /// Always fetches: a refresh follows a write or a pull-to-refresh, so joining a load that started
  /// earlier would show stale data.
  func refresh() async {
    guard let athleteId = currentAthleteId else {
      errorMessage = "Unable to load timeline."
      return
    }
    await performLoad(athleteId: athleteId)
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
    // Write against the athlete being viewed. For a player this is their own id;
    // for a parent helping their athlete it's the linked athlete's id, so the
    // athlete_task row is keyed to the athlete, not the parent.
    guard let athleteId = currentAthleteId else { return }

    guard let task = allTasks.first(where: { $0.id == taskId }), !task.isLocked else { return }

    do {
      _ = try await tasksService.updateTaskStatus(taskId: taskId, status: .completed, userId: athleteId)
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
