import Foundation
import OSLog
import SwiftUI
import Observation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardViewModel")

@Observable
@MainActor
final class DashboardViewModel {

  nonisolated deinit {}
  var stats: DashboardStats?
  /// Target athlete's graduation year, sourced from their player preferences. nil until loaded
  /// (or when unset), which surfaces as "--" in the At-a-Glance graduation countdown.
  var graduationYear: Int?
  /// Target athlete's primary sport, sourced from their player preferences. nil until loaded
  /// (or when unset) — sport-aware widgets (e.g. the recruiting calendar) fall back to a
  /// generic "Other" presentation when nil.
  var athleteSport: String?
  /// Target athlete's gender, sourced from their player preferences. nil until loaded (or
  /// when unset).
  var athleteGender: String?
  var widgetVisibility: DashboardWidgetVisibility = .default
  var quickTasks: [QuickTask] = []
  var suggestions: [Suggestion] = []
  /// Additional suggestions queued beyond the 3 returned (for "Show N more").
  var suggestionsPendingCount: Int = 0
  var isSuggestionsLoading = false
  var suggestionsError: String?
  var events: [FullEvent] = []
  var coachesNeedingFollowup: [Coach] = []
  var allSchools: [School] = []
  var metrics: [PerformanceMetric] = []
  var interactionTrends: [InteractionTrend] = []
  /// Family-scoped user deadlines, merged into the recruiting-calendar
  /// widget's "Upcoming" list alongside NCAA milestones (see
  /// `RecruitingCalendarWidget.userDeadlines`).
  var deadlines: [Deadline] = []
  var playerDetails: PlayerDetails?
  /// Whether the target athlete has a home location set (`user_preferences`/`location`).
  /// Loaded alongside playerDetails; feeds profileCompleteness/missingProfileFields.
  var hasHomeLocation = false
  var recommendations: [SchoolRecommendation] = []
  var isLoading = false
  var isLoggingOut = false
  var errorMessage: String?

  func dismissError() {
    errorMessage = nil
  }
  var logoutErrorMessage: String?
  var lastUpdated: Date?

  private let authManager: any AuthManaging
  private let dashboardService: any DashboardManaging
  private let taskStorage: QuickTaskStorage
  private let familyManager: FamilyManager
  private let preferenceService: any PreferenceManaging
  private let recommendationService: any SchoolRecommendationManaging
  private let deadlinesService: any DeadlinesManaging

  /// The user whose recruiting data the dashboard shows. When a parent is
  /// viewing an athlete, events/metrics/interactions belong to the athlete;
  /// quick tasks stay keyed to the signed-in user (they are a personal,
  /// device-local list).
  private var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  var userEmail: String {
    authManager.user?.email ?? "Unknown"
  }

  var userFirstName: String {
    guard let email = authManager.user?.email else { return "User" }
    return email.components(separatedBy: "@").first?.capitalized ?? "User"
  }

  var isEmpty: Bool {
    guard let stats = stats else { return true }
    return stats.schoolCount == 0 && stats.coachCount == 0 && stats.interactionCount == 0
  }

  // MARK: - At-a-Glance Computed Properties

  var schoolsWithOffers: Int {
    guard let stats = stats else { return 0 }
    // Clamp to schoolCount so orphan offers (offer without a tracked school) can't exceed 100%.
    return min(stats.schoolsWithOffers, stats.schoolCount)
  }

  var schoolsWithOffersPercentage: String {
    guard let stats = stats, stats.schoolCount > 0 else { return "0%" }
    let percentage = Double(schoolsWithOffers) / Double(stats.schoolCount)
    return percentage.formatted(.percent.precision(.fractionLength(0)))
  }

  var interactionsThisMonth: Int {
    stats?.interactionsThisMonth ?? 0
  }

  var daysUntilGraduation: Int? {
    guard let year = graduationYear else { return nil }
    return GradeLevelHelper.daysUntilGraduation(graduationYear: year)
  }

  var daysUntilGraduationFormatted: String {
    guard let days = daysUntilGraduation else { return "--" }
    return "\(days)"
  }

  var isParentPreviewMode: Bool {
    familyManager.isParentViewingAthlete
  }

  var actingUserId: String { authManager.user?.id ?? "" }
  var currentFamilyUnitId: String { familyManager.currentMember?.familyUnitId ?? "" }

  var selectedAthleteName: String {
    if let athlete = familyManager.selectedAthlete {
      return athlete.user?.fullName ?? "Athlete"
    }
    return "Athlete"
  }

  /// Profile completeness (0.0–1.0) derived from playerDetails. Falls back to 0 when
  /// details haven't loaded yet. Highlight video is not tracked on the dashboard — passed
  /// as false so the ring focuses on fields the user can fill from Player Details.
  var profileCompleteness: Double {
    playerDetails?.completenessScore(hasHighlightVideo: false, hasHomeLocation: hasHomeLocation) ?? 0
  }

  var missingProfileFields: [MissingField] {
    playerDetails?.topMissingFields(hasHighlightVideo: false, hasHomeLocation: hasHomeLocation) ?? []
  }

  #if DEBUG
  var truncatedSessionToken: String {
    guard let token = authManager.session?.accessToken else {
      return "No session"
    }
    let truncationLength = min(20, token.count)
    return String(token.prefix(truncationLength)) + "..."
  }
  #endif

  init(
    authManager: (any AuthManaging)? = nil,
    dashboardService: (any DashboardManaging)? = nil,
    taskStorage: QuickTaskStorage? = nil,
    familyManager: FamilyManager? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    recommendationService: (any SchoolRecommendationManaging)? = nil,
    deadlinesService: (any DeadlinesManaging)? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.dashboardService = dashboardService ?? DashboardServiceImpl(supabaseManager: .shared)
    self.taskStorage = taskStorage ?? UserDefaultsTaskStorage()
    self.familyManager = familyManager ?? .shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.recommendationService = recommendationService ?? SchoolRecommendationServiceImpl(supabaseManager: .shared)
    self.deadlinesService = deadlinesService ?? DeadlinesServiceImpl(supabaseManager: .shared)
  }

  func fetchDashboardData() async {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return
    }

    await familyManager.loadFamilyData()

    let targetUserId = familyManager.selectedAthlete?.userId ?? userId

    guard let familyUnitId = familyManager.familyUnitId else {
      // Mirrors web: no family yet — show empty state. User creates from Family tab when inviting parent.
      logger.debug("No family unit for user \(userId), showing empty stats")
      stats = DashboardStats(
        coachCount: 0,
        schoolCount: 0,
        interactionCount: 0,
        totalOffers: 0,
        acceptedOffers: 0,
        acceptanceRate: nil
      )
      lastUpdated = Date.now
      loadQuickTasks()
      await fetchWidgetVisibility()
      await fetchVisibleWidgets(familyUnitId: nil)
      return
    }

    logger.debug("fetchDashboardData - familyUnitId: \(familyUnitId), targetUserId: \(targetUserId)")

    isLoading = true
    errorMessage = nil

    defer { isLoading = false }

    do {
      async let visibilityTask: Void = fetchWidgetVisibility()
      async let statsTask = dashboardService.fetchStats(
        familyUnitId: familyUnitId,
        userId: targetUserId
      )
      _ = await visibilityTask
      stats = try await statsTask
      lastUpdated = Date.now

      loadQuickTasks()
      await fetchVisibleWidgets(familyUnitId: familyUnitId)
    } catch {
      logger.error("Failed to load dashboard data: \(error.localizedDescription)")
      errorMessage = "Failed to load dashboard. Pull to refresh."

      #if DEBUG
      logger.warning("Using empty stats for development")
      stats = DashboardStats(
        coachCount: 0,
        schoolCount: 0,
        interactionCount: 0,
        totalOffers: 0,
        acceptedOffers: 0,
        acceptanceRate: nil
      )
      lastUpdated = Date.now
      #endif
    }
  }

  /// Widget payloads only. Stats already ran; skip hidden widgets so we don't
  /// download events/metrics/schools the UI will not render.
  private func fetchVisibleWidgets(familyUnitId: String?) async {
    let widgets = widgetVisibility.widgets

    async let suggestionsTask: Void = fetchSuggestionsIfNeeded(widgets.actionItems)
    async let eventsTask: Void = fetchEventsIfNeeded(widgets.eventsSummary)
    async let metricsTask: Void = fetchMetricsIfNeeded(widgets.performanceSummary)
    async let trendsTask: Void = fetchTrendsIfNeeded(widgets.interactionTrendChart)
    async let coachesTask: Void = fetchCoachesFollowupIfNeeded(
      widgets.coachFollowupWidget && familyUnitId != nil
    )
    // Always fetch profile — NUX completeness card needs it even when calendar/at-a-glance are off
    async let profileTask: Void = fetchPlayerProfileIfNeeded(true)
    async let recommendationsTask: Void = fetchRecommendations()
    async let deadlinesTask: Void = fetchDeadlinesIfNeeded(
      widgets.recruitingCalendar && familyUnitId != nil, familyUnitId: familyUnitId
    )
    _ = await (
      suggestionsTask, eventsTask, metricsTask, trendsTask, coachesTask, profileTask,
      recommendationsTask, deadlinesTask
    )
  }

  private func fetchSuggestionsIfNeeded(_ needed: Bool) async {
    guard needed else {
      suggestions = []
      suggestionsPendingCount = 0
      return
    }
    await fetchSuggestions()
  }

  private func fetchEventsIfNeeded(_ needed: Bool) async {
    guard needed else {
      events = []
      return
    }
    await fetchEvents()
  }

  private func fetchMetricsIfNeeded(_ needed: Bool) async {
    guard needed else {
      metrics = []
      return
    }
    await fetchMetrics()
  }

  private func fetchTrendsIfNeeded(_ needed: Bool) async {
    guard needed else {
      interactionTrends = []
      return
    }
    await fetchInteractionTrends()
  }

  private func fetchCoachesFollowupIfNeeded(_ needed: Bool) async {
    guard needed else {
      coachesNeedingFollowup = []
      allSchools = []
      return
    }
    await fetchCoachesFollowup()
  }

  private func fetchPlayerProfileIfNeeded(_ needed: Bool) async {
    guard needed else { return }
    await fetchPlayerProfile()
  }

  private func fetchDeadlinesIfNeeded(_ needed: Bool, familyUnitId: String?) async {
    guard needed, let familyUnitId else {
      deadlines = []
      return
    }
    do {
      deadlines = try await deadlinesService.fetchDeadlines(familyUnitId: familyUnitId)
    } catch {
      logger.warning("Failed to load deadlines: \(error.localizedDescription)")
    }
  }

  func exitParentPreview() {
    familyManager.clearAthleteSelection()
    Task {
      await fetchDashboardData()
    }
  }

  func selectAthlete(_ athleteId: String) {
    familyManager.selectAthlete(athleteId)
    Task {
      await fetchDashboardData()
    }
  }

  func loadQuickTasks() {
    guard let userId = authManager.user?.id else { return }
    do {
      quickTasks = try taskStorage.loadTasks(forUserId: userId)
    } catch {
      errorMessage = "Failed to load tasks: \(error.localizedDescription)"
    }
  }

  func addTask(_ text: String) {
    let newTask = QuickTask(text: text)
    quickTasks.append(newTask)
    saveQuickTasks()
  }

  func toggleTaskCompletion(_ taskId: String) {
    guard let index = quickTasks.firstIndex(where: { $0.id == taskId }) else { return }
    quickTasks[index].isCompleted.toggle()
    saveQuickTasks()
  }

  func deleteTask(_ taskId: String) {
    quickTasks.removeAll { $0.id == taskId }
    saveQuickTasks()
  }

  func clearCompletedTasks() {
    quickTasks.removeAll { $0.isCompleted }
    saveQuickTasks()
  }

  private func saveQuickTasks() {
    guard let userId = authManager.user?.id else { return }
    do {
      try taskStorage.saveTasks(quickTasks, forUserId: userId)
    } catch {
      errorMessage = "Failed to save tasks: \(error.localizedDescription)"
    }
  }

  func fetchSuggestions() async {
    var token = authManager.session?.accessToken
    isSuggestionsLoading = true
    suggestionsError = nil
    defer { isSuggestionsLoading = false }
    do {
      let result = try await dashboardService.fetchSuggestions(location: "dashboard", accessToken: token)
      suggestions = result.suggestions.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }
      suggestionsPendingCount = result.pendingCount
    } catch let err as SuggestionsAPIError where err == .unauthorized {
      // Token may be expired; refresh session once and retry with new access token (JWT)
      do {
        _ = try await authManager.refreshSession()
        token = authManager.session?.accessToken
        logger.debug("Retrying suggestions after session refresh (token present: \(token != nil))")
        let result = try await dashboardService.fetchSuggestions(location: "dashboard", accessToken: token)
        suggestions = result.suggestions.sorted { $0.urgency.sortWeight < $1.urgency.sortWeight }
        suggestionsPendingCount = result.pendingCount
      } catch {
        logger.warning("Failed to load suggestions after refresh: \(error.localizedDescription)")
        suggestionsError = "Couldn't load action items. Pull to refresh."
      }
    } catch {
      logger.warning("Failed to load suggestions: \(error.localizedDescription)")
      suggestionsError = "Couldn't load action items. Pull to refresh."
    }
  }

  func dismissSuggestion(_ id: String) async {
    let token = authManager.session?.accessToken
    do {
      try await dashboardService.dismissSuggestion(id: id, accessToken: token)
      suggestions.removeAll { $0.id == id }
    } catch let err as SuggestionsAPIError {
      errorMessage = err.errorDescription
    } catch {
      errorMessage = "Failed to dismiss suggestion"
    }
  }

  func completeSuggestion(_ id: String) async {
    let token = authManager.session?.accessToken
    do {
      try await dashboardService.completeSuggestion(id: id, accessToken: token)
      suggestions.removeAll { $0.id == id }
    } catch let err as SuggestionsAPIError {
      errorMessage = err.errorDescription
    } catch {
      errorMessage = "Failed to complete suggestion"
    }
  }

  func fetchEvents() async {
    guard let userId = targetUserId else { return }
    do {
      events = try await dashboardService.fetchEvents(userId: userId, limit: 10)
    } catch {
      logger.warning("Failed to load events: \(error.localizedDescription)")
    }
  }

  func fetchCoachesFollowup() async {
    guard let familyUnitId = familyManager.familyUnitId else {
      coachesNeedingFollowup = []
      allSchools = []
      return
    }
    do {
      let schools = try await dashboardService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools
      let schoolIds = schools.map(\.id)
      guard !schoolIds.isEmpty else {
        coachesNeedingFollowup = []
        return
      }
      let coaches = try await dashboardService.fetchCoaches(schoolIds: schoolIds)
      coachesNeedingFollowup = CoachFollowup.stale(coaches, asOf: Date.now)
    } catch {
      logger.warning("Failed to load coaches follow-up: \(error.localizedDescription)")
    }
  }

  func fetchMetrics() async {
    guard let userId = targetUserId else { return }
    do {
      metrics = try await dashboardService.fetchMetrics(userId: userId, limit: 10)
    } catch {
      logger.warning("Failed to load metrics: \(error.localizedDescription)")
    }
  }

  func fetchInteractionTrends() async {
    guard let userId = targetUserId else { return }
    do {
      let interactions = try await dashboardService.fetchInteractions(userId: userId, limit: 30)
      let groupedByDate = Dictionary(grouping: interactions) { interaction -> String in
        String((interaction.occurredAt ?? interaction.createdAt).prefix(10))
      }
      interactionTrends = groupedByDate.map { datePrefix, interactions in
        // datePrefix is "YYYY-MM-DD" extracted from ISO8601 timestamp
        InteractionTrend(id: datePrefix, date: datePrefix + "T00:00:00Z", count: interactions.count)
      }.sorted { $0.date < $1.date }
    } catch {
      logger.warning("Failed to load interaction trends: \(error.localizedDescription)")
    }
  }

  func fetchWidgetVisibility() async {
    do {
      if let saved: DashboardWidgetVisibility = try await preferenceService.fetchPreferences(category: .dashboard) {
        widgetVisibility = saved
      }
    } catch {
      logger.debug("Could not load widget visibility, using defaults: \(error.localizedDescription)")
    }
  }

  /// Loads the target athlete's graduation year, primary sport, and gender from their player
  /// preferences. Player prefs are keyed to the user, not a family unit, so this works before
  /// any family exists. Errors are tolerated (leaves fields nil — the countdown shows "--" and
  /// sport-aware widgets fall back to a generic presentation), mirroring fetchWidgetVisibility.
  func fetchPlayerProfile() async {
    guard let userId = targetUserId else { return }
    do {
      let details: PlayerDetails? = try await preferenceService.fetchPreferences(category: .player, userId: userId)
      playerDetails = details
      graduationYear = details?.graduationYear
      athleteSport = details?.primarySport
      athleteGender = details?.gender
    } catch {
      logger.debug("Could not load graduation year/sport/gender: \(error.localizedDescription)")
    }

    do {
      let location: HomeLocation? = try await preferenceService.fetchPreferences(category: .location, userId: userId)
      hasHomeLocation = location?.isSet ?? false
    } catch {
      logger.debug("Could not load home location for completeness: \(error.localizedDescription)")
      hasHomeLocation = false
    }
  }

  func fetchRecommendations() async {
    guard let userId = targetUserId else { return }
    do {
      recommendations = try await recommendationService.fetchRecommendations(athleteId: userId, limit: 6)
    } catch {
      logger.warning("Failed to load recommendations: \(error.localizedDescription)")
    }
  }

  func addRecommendedSchool(_ recommendation: SchoolRecommendation) async {
    guard let familyUnitId = familyManager.familyUnitId,
          let userId = authManager.user?.id else { return }
    do {
      let schoolsService = SchoolsServiceImpl(supabaseManager: .shared)
      let request = SchoolCreateRequest(
        userId: userId,
        familyUnitId: familyUnitId,
        name: recommendation.name,
        location: nil,
        city: nil,
        state: recommendation.state,
        division: recommendation.division,
        conference: recommendation.conference,
        website: nil,
        twitterHandle: nil,
        instagramHandle: nil,
        ncaaId: nil,
        notes: nil,
        status: "tracking",
        academicInfo: nil,
        faviconUrl: nil
      )
      _ = try await schoolsService.createSchool(request: request)
      recommendations.removeAll { $0.id == recommendation.id }
      await fetchDashboardData()
    } catch {
      logger.warning("Failed to add recommended school: \(error.localizedDescription)")
      errorMessage = "Couldn't add school. Please try again."
    }
  }

  func dismissRecommendation(_ recommendation: SchoolRecommendation) async {
    guard let userId = targetUserId else { return }
    recommendations.removeAll { $0.id == recommendation.id }
    do {
      try await recommendationService.dismissRecommendation(catalogKey: recommendation.catalogKey, athleteId: userId)
    } catch {
      logger.warning("Failed to dismiss recommendation: \(error.localizedDescription)")
    }
  }

  func refresh() async {
    await fetchDashboardData()
  }

  func logout() async {
    isLoggingOut = true
    logoutErrorMessage = nil
    defer { isLoggingOut = false }

    do {
      try await authManager.logout()
    } catch {
      logoutErrorMessage = "Failed to log out. Please try again."
    }
  }

}
