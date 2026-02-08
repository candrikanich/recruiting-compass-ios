import Foundation
import SwiftUI
import Combine

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

  func fetchEvents() async {
    guard let userId = authManager.user?.id else { return }
    do {
      events = try await dashboardService.fetchEvents(userId: userId, limit: 10)
    } catch {
    }
  }

  func fetchActivities() async {
    guard let userId = authManager.user?.id else { return }
    do {
      activities = try await dashboardService.fetchRecentActivity(userId: userId, limit: 10)
    } catch {
    }
  }

  func fetchMetrics() async {
    guard let userId = authManager.user?.id else { return }
    do {
      metrics = try await dashboardService.fetchMetrics(userId: userId, limit: 10)
    } catch {
    }
  }

  func fetchInteractionTrends() async {
    guard let userId = authManager.user?.id else { return }
    do {
      let interactions = try await dashboardService.fetchInteractions(userId: userId, limit: 30)
      let groupedByDate = Dictionary(grouping: interactions) { interaction -> String in
        String(interaction.interactionDate.prefix(10))
      }
      interactionTrends = groupedByDate.map { date, interactions in
        InteractionTrend(id: date, date: "\(date)T00:00:00Z", count: interactions.count)
      }.sorted { $0.date < $1.date }
    } catch {
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
