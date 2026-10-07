import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FeatureFlags")

/// Remote kill switches. A feature is on unless the server lists its key; the store starts with everything on
/// and fails open, so a missing RPC, an error or being offline never hides anything on its own.
@Observable
@MainActor
final class FeatureFlagStore {
  private(set) var disabled: Set<FeatureKey> = []

  private let service: FeatureFlagFetching
  private var latestRefresh = 0

  init(service: FeatureFlagFetching = FeatureFlagService()) {
    self.service = service
  }

  nonisolated deinit {}

  func isEnabled(_ key: FeatureKey) -> Bool {
    !disabled.contains(key)
  }

  /// On error the last known state stands: a flaky network shouldn't switch a killed feature back on.
  /// Launch and foreground refreshes can overlap; only the most recently started one applies.
  func refresh() async {
    latestRefresh += 1
    let thisRefresh = latestRefresh
    do {
      let keys = try await service.fetchDisabledFeatureKeys()
      guard thisRefresh == latestRefresh else { return }
      disabled = Set(keys.compactMap(FeatureKey.init(rawValue:)))
    } catch {
      logger.info("Feature flag refresh failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}

extension FeatureFlagStore? {
  /// Views read the store as an optional environment value so previews and tests without one stay fully on.
  @MainActor
  func isEnabled(_ key: FeatureKey) -> Bool {
    self?.isEnabled(key) ?? true
  }
}
