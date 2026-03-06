import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardCustomizationViewModel")

@Observable
@MainActor
final class DashboardCustomizationViewModel {
  var visibility: DashboardWidgetVisibility = .default
  var isLoading = false
  var errorMessage: String?
  var saveStatus: SaveStatus = .idle

  private let preferenceService: any PreferenceManaging
  @ObservationIgnored nonisolated(unsafe) private var pendingAutoSave: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

  init(preferenceService: any PreferenceManaging) {
    self.preferenceService = preferenceService
  }

  nonisolated deinit {
    pendingAutoSave?.cancel()
    pendingStatusReset?.cancel()
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
      errorMessage = "Failed to load settings. Please try again."
      isLoading = false
    }
  }

  func saveVisibility() async {
    logger.debug("Saving dashboard visibility")
    saveStatus = .saving
    errorMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .dashboard, data: visibility)
      saveStatus = .saved
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      logger.info("Dashboard visibility saved")
      pendingStatusReset?.cancel()
      pendingStatusReset = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if self.saveStatus == .saved { self.saveStatus = .idle }
      }
    } catch {
      logger.error("Failed to save visibility: \(error.localizedDescription)")
      errorMessage = "Failed to save settings. Please try again."
      saveStatus = .idle
    }
  }

  // MARK: - Auto-Save

  func scheduleAutoSave() {
    pendingAutoSave?.cancel()
    saveStatus = .saving
    pendingAutoSave = Task {
      try? await Task.sleep(for: .milliseconds(1000))
      guard !Task.isCancelled else { return }
      Task { await self.saveVisibility() }
    }
  }

  func markChanged() {
    scheduleAutoSave()
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
    await saveVisibility()
  }

  // MARK: - Computed

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
