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
  var hapticSuccessTrigger = 0

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
    defer { isLoading = false }

    do {
      if let savedVisibility: DashboardWidgetVisibility = try await preferenceService.fetchPreferences(category: .dashboard) {
        visibility = savedVisibility
        logger.info("Loaded existing dashboard visibility")
      } else {
        visibility = .default
        logger.info("No existing visibility settings, using defaults")
      }
    } catch {
      logger.error("Failed to load visibility: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load settings. Please try again.")
    }
  }

  func saveVisibility() async {
    logger.debug("Saving dashboard visibility")
    saveStatus = .saving
    errorMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .dashboard, data: visibility)
      saveStatus = .saved
      hapticSuccessTrigger += 1
      logger.info("Dashboard visibility saved")
      pendingStatusReset?.cancel()
      pendingStatusReset = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if self.saveStatus == .saved { self.saveStatus = .idle }
      }
    } catch {
      logger.error("Failed to save visibility: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to save settings. Please try again.")
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
    markChanged()
    logger.debug("All stats cards set to: \(enabled)")
  }

  // MARK: - Widgets Toggles

  func toggleAllWidgets(_ enabled: Bool) {
    for id in DashboardWidgetID.allCases {
      visibility.widgets[keyPath: id.visibilityKeyPath] = enabled
    }
    markChanged()
    logger.debug("All widgets set to: \(enabled)")
  }

  // MARK: - Widget Order

  /// Reorders the arrangeable widget list (drag-to-reorder from the customize screen).
  func moveWidget(fromOffsets source: IndexSet, toOffset destination: Int) {
    visibility.widgetOrder.move(fromOffsets: source, toOffset: destination)
    markChanged()
    logger.debug("Widget order changed")
  }

  /// Autosaving binding for a single widget's on/off flag, keyed by its stable id.
  func binding(for id: DashboardWidgetID) -> Binding<Bool> {
    Binding(
      get: { self.visibility.widgets[keyPath: id.visibilityKeyPath] },
      set: { newValue in
        self.visibility.widgets[keyPath: id.visibilityKeyPath] = newValue
        self.markChanged()
      }
    )
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
    visibility.statsCards.offers
  }

  var allWidgetsEnabled: Bool {
    DashboardWidgetID.allCases.allSatisfy { visibility.widgets[keyPath: $0.visibilityKeyPath] }
  }
}
