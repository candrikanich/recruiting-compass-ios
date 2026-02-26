import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "NotificationPreferencesViewModel")

@Observable
@MainActor
final class NotificationPreferencesViewModel {
  var settings: NotificationSettings = .default
  var isLoading = false
  var isSaving = false
  var errorMessage: String?
  var successMessage: String?
  var hasUnsavedChanges = false

  private let preferenceService: any PreferenceManaging
  init(preferenceService: any PreferenceManaging) {
    self.preferenceService = preferenceService
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
    isSaving = true
    errorMessage = nil
    successMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .notifications, data: settings)
      hasUnsavedChanges = false
      successMessage = "Preferences saved successfully"
      logger.info("Notification preferences saved")

      // Clear success message after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run {
          if successMessage == "Preferences saved successfully" {
            successMessage = nil
          }
        }
      }

      isSaving = false
    } catch {
      logger.error("Failed to save preferences: \(error.localizedDescription)")
      errorMessage = "Failed to save preferences. Please try again."
      isSaving = false
    }
  }

  // MARK: - Reset to Defaults

  func resetToDefaults() async {
    logger.debug("Resetting notification preferences to defaults")
    settings = .default
    hasUnsavedChanges = true
    await savePreferences()
  }

  // MARK: - Public Helpers

  func markAsChanged() {
    hasUnsavedChanges = true
  }
}
