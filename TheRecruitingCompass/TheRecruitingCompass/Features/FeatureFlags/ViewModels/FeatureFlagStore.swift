import Foundation
import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FeatureFlags")

/// Remote kill switches. A feature is on unless the server lists its key. The last server answer is persisted so a
/// cold launch honours it before the first refresh returns; with nothing persisted (first install) or on a missing
/// RPC, an error or being offline, the store fails open and never hides anything on its own.
@Observable
@MainActor
final class FeatureFlagStore {
  static let persistedKey = "featureFlags.disabledKeys"

  private(set) var disabled: Set<FeatureKey>
  private(set) var hasResolvedInitialState = false

  private let service: FeatureFlagFetching
  private let defaults: UserDefaults
  private var latestRefresh = 0

  init(service: FeatureFlagFetching = FeatureFlagService(), defaults: UserDefaults = .standard) {
    self.service = service
    self.defaults = defaults
    let persisted = defaults.stringArray(forKey: Self.persistedKey) ?? []
    disabled = Set(persisted.compactMap(FeatureKey.init(rawValue:)))
  }

  nonisolated deinit {}

  func isEnabled(_ key: FeatureKey) -> Bool {
    !disabled.contains(key)
  }

  /// Deep links and push taps that arrive on a cold launch wait here so they are routed against the server's
  /// current answer, not just the persisted one. Fails open after `timeout` (offline, slow or missing RPC).
  func waitForInitialState(timeout: Duration = .seconds(3)) async {
    let deadline = ContinuousClock.now + timeout
    while !hasResolvedInitialState, ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(25))
    }
  }

  /// On error the last known state stands: a flaky network shouldn't switch a killed feature back on.
  /// Launch and foreground refreshes can overlap; only the most recently started one applies.
  func refresh() async {
    latestRefresh += 1
    let thisRefresh = latestRefresh
    // A superseded refresh must not release cold-launch waiters; the newest one will.
    defer { if thisRefresh == latestRefresh { hasResolvedInitialState = true } }
    do {
      let keys = try await service.fetchDisabledFeatureKeys()
      guard thisRefresh == latestRefresh else { return }
      disabled = Set(keys.compactMap(FeatureKey.init(rawValue:)))
      defaults.set(disabled.map(\.rawValue).sorted(), forKey: Self.persistedKey)
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

/// Enforces a kill switch at the destination itself, so every present and future entry point is covered
/// without each call site remembering to check. The wrapped content is never built while the feature is off.
private struct FeatureGateModifier: ViewModifier {
  let key: FeatureKey
  @Environment(FeatureFlagStore.self) private var flags: FeatureFlagStore?
  /// Fixed on first appearance: a switch never interrupts a flow already on screen.
  @State private var admitted: Bool?
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    let allowed = admitted ?? flags.isEnabled(key)
    Group {
      if allowed {
        content
      } else {
        ContentUnavailableView {
          Label("Temporarily Unavailable", systemImage: "pause.circle")
        } description: {
          Text("This feature is turned off right now. Please check back soon.")
        } actions: {
          Button("Close") { dismiss() }
        }
      }
    }
    .onAppear { if admitted == nil { admitted = allowed } }
  }
}

extension View {
  func featureGated(_ key: FeatureKey) -> some View {
    modifier(FeatureGateModifier(key: key))
  }
}
