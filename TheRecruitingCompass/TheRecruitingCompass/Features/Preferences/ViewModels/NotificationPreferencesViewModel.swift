import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "NotificationPreferencesViewModel")

@Observable
@MainActor
final class NotificationPreferencesViewModel {
  var settings: NotificationSettings = .default
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

  // MARK: - Load Preferences

  func loadPreferences() async {
    logger.debug("Loading notification preferences")
    isLoading = true
    errorMessage = nil

    do {
      if let savedSettings: NotificationSettings = try await preferenceService.fetchPreferences(category: .notifications) {
        settings = savedSettings
        logger.info("Loaded existing notification preferences")
      } else {
        settings = .default
        logger.info("No existing preferences, using defaults")
      }
      isLoading = false
    } catch {
      logger.error("Failed to load preferences: \(error.localizedDescription)")
      errorMessage = "Failed to load preferences. Please try again."
      isLoading = false
    }
  }

  // MARK: - Save Preferences

  func savePreferences() async {
    logger.debug("Saving notification preferences")
    saveStatus = .saving
    errorMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .notifications, data: settings)
      saveStatus = .saved
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      logger.info("Notification preferences saved")
      pendingStatusReset?.cancel()
      pendingStatusReset = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if self.saveStatus == .saved { self.saveStatus = .idle }
      }
    } catch {
      logger.error("Failed to save preferences: \(error.localizedDescription)")
      errorMessage = "Failed to save preferences. Please try again."
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
      Task { await self.savePreferences() }
    }
  }

  func markAsChanged() {
    scheduleAutoSave()
  }

  // MARK: - Reset to Defaults

  func resetToDefaults() async {
    logger.debug("Resetting notification preferences to defaults")
    settings = .default
    await savePreferences()
  }
}
