import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardCustomizationViewModel")

@Observable
@MainActor
final class DashboardCustomizationViewModel {
  var visibility: DashboardWidgetVisibility = .default
  var isLoading = false
  var isSaving = false
  var errorMessage: String?
  var successMessage: String?
  var hasUnsavedChanges = false

  private let preferenceService: PreferenceManaging

  init(preferenceService: PreferenceManaging) {
    self.preferenceService = preferenceService
  }

  // MARK: - Load/Save

  func loadVisibility() async {
    logger.debug("Loading dashboard visibility settings")
    isLoading = true
    errorMessage = nil

    do {
      if let savedVisibility: DashboardWidgetVisibility = try await preferenceService.fetchPreferences(category: .dashboard) {
        visibility = savedVisibility
        logger.info("Loaded existing dashboard visibility")
      } else {
        visibility = .default
        logger.info("No existing visibility settings, using defaults")
      }
      isLoading = false
    } catch {
      logger.error("Failed to load visibility: \(error.localizedDescription)")
      errorMessage = "Failed to load settings: \(error.localizedDescription)"
      isLoading = false
    }
  }

  func saveVisibility() async {
    logger.debug("Saving dashboard visibility")
    isSaving = true
    errorMessage = nil
    successMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .dashboard, data: visibility)
      hasUnsavedChanges = false
      successMessage = "Dashboard settings saved successfully"
      logger.info("Dashboard visibility saved")

      // Clear success message after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run {
          if successMessage == "Dashboard settings saved successfully" {
            successMessage = nil
          }
        }
      }

      isSaving = false
    } catch {
      logger.error("Failed to save visibility: \(error.localizedDescription)")
      errorMessage = "Failed to save settings: \(error.localizedDescription)"
      isSaving = false
    }
  }

  // MARK: - Stats Cards Toggles

  func toggleAllStatsCards(_ enabled: Bool) {
    visibility.statsCards.coaches = enabled
    visibility.statsCards.schools = enabled
    visibility.statsCards.interactions = enabled
    visibility.statsCards.offers = enabled
    visibility.statsCards.events = enabled
    visibility.statsCards.performance = enabled
    visibility.statsCards.notifications = enabled
    visibility.statsCards.socialMedia = enabled
    markChanged()
    logger.debug("All stats cards set to: \(enabled)")
  }

  // MARK: - Widgets Toggles

  func toggleAllWidgets(_ enabled: Bool) {
    visibility.widgets.recentNotifications = enabled
    visibility.widgets.linkedAccounts = enabled
    visibility.widgets.recruitingCalendar = enabled
    visibility.widgets.quickTasks = enabled
    visibility.widgets.atAGlanceSummary = enabled
    visibility.widgets.offerStatusOverview = enabled
    visibility.widgets.interactionTrendChart = enabled
    visibility.widgets.schoolInterestChart = enabled
    visibility.widgets.schoolMapWidget = enabled
    visibility.widgets.coachFollowupWidget = enabled
    visibility.widgets.eventsSummary = enabled
    visibility.widgets.performanceSummary = enabled
    visibility.widgets.recentDocuments = enabled
    visibility.widgets.interactionStats = enabled
    visibility.widgets.schoolStatusOverview = enabled
    visibility.widgets.coachResponsiveness = enabled
    visibility.widgets.upcomingDeadlines = enabled
    markChanged()
    logger.debug("All widgets set to: \(enabled)")
  }

  // MARK: - Reset

  func resetToDefaults() async {
    logger.debug("Resetting dashboard visibility to defaults")
    visibility = .default
    hasUnsavedChanges = true
    await saveVisibility()
  }

  // MARK: - Helpers

  func markChanged() {
    hasUnsavedChanges = true
  }

  var allStatsCardsEnabled: Bool {
    visibility.statsCards.coaches &&
    visibility.statsCards.schools &&
    visibility.statsCards.interactions &&
    visibility.statsCards.offers &&
    visibility.statsCards.events &&
    visibility.statsCards.performance &&
    visibility.statsCards.notifications &&
    visibility.statsCards.socialMedia
  }

  var allWidgetsEnabled: Bool {
    visibility.widgets.recentNotifications &&
    visibility.widgets.linkedAccounts &&
    visibility.widgets.recruitingCalendar &&
    visibility.widgets.quickTasks &&
    visibility.widgets.atAGlanceSummary &&
    visibility.widgets.offerStatusOverview &&
    visibility.widgets.interactionTrendChart &&
    visibility.widgets.schoolInterestChart &&
    visibility.widgets.schoolMapWidget &&
    visibility.widgets.coachFollowupWidget &&
    visibility.widgets.eventsSummary &&
    visibility.widgets.performanceSummary &&
    visibility.widgets.recentDocuments &&
    visibility.widgets.interactionStats &&
    visibility.widgets.schoolStatusOverview &&
    visibility.widgets.coachResponsiveness &&
    visibility.widgets.upcomingDeadlines
  }
}
