import Foundation
import OSLog
import SwiftUI
import Combine

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardViewModel")

@MainActor
final class DashboardViewModel: ObservableObject {
  @Published var stats: DashboardStats?
  @Published var quickTasks: [QuickTask] = []
  @Published var suggestions: [Suggestion] = []
  @Published var events: [Event] = []
  @Published var activities: [Activity] = []
  @Published var metrics: [PerformanceMetric] = []
  @Published var interactionTrends: [InteractionTrend] = []
  @Published var isLoading = false
  @Published var isLoggingOut = false
  @Published var errorMessage: String?
  @Published var logoutErrorMessage: String?
  @Published var lastUpdated: Date?

  private let authManager: any AuthManaging
  private let dashboardService: any DashboardManaging
  private let taskStorage: QuickTaskStorage
  private let familyManager: FamilyManager

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
    return stats.totalOffers > 0 && stats.schoolCount > 0 ? min(stats.totalOffers, stats.schoolCount) : 0
  }

  var schoolsWithOffersPercentage: String {
    guard let stats = stats, stats.schoolCount > 0 else { return "0%" }
    let percentage = Double(schoolsWithOffers) / Double(stats.schoolCount) * 100
    return String(format: "%.0f%%", percentage)
  }

  var avgCoachResponsiveness: Double {
    // TODO: Calculate based on interaction response times
    return stats != nil && stats!.interactionCount > 0 ? 0.75 : 0.0
  }

  var avgCoachResponsivenessFormatted: String {
    String(format: "%.0f%%", avgCoachResponsiveness * 100)
  }

  var avgCoachResponsivenessColor: Color {
    if avgCoachResponsiveness >= 0.75 {
      return .successGreen
    } else if avgCoachResponsiveness >= 0.50 {
      return .warningOrange
    } else {
      return .errorRed
    }
  }

  var interactionsThisMonth: Int {
    let calendar = Calendar.current
    let now = Date()
    return activities.filter { activity in
      guard let date = ISO8601DateFormatter().date(from: activity.timestamp) else {
        return false
      }
      return calendar.isDate(date, equalTo: now, toGranularity: .month)
    }.count
  }

  var daysUntilGraduation: Int? {
    // TODO: Requires user.graduationDate field in User model
    return stats != nil ? 365 : nil
  }

  var daysUntilGraduationFormatted: String {
    guard let days = daysUntilGraduation else { return "--" }
    return "\(days)"
  }

  var isParentPreviewMode: Bool {
    familyManager.isParentViewingAthlete
  }

  var selectedAthleteName: String {
    familyManager.selectedAthlete?.fullName ?? "Athlete"
  }

  var truncatedSessionToken: String {
    guard let token = authManager.session?.accessToken else {
      return "No session"
    }
    let truncationLength = min(20, token.count)
    return String(token.prefix(truncationLength)) + "..."
  }

  nonisolated init(
    authManager: any AuthManaging = AuthManager.shared,
    dashboardService: any DashboardManaging = DashboardServiceImpl(supabaseManager: .shared),
    taskStorage: QuickTaskStorage = UserDefaultsTaskStorage(),
    familyManager: FamilyManager = .shared
  ) {
    self.authManager = authManager
    self.dashboardService = dashboardService
    self.taskStorage = taskStorage
    self.familyManager = familyManager
  }

  func fetchDashboardData() async {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return
    }

    await familyManager.loadFamilyData()

    let targetUserId = familyManager.selectedAthleteId ?? userId
    let familyUnitId = familyManager.currentMember?.familyUnitId ?? userId

    isLoading = true
    errorMessage = nil

    defer { isLoading = false }

    do {
      let fetchedStats = try await dashboardService.fetchStats(
        familyUnitId: familyUnitId,
        userId: targetUserId
      )
      stats = fetchedStats
      lastUpdated = Date()

      loadQuickTasks()
      await fetchSuggestions()
      await fetchEvents()
      await fetchActivities()
      await fetchMetrics()
      await fetchInteractionTrends()
    } catch {
      errorMessage = "Failed to load dashboard: \(error.localizedDescription)"

      #if DEBUG
      logger.warning("Using empty stats for development")
      stats = DashboardStats(
        coachCount: 0,
        schoolCount: 0,
        interactionCount: 0,
        totalOffers: 0,
        acceptedOffers: 0,
        aTierSchoolCount: 0,
        acceptanceRate: nil
      )
      lastUpdated = Date()
      #endif
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
    do {
      suggestions = try await dashboardService.fetchSuggestions(location: "dashboard")
    } catch {
      logger.warning("Failed to load suggestions: \(error.localizedDescription)")
    }
  }

  func dismissSuggestion(_ id: String) async {
    do {
      try await dashboardService.dismissSuggestion(id: id)
      suggestions.removeAll { $0.id == id }
    } catch {
      errorMessage = "Failed to dismiss suggestion"
    }
  }

  func completeSuggestion(_ id: String) async {
    do {
      try await dashboardService.completeSuggestion(id: id)
      suggestions.removeAll { $0.id == id }
    } catch {
      errorMessage = "Failed to complete suggestion"
    }
  }

  func fetchEvents() async {
    guard let userId = authManager.user?.id else { return }
    do {
      events = try await dashboardService.fetchEvents(userId: userId, limit: 10)
    } catch {
      logger.warning("Failed to load events: \(error.localizedDescription)")
    }
  }

  func fetchActivities() async {
    guard let userId = authManager.user?.id else { return }
    do {
      activities = try await dashboardService.fetchRecentActivity(userId: userId, limit: 10)
    } catch {
      logger.warning("Failed to load activities: \(error.localizedDescription)")
    }
  }

  func fetchMetrics() async {
    guard let userId = authManager.user?.id else { return }
    do {
      metrics = try await dashboardService.fetchMetrics(userId: userId, limit: 10)
    } catch {
      logger.warning("Failed to load metrics: \(error.localizedDescription)")
    }
  }

  func fetchInteractionTrends() async {
    guard let userId = authManager.user?.id else { return }
    do {
      let interactions = try await dashboardService.fetchInteractions(userId: userId, limit: 30)
      let groupedByDate = Dictionary(grouping: interactions) { interaction -> String in
        String((interaction.occurredAt ?? interaction.createdAt).prefix(10))
      }
      interactionTrends = groupedByDate.map { date, interactions in
        InteractionTrend(id: date, date: "\(date)T00:00:00Z", count: interactions.count)
      }.sorted { $0.date < $1.date }
    } catch {
      logger.warning("Failed to load interaction trends: \(error.localizedDescription)")
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
