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
  var pushPreferences: [NotificationType: Bool] = [:]
  var pushSetupError: String?
  var hapticSuccessTrigger = 0

  private let preferenceService: any PreferenceManaging
  private let pushPreferencesService: (any PushPreferencesManaging)?
  @ObservationIgnored nonisolated(unsafe) private var pendingAutoSave: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var pendingPreferenceUpdates: [NotificationType: Task<Void, Never>] = [:]

  init(
    preferenceService: any PreferenceManaging,
    pushPreferencesService: (any PushPreferencesManaging)? = nil
  ) {
    self.preferenceService = preferenceService
    self.pushPreferencesService = pushPreferencesService
  }

  nonisolated deinit {
    pendingAutoSave?.cancel()
    pendingStatusReset?.cancel()
    pendingPreferenceUpdates.values.forEach { $0.cancel() }
  }

  // MARK: - Load Preferences

  func loadPreferences() async {
    logger.debug("Loading notification preferences")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      if let savedSettings: NotificationSettings = try await preferenceService.fetchPreferences(category: .notifications) {
        settings = savedSettings
        logger.info("Loaded existing notification preferences")
      } else {
        settings = .default
        logger.info("No existing preferences, using defaults")
      }
    } catch {
      logger.error("Failed to load preferences: \(error.localizedDescription)")
      errorMessage = "Failed to load preferences. Please try again."
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
      hapticSuccessTrigger += 1
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

  // MARK: - Push Preferences

  func loadPushPreferences(userId: String) async {
    // Surface any device-registration failure recorded by the push manager;
    // without this the device silently never receives push.
    pushSetupError = PushNotificationManager.shared.lastError
    guard let service = pushPreferencesService else { return }
    do {
      let prefs = try await service.fetchPreferences(userId: userId)
      pushPreferences = prefs.filter { $0.key != .unknown }
    } catch {
      errorMessage = "Failed to load push preferences."
      logger.error("loadPushPreferences failed: \(error.localizedDescription)")
    }
  }

  func updatePushPreference(userId: String, type: NotificationType, enabled: Bool) async {
    guard let service = pushPreferencesService else { return }
    pendingPreferenceUpdates[type]?.cancel()
    pushPreferences[type] = enabled  // optimistic update
    let task = Task {
      guard !Task.isCancelled else { return }
      do {
        try await service.updatePreference(userId: userId, type: type, pushEnabled: enabled)
      } catch {
        guard !Task.isCancelled else { return }
        pushPreferences[type] = !enabled  // revert
        errorMessage = "Failed to update push preference."
        logger.error("updatePushPreference failed: \(error.localizedDescription)")
      }
    }
    pendingPreferenceUpdates[type] = task
    await task.value
  }
}
