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

  /// The last completed load had no family to look up — a setup step, not a failure.
  private var loadedWithoutFamily = false

  /// Advanced by `reset()`; a fetch only applies while its session is still current.
  private var session = 0

  private let service: any EntitlementManaging
  private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "EntitlementStore")

  /// Reflects only whatever `familyUnitId` was last passed to `load(familyUnitId:)`. Defaults to
  /// `false` until `load` has been called at least once — currently only `SettingsView` and
  /// `PlanView` call it. Phase 1 work that gates write actions elsewhere must first ensure `load`
  /// has run for the active family (e.g. on session restore / family switch), or this will
  /// incorrectly read as read-only.
  var canWrite: Bool { subscription?.canWrite() ?? false }
  var planLabel: String {
    if let subscription { return subscription.planLabel() }
    return loadedWithoutFamily ? PlanLabel.noFamily : PlanLabel.unavailable
  }

  init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared)) {
    self.service = service
  }

  /// Forgets the previous family's plan on sign-out or account switch.
  func reset() {
    session += 1
    subscription = nil
    errorMessage = nil
    isLoading = false
    hasLoaded = false
    loadedWithoutFamily = false
  }

  func load(familyUnitId: String?) async {
    guard let familyUnitId else {
      subscription = nil
      errorMessage = nil
      loadedWithoutFamily = true
      hasLoaded = true
      return
    }
    isLoading = true
    let loadSession = session
    let result: Result<FamilySubscription?, Error>
    do {
      result = .success(try await service.fetchSubscription(familyUnitId: familyUnitId))
    } catch {
      result = .failure(error)
    }
    guard loadSession == session else { return }
    isLoading = false
    // A view's `.task` is cancelled when the view disappears — Settings' load is cancelled the moment
    // Plan is pushed. That is not a failed load: keep whatever a concurrent load produced.
    if case .failure(let error) = result, Self.isCancellation(error) { return }
    hasLoaded = true
    loadedWithoutFamily = false
    switch result {
    case .success(let fetched):
      subscription = fetched
      errorMessage = nil
    case .failure(let error):
      subscription = nil
      // fetchSubscription has no typed error of its own (raw Supabase SDK
      // errors) -- never surface that wording to the user directly.
      errorMessage = String(localized: "Unable to load your plan. Please try again.")
      logger.error("Failed to load entitlement: \(error.localizedDescription)")
    }
  }

  private static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
