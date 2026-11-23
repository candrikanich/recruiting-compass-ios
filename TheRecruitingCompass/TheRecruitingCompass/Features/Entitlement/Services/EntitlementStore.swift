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
  var hasLoaded: Bool { didLoad && loadedFamilyUnitId == selectedFamilyUnitId }
  private var didLoad = false
  private var loadedFamilyUnitId: String?
  /// The family of the latest `load` call, set before its fetch starts.
  private var requestedFamilyUnitId: String?

  /// Reads the app's selected family, so every read below follows a family switch the instant it happens rather
  /// than when some screen next calls `load`. Without one, the latest `load`'s family stands in.
  private let currentSelection: (@MainActor () -> String?)?

  private var selectedFamilyUnitId: String? {
    if let currentSelection { return currentSelection() }
    return requestedFamilyUnitId
  }

  var subscription: FamilySubscription? {
    fetchedSubscription?.familyUnitId == selectedFamilyUnitId ? fetchedSubscription : nil
  }

  /// Server flag hiding the trial day count while trials are held. Display-only; defaults to showing
  /// the countdown whenever the signal is unavailable (older server, error).
  private(set) var trialCountdownVisible = true

  /// The last completed load had no family to look up — a setup step, not a failure.
  private var loadedWithoutFamily = false

  /// Advanced by `reset()`; a fetch only applies while its session is still current.
  private var session = 0

  /// Advanced by every `load`; a result applies only if no later load has already applied, so an older
  /// answer cannot overwrite a newer one.
  private var loadEpoch = 0
  private var lastAppliedEpoch = 0

  /// Fetches still running for the current session. `isLoading` stays true until the last one returns, so a
  /// cancelled load cannot clear the spinner while another load for the same family is still in flight.
  private var loadsInFlight = 0

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
    return loadedWithoutFamily && hasLoaded ? PlanLabel.noFamily : PlanLabel.unavailable
  }

  init(
    service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared),
    selectedFamilyUnitId: (@MainActor () -> String?)? = nil
  ) {
    self.service = service
    self.currentSelection = selectedFamilyUnitId
  }

  /// Forgets the previous family's plan on sign-out or account switch.
  func reset() {
    session += 1
    fetchedSubscription = nil
    trialCountdownVisible = true
    errorMessage = nil
    isLoading = false
    loadsInFlight = 0
    lastAppliedEpoch = loadEpoch
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
      // `lastAppliedEpoch` stays put: the family guard already drops answers for a family no longer requested, and
      // advancing it here would drop a slow answer for a family that is requested again by the time it lands.
      return
    }
    isLoading = true
    loadsInFlight += 1
    let loadSession = session
    async let countdownVisible = fetchCountdownVisible()
    let result: Result<FamilySubscription?, Error>
    do {
      result = .success(try await service.fetchSubscription(familyUnitId: familyUnitId))
    } catch {
      result = .failure(error)
    }
    let visible = await countdownVisible
    guard loadSession == session else { return }
    loadsInFlight -= 1
    isLoading = loadsInFlight > 0
    // A view's `.task` is cancelled when the view disappears — Settings' load is cancelled the moment
    // Plan is pushed. That is not a failed load: keep whatever a concurrent load produced or will produce.
    if case .failure(let error) = result, Self.isCancellation(error) { return }
    // Judge by family, not by being the latest call: an earlier answer for the family now selected is valid,
    // while one for a family the user switched away from must never apply.
    guard familyUnitId == requestedFamilyUnitId, epoch > lastAppliedEpoch else { return }
    // An older failure must not revoke a plan or flash an error while a newer load is still on its way; that
    // load answers for itself. With nothing else running, the failure is the final word and must show.
    if case .failure = result, epoch < loadEpoch, loadsInFlight > 0 { return }
    lastAppliedEpoch = epoch
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
