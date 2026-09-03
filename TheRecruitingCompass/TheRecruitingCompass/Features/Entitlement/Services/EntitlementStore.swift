import Foundation
import Observation
import OSLog

/// App-wide family entitlement state. Source of truth is `family_subscriptions` in Supabase;
/// this mirrors it for UI. Phase 0: only the Settings Plan row reads it.
@Observable
@MainActor
final class EntitlementStore {
  nonisolated deinit {}

  private(set) var subscription: FamilySubscription?
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  /// `true` once `load(familyUnitId:)` has completed at least once (success, no-family, or error).
  /// Lets callers distinguish "not yet loaded" from "loaded, no subscription row exists" — both
  /// leave `subscription` nil, but only the latter should render `planLabel`/`canWrite` as final.
  private(set) var hasLoaded = false

  private let service: any EntitlementManaging
  private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "EntitlementStore")

  /// Reflects only whatever `familyUnitId` was last passed to `load(familyUnitId:)`. Defaults to
  /// `false` until `load` has been called at least once — currently only `SettingsView` and
  /// `PlanView` call it. Phase 1 work that gates write actions elsewhere must first ensure `load`
  /// has run for the active family (e.g. on session restore / family switch), or this will
  /// incorrectly read as read-only.
  var canWrite: Bool { subscription?.canWrite() ?? false }
  var planLabel: String { subscription?.planLabel() ?? PlanLabel.unavailable }

  init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared)) {
    self.service = service
  }

  func load(familyUnitId: String?) async {
    guard let familyUnitId else {
      subscription = nil
      errorMessage = nil
      hasLoaded = true
      return
    }
    isLoading = true
    defer {
      isLoading = false
      hasLoaded = true
    }
    do {
      subscription = try await service.fetchSubscription(familyUnitId: familyUnitId)
      errorMessage = nil
    } catch {
      subscription = nil
      errorMessage = error.localizedDescription
      logger.error("Failed to load entitlement: \(error.localizedDescription)")
    }
  }
}
