import Foundation
import Observation
import OSLog

/// App-wide family entitlement state. Source of truth is `family_subscriptions` in Supabase;
/// this mirrors it for UI. Phase 0: only the Settings Plan row reads it.
@Observable
@MainActor
final class EntitlementStore {
  nonisolated deinit {}

  /// The last fetched row. Read through `subscription`, which hides it once it belongs to a family other than the
  /// one last asked for, so a switch never shows (or grants writes from) the previous family's plan.
  private var fetchedSubscription: FamilySubscription?
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  /// `true` once `load(familyUnitId:)` has completed at least once (success, no-family, or error).
  /// Lets callers distinguish "not yet loaded" from "loaded, no subscription row exists" — both
  /// leave `subscription` nil, but only the latter should render `planLabel`/`canWrite` as final.
  var hasLoaded: Bool { didLoad && loadedFamilyUnitId == requestedFamilyUnitId }
  private var didLoad = false
  private var loadedFamilyUnitId: String?
  /// The family of the latest `load` call, set before its fetch starts.
  private var requestedFamilyUnitId: String?

  var subscription: FamilySubscription? {
    fetchedSubscription?.familyUnitId == requestedFamilyUnitId ? fetchedSubscription : nil
  }

  /// Server flag hiding the trial day count while trials are held. Display-only; defaults to showing
  /// the countdown whenever the signal is unavailable (older server, error).
  private(set) var trialCountdownVisible = true

  /// The last completed load had no family to look up — a setup step, not a failure.
  private var loadedWithoutFamily = false

  /// Advanced by `reset()`; a fetch only applies while its session is still current.
  private var session = 0

  /// Advanced by every `load`. Only the latest call applies, so a slow answer for the family the user just
  /// switched away from cannot overwrite the selected family's plan (and its write access).
  private var loadEpoch = 0

  private let service: any EntitlementManaging
  private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "EntitlementStore")

  /// Reflects only whatever `familyUnitId` was last passed to `load(familyUnitId:)`. Defaults to
  /// `false` until `load` has been called at least once — currently only `SettingsView` and
  /// `PlanView` call it. Phase 1 work that gates write actions elsewhere must first ensure `load`
  /// has run for the active family (e.g. on session restore / family switch), or this will
  /// incorrectly read as read-only.
  var canWrite: Bool { subscription?.canWrite() ?? false }
  var planLabel: String {
    if let subscription { return subscription.planLabel(countdownVisible: trialCountdownVisible) }
    return loadedWithoutFamily ? PlanLabel.noFamily : PlanLabel.unavailable
  }

  init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared)) {
    self.service = service
  }

  /// Forgets the previous family's plan on sign-out or account switch.
  func reset() {
    session += 1
    fetchedSubscription = nil
    trialCountdownVisible = true
    errorMessage = nil
    isLoading = false
    didLoad = false
    loadedFamilyUnitId = nil
    requestedFamilyUnitId = nil
    loadedWithoutFamily = false
  }

  func load(familyUnitId: String?) async {
    loadEpoch += 1
    let epoch = loadEpoch
    requestedFamilyUnitId = familyUnitId
    guard let familyUnitId else {
      // This call overtakes any fetch in flight, which will now return early, so it must clear `isLoading` itself.
      fetchedSubscription = nil
      errorMessage = nil
      isLoading = false
      loadedWithoutFamily = true
      loadedFamilyUnitId = nil
      didLoad = true
      return
    }
    isLoading = true
    let loadSession = session
    async let countdownVisible = fetchCountdownVisible()
    let result: Result<FamilySubscription?, Error>
    do {
      result = .success(try await service.fetchSubscription(familyUnitId: familyUnitId))
    } catch {
      result = .failure(error)
    }
    let visible = await countdownVisible
    guard loadSession == session, epoch == loadEpoch else { return }
    isLoading = false
    // A view's `.task` is cancelled when the view disappears — Settings' load is cancelled the moment
    // Plan is pushed. That is not a failed load: keep whatever a concurrent load produced.
    if case .failure(let error) = result, Self.isCancellation(error) { return }
    didLoad = true
    loadedFamilyUnitId = familyUnitId
    loadedWithoutFamily = false
    trialCountdownVisible = visible
    switch result {
    case .success(let fetched):
      fetchedSubscription = fetched
      errorMessage = nil
    case .failure(let error):
      fetchedSubscription = nil
      // fetchSubscription has no typed error of its own (raw Supabase SDK
      // errors) -- never surface that wording to the user directly.
      errorMessage = String(localized: "Unable to load your plan. Please try again.")
      logger.error("Failed to load entitlement: \(error.localizedDescription)")
    }
  }

  private func fetchCountdownVisible() async -> Bool {
    do {
      return try await service.fetchTrialCountdownVisible()
    } catch {
      logger.info("Trial countdown flag unavailable, showing countdown: \(error.localizedDescription)")
      return true
    }
  }

  private static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
