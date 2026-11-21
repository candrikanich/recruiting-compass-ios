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

  /// True only once a phase fetch for the athlete on screen has returned. `currentPhase` defaults to freshman, so
  /// without this a failed fetch (or a switch to another athlete) would show freshman steps as if they were right.
  private(set) var isPhaseResolved = false

  /// Family-wide coach / conversation counts and the favorite school. `nil` until loaded or when a read failed,
  /// which hides the status score (fail closed).
  private(set) var firstRunSignals: FirstRunSignals?

  /// The what-matters-now request failed: the card must say so rather than claim there is nothing to do.
  private(set) var stepsFailed = false

  var isStatusScoreVisible: Bool { firstRunSignals?.isStatusScoreVisible ?? false }
  var favoriteSchoolName: String? { firstRunSignals?.favoriteSchoolName }

  /// The next one to three steps for the athlete's grade; empty until the phase is known.
  var nextSteps: [WhatMattersItem] {
    isPhaseResolved ? Array(whatMattersItems.prefix(Self.maxNextSteps)) : []
  }

  /// The score and its server-derived color, or `nil` while it must stay hidden.
  var visibleStatus: DashboardTimelineSummaryCard.Status? {
    guard isStatusScoreVisible, let statusScore else { return nil }
    return .init(score: statusScore.score, color: statusScore.color)
  }

  /// Everything the Home card renders, decided here so the view only passes it through.
  var summaryCard: DashboardTimelineSummaryCard.Content {
    .init(
      phase: isPhaseResolved ? currentPhase : nil,
      status: visibleStatus,
      favoriteSchoolName: favoriteSchoolName,
      nextSteps: nextSteps,
      stepsUnavailable: !isPhaseResolved || stepsFailed
    )
  }

  /// What the Timeline screen's stat pills show for the status score; `nil` hides it.
  var statPillsStatus: TimelineStatPills.Status? {
    visibleStatus.map { _ in .init(score: statusScoreValue, label: statusLabel) }
  }

  /// Hidden until the phase fetch settles; then shown either with steps or with the failure message. It never waits
  /// on the counts request (the score is what stays hidden until that lands) and stays up during a reload.
  var shouldShowNextStepsCard: Bool {
    isPhaseResolved || errorMessage != nil
  }

  private static let maxNextSteps = 3
  @ObservationIgnored private var loadedAthleteId: String?

  var isViewingAsParent: Bool { familyManager.isParentViewingAthlete }
  /// Friendly explanation shown when a parent tries an action that stays with the athlete.
  var restrictionNotice: String?
  var currentAthleteId: String? {
    if let athlete = familyManager.selectedAthlete { return athlete.userId }
    return authManager.user?.id
  }

  @ObservationIgnored private var inFlightLoad: (key: String, task: Task<Void, Never>)?
  /// Bumped for every signals request; only the newest one may write, so a slow older answer (a stale 0) can't
  /// overwrite a newer one.
  @ObservationIgnored private var signalsRequestSequence = 0

  private let tasksService: any TasksManaging
  private let apiService: any TimelineAPIManaging
  private let preferenceService: any PreferenceManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager
  private let dashboardService: any DashboardManaging

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
    familyManager: FamilyManager? = nil,
    dashboardService: (any DashboardManaging)? = nil
  ) {
    self.tasksService = tasksService ?? TasksServiceImpl(supabaseManager: .shared)
    self.apiService = apiService ?? TimelineAPIService()
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? .shared
    self.dashboardService = dashboardService ?? DashboardServiceImpl(supabaseManager: .shared)
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
    await coalescing("summary:\(athleteId)") { await self.performSummaryLoad(athleteId: athleteId) }
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
    defer { if isCurrent(athleteId) { isLoading = false } }

    do {
      async let prefsResult = preferenceService.fetchPreferences(category: .player, userId: athleteId) as PlayerDetails?
      async let tasksResult = tasksService.fetchAllTasksWithStatus(athleteId: athleteId)
      async let summaryResult: Void = fetchSummary()

      let prefs = try await prefsResult
      guard isCurrent(athleteId) else { return }
      graduationYear = prefs?.graduationYear
      athleteSport = prefs?.primarySport
      athleteGender = prefs?.gender
      let tasksByGrade = try await tasksResult.mapValues { TimelineTaskSort.sorted($0) }
      guard isCurrent(athleteId) else { return }
      self.tasksByGrade = tasksByGrade
      try await summaryResult

      guard isCurrent(athleteId) else { return }
      if expandedPhaseGrade == nil {
        expandedPhaseGrade = currentPhase.gradeLevel
      }
    } catch {
      logger.error("Failed to load timeline: \(error.localizedDescription)")
      if isCurrent(athleteId) { errorMessage = "Failed to load timeline. Please try again." }
    }
  }

  private func performSummaryLoad(athleteId: String) async {
    isLoading = true
    errorMessage = nil
    defer { if isCurrent(athleteId) { isLoading = false } }

    do {
      try await fetchSummary()
    } catch {
      logger.error("Failed to load timeline summary: \(error.localizedDescription)")
      if isCurrent(athleteId) { errorMessage = "Failed to load timeline. Please try again." }
    }
  }

  /// Drops everything that described another athlete, so a switch (or a failed load) never shows their steps,
  /// phase or score as this athlete's.
  private func resetSummaryIfAthleteChanged() {
    guard loadedAthleteId != currentAthleteId else { return }
    loadedAthleteId = currentAthleteId
    isPhaseResolved = false
    statusScore = nil
    currentTask = nil
    whatMattersItems = []
    stepsFailed = false
    firstRunSignals = nil
  }

  /// A load only writes while the athlete it started for is still the one on screen. `coalescing` runs it in an
  /// unstructured Task, so cancelling the view's `.task(id:)` on a switch doesn't stop it landing late.
  private func isCurrent(_ requestedAthleteId: String?) -> Bool {
    currentAthleteId == requestedAthleteId
  }

  /// One fence for the load's read and every refresh (as web's `createRequestFence`): only the newest request may
  /// write, on success and on failure. A failed newest read fails closed (score hidden), as on web.
  private func fetchFirstRunSignals(for requestedAthleteId: String?) async {
    signalsRequestSequence += 1
    let sequence = signalsRequestSequence
    guard let familyUnitId = familyManager.familyUnitId else {
      if isCurrent(requestedAthleteId) { firstRunSignals = nil }
      return
    }
    do {
      let signals = try await dashboardService.fetchFirstRunSignals(familyUnitId: familyUnitId)
      guard isCurrent(requestedAthleteId), sequence == signalsRequestSequence else { return }
      firstRunSignals = signals
    } catch {
      logger.error("first-run signals failed (non-fatal): \(error.localizedDescription)")
      guard isCurrent(requestedAthleteId), sequence == signalsRequestSequence else { return }
      firstRunSignals = nil
    }
  }

  /// A summary load is running or about to: it reads the signals itself.
  var isSummaryLoadInFlight: Bool { isLoading || inFlightLoad != nil }

  /// Re-reads only the coach / conversation counts and favorite school, for when the family adds a coach or
  /// school or logs a conversation. Runs even mid-load: that load may have sent its counts request before the
  /// write, and the newest request wins. Skipped until a load has begun for this athlete, so it can never keep
  /// another athlete's signals.
  func refreshFirstRunSignals() async {
    guard let athleteId = currentAthleteId, loadedAthleteId == athleteId else { return }
    await fetchFirstRunSignals(for: athleteId)
  }

  /// For returning to the screen, where nothing was written: a load in flight already reads fresh counts.
  func refreshFirstRunSignalsIfIdle() async {
    guard !isSummaryLoadInFlight else { return }
    await refreshFirstRunSignals()
  }

  private func fetchSummary() async throws {
    let requestedAthleteId = currentAthleteId
    resetSummaryIfAthleteChanged()
    do {
      try await fetchSummaryUnchecked(for: requestedAthleteId)
    } catch {
      if isCurrent(requestedAthleteId) { isPhaseResolved = false }
      throw error
    }
  }

  private func fetchSummaryUnchecked(for requestedAthleteId: String?) async throws {
    let token = authManager.session?.accessToken

    let athleteId = familyManager.selectedAthlete?.userId
    async let signalsResult: Void = fetchFirstRunSignals(for: requestedAthleteId)
    async let phaseResult = apiService.fetchPhase(accessToken: token, athleteId: athleteId)
    async let statusResult = apiService.fetchStatus(accessToken: token, athleteId: athleteId)
    async let whatMattersResult = apiService.fetchWhatMattersNow(accessToken: token, athleteId: athleteId)

    let phaseData = try await phaseResult
    guard isCurrent(requestedAthleteId) else { return }
    currentPhase = phaseData.phase
    milestoneProgress = phaseData.milestoneProgress
    canAdvancePhase = phaseData.canAdvance

    let status = try await statusResult
    guard isCurrent(requestedAthleteId) else { return }
    statusScore = StatusScore(score: status.score, label: status.label, breakdown: status.breakdown)

    // Non-fatal: a failing what-matters-now endpoint must not abort the whole timeline load, but the card says
    // the steps are unavailable instead of claiming there is nothing to do.
    let items: [WhatMattersItem]
    var failed = false
    do {
      items = try await whatMattersResult
    } catch {
      logger.error("what-matters-now failed (non-fatal): \(error.localizedDescription)")
      items = []
      failed = true
    }
    guard isCurrent(requestedAthleteId) else { return }
    whatMattersItems = Array(items.prefix(5))
    currentTask = items.first
    stepsFailed = failed
    // The steps never wait on the counts request; the score stays hidden until it lands.
    isPhaseResolved = true

    await signalsResult

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
    guard !isViewingAsParent else {
      restrictionNotice = familyManager.completeTaskRestrictionNotice
      return
    }
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
