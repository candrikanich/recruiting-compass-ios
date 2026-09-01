import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "NuxProgressManager")

/// Manages NUX (New User Experience) checklist progress. Optimistic-update pattern:
/// mutations apply locally first, then persist to the server in the background.
/// On save failure, logs but does not revert (matches web behavior).
@Observable
@MainActor
final class NuxProgressManager {
  nonisolated deinit {}

  static let shared = NuxProgressManager()

  var progress: NuxProgress = .empty
  var isLoaded = false

  private let service: any NuxProgressManaging
  private var currentUserId: String?

  init(service: (any NuxProgressManaging)? = nil) {
    self.service = service ?? NuxProgressServiceImpl(supabaseManager: .shared)
  }

  func load(userId: String) async {
    currentUserId = userId
    do {
      progress = try await service.fetchNuxProgress(userId: userId)
      isLoaded = true
      logger.info("NUX progress loaded for user \(userId, privacy: .private) (\(self.progress.checklist.completedCount)/\(NuxChecklistKey.allCases.count))")
    } catch {
      logger.error("Failed to load NUX progress: \(error.localizedDescription)")
      progress = .empty
      isLoaded = true
    }
  }

  func completeItem(_ key: NuxChecklistKey) {
    guard !progress.isItemCompleted(key) else { return }
    progress.completeItem(key)
    OnboardingAnalytics.checklistItemCompleted(item: key.rawValue)
    logger.info("NUX item completed: \(key.rawValue) (\(self.progress.checklist.completedCount)/\(NuxChecklistKey.allCases.count))")
    persistInBackground()
  }

  func dismissChecklist() {
    progress.checklist.dismissedAt = Date()
    OnboardingAnalytics.checklistDismissed()
    logger.info("NUX checklist dismissed")
    persistInBackground()
  }

  func resumeChecklist() {
    progress.checklist.dismissedAt = nil
    logger.info("NUX checklist resumed")
    persistInBackground()
  }

  func dismissPrompt(_ key: String) {
    progress.dismissPrompt(key)
    logger.info("NUX prompt dismissed: \(key)")
    persistInBackground()
  }

  func recordFirstVisit(_ key: String) {
    guard progress.firstVisits[key] == nil else { return }
    progress.firstVisits[key] = Date()
    logger.info("NUX first visit recorded: \(key)")
    persistInBackground()
  }

  private func persistInBackground() {
    guard let userId = currentUserId else { return }
    let snapshot = progress
    Task.detached { [service] in
      do {
        try await service.saveNuxProgress(userId: userId, progress: snapshot)
      } catch {
        Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "NuxProgressManager")
          .error("Background save failed: \(error.localizedDescription)")
      }
    }
  }
}
