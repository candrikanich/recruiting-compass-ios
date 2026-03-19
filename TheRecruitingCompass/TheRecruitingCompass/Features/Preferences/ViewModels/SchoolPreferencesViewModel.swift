import Foundation
import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolPreferencesViewModel")

@Observable
@MainActor
final class SchoolPreferencesViewModel {

  var preferences: SchoolPreferences = .default
  var isLoading = false
  var errorMessage: String?
  var saveStatus: SaveStatus = .idle
  var showingAddSheet = false
  var showingTemplateWarning = false
  var pendingTemplate: String?

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

  func loadPreferences() async {
    logger.debug("Loading school preferences")
    isLoading = true
    errorMessage = nil

    do {
      if let savedPreferences: SchoolPreferences = try await preferenceService.fetchPreferences(category: .school) {
        preferences = savedPreferences
        logger.info("Loaded existing school preferences")
      } else {
        preferences = .default
        logger.info("No existing preferences, using defaults")
      }
      isLoading = false
    } catch {
      logger.error("Failed to load preferences: \(error.localizedDescription)")
      errorMessage = "Failed to load preferences. Please try again."
      isLoading = false
    }
  }

  func savePreferences() async {
    logger.debug("Saving school preferences")
    saveStatus = .saving
    errorMessage = nil
    preferences.lastUpdated = Date().ISO8601Format()

    do {
      _ = try await preferenceService.savePreferences(category: .school, data: preferences)
      saveStatus = .saved
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      logger.info("School preferences saved")
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

  private func markChanged() {
    scheduleAutoSave()
  }

  // MARK: - Templates

  func requestTemplateApplication(_ templateName: String) {
    if !preferences.preferences.isEmpty {
      pendingTemplate = templateName
      showingTemplateWarning = true
    } else {
      applyTemplateInternal(templateName)
    }
  }

  func confirmTemplateApplication() {
    if let template = pendingTemplate {
      applyTemplateInternal(template)
      pendingTemplate = nil
    }
    showingTemplateWarning = false
  }

  func cancelTemplateApplication() {
    pendingTemplate = nil
    showingTemplateWarning = false
  }

  private func applyTemplateInternal(_ templateName: String) {
    logger.debug("Applying template: \(templateName)")

    switch templateName {
    case "D1 Power Conference":
      preferences.preferences = [
        SchoolPreference(
          id: UUID().uuidString,
          category: .program,
          type: "division",
          value: .stringArray(["D1"]),
          priority: 1,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .program,
          type: "conference_type",
          value: .stringArray(["Power 4"]),
          priority: 2,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .program,
          type: "scholarship_required",
          value: .bool(true),
          priority: 3,
          isDealbreaker: false
        )
      ]

    case "Academic Excellence":
      preferences.preferences = [
        SchoolPreference(
          id: UUID().uuidString,
          category: .academic,
          type: "min_academic_rating",
          value: .int(4),
          priority: 1,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .academic,
          type: "school_size",
          value: .string("medium"),
          priority: 2,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .program,
          type: "division",
          value: .stringArray(["D1", "D3"]),
          priority: 3,
          isDealbreaker: false
        )
      ]

    case "Close to Home":
      preferences.preferences = [
        SchoolPreference(
          id: UUID().uuidString,
          category: .location,
          type: "max_distance_miles",
          value: .int(300),
          priority: 1,
          isDealbreaker: false
        )
      ]

    case "Best Fit (Balanced)":
      preferences.preferences = [
        SchoolPreference(
          id: UUID().uuidString,
          category: .location,
          type: "max_distance_miles",
          value: .int(500),
          priority: 1,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .academic,
          type: "min_academic_rating",
          value: .int(3),
          priority: 2,
          isDealbreaker: false
        ),
        SchoolPreference(
          id: UUID().uuidString,
          category: .program,
          type: "division",
          value: .stringArray(["D1", "D2", "D3"]),
          priority: 3,
          isDealbreaker: false
        )
      ]

    default:
      logger.warning("Unknown template: \(templateName)")
      return
    }

    preferences.templateUsed = templateName
    markChanged()
  }

  // MARK: - Preference Management

  func addPreference(_ preference: SchoolPreference) {
    var newPreference = preference
    newPreference.priority = preferences.preferences.count + 1
    preferences.preferences.append(newPreference)
    markChanged()
    logger.debug("Added preference: \(preference.type)")
  }

  func removePreference(at offsets: IndexSet) {
    preferences.preferences.remove(atOffsets: offsets)
    updatePriorities()
    markChanged()
    logger.debug("Removed preference at offsets: \(offsets)")
  }

  func movePreference(from source: IndexSet, to destination: Int) {
    preferences.preferences.move(fromOffsets: source, toOffset: destination)
    updatePriorities()
    markChanged()
    logger.debug("Moved preference from \(source) to \(destination)")
  }

  func toggleDealbreaker(id: String) {
    if let index = preferences.preferences.firstIndex(where: { $0.id == id }) {
      preferences.preferences[index].isDealbreaker.toggle()
      markChanged()
      logger.debug("Toggled dealbreaker for preference: \(id)")
    }
  }

  // MARK: - Private Helpers

  private func updatePriorities() {
    for (index, _) in preferences.preferences.enumerated() {
      preferences.preferences[index].priority = index + 1
    }
  }

  var hasPreferences: Bool {
    !preferences.preferences.isEmpty
  }
}
