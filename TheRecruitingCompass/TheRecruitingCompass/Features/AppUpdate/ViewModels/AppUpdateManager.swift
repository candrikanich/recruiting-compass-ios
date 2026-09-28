import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AppUpdate")

/// Owns the app-version lifecycle: the server-driven update gate/prompt and the post-upgrade What's New.
@Observable
@MainActor
final class AppUpdateManager {
  static let lastSeenVersionKey = "appUpdate.lastSeenVersion"
  static let dismissedRecommendedVersionKey = "appUpdate.dismissedRecommendedVersion"
  private static let staleInterval: TimeInterval = 60 * 60

  private(set) var status: AppUpdateStatus = .upToDate
  private(set) var isShowingUpdatePrompt = false
  private(set) var pendingWhatsNew: WhatsNewRelease?

  var isUpdateRequired: Bool {
    if case .updateRequired = status { return true }
    return false
  }

  private let service: AppVersionPolicyFetching
  private let currentVersion: AppVersion
  private let defaults: UserDefaults
  private let whatsNewCatalog: [WhatsNewRelease]
  private let now: () -> Date
  private var lastSuccessfulCheck: Date?
  private var latestCheck = 0

  init(
    service: AppVersionPolicyFetching = AppVersionPolicyService(),
    currentVersion: AppVersion = AppVersion(AppInfo.version) ?? AppVersion(major: 0, minor: 0, patch: 0),
    defaults: UserDefaults = .standard,
    whatsNewCatalog: [WhatsNewRelease] = WhatsNewCatalog.releases,
    now: @escaping () -> Date = Date.init
  ) {
    self.service = service
    self.currentVersion = currentVersion
    self.defaults = defaults
    self.whatsNewCatalog = whatsNewCatalog
    self.now = now
  }

  nonisolated deinit {}

  // MARK: - Update gate

  /// Fails open: on error the previous status stands, so a flaky network never blocks a user who wasn't
  /// already blocked. Launch and foreground checks can overlap; only the most recently started one applies.
  func check() async {
    latestCheck += 1
    let thisCheck = latestCheck
    do {
      let policy = try await service.fetchPolicy()
      guard thisCheck == latestCheck else { return }
      lastSuccessfulCheck = now()
      apply(AppUpdateStatus.evaluate(current: currentVersion, policy: policy))
    } catch {
      logger.info("Version policy check failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func checkIfStale() async {
    if let lastSuccessfulCheck, now().timeIntervalSince(lastSuccessfulCheck) < Self.staleInterval { return }
    await check()
  }

  func dismissUpdatePrompt() {
    if case .updateAvailable(let version) = status {
      defaults.set(version.description, forKey: Self.dismissedRecommendedVersionKey)
    }
    isShowingUpdatePrompt = false
  }

  private func apply(_ newStatus: AppUpdateStatus) {
    status = newStatus
    guard case .updateAvailable(let version) = newStatus else {
      isShowingUpdatePrompt = false
      return
    }
    isShowingUpdatePrompt = defaults.string(forKey: Self.dismissedRecommendedVersionKey) != version.description
  }

  // MARK: - What's New

  /// Fresh installs (no recorded version) are recorded silently; an upgrade shows the current version's
  /// catalog entry if it has one. The version is recorded either way so each entry shows at most once.
  func evaluateWhatsNew() {
    let lastSeen = defaults.string(forKey: Self.lastSeenVersionKey).flatMap(AppVersion.init)
    defaults.set(currentVersion.description, forKey: Self.lastSeenVersionKey)

    guard let lastSeen, lastSeen < currentVersion else { return }
    pendingWhatsNew = whatsNewCatalog.first { $0.version == currentVersion }
  }

  func dismissWhatsNew() {
    pendingWhatsNew = nil
  }
}
