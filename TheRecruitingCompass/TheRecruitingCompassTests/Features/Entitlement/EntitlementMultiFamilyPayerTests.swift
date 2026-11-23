import XCTest
@testable import TheRecruitingCompass

/// A parent paying for family A while family B is unseated (#604): the plan and write access shown must always be
/// the selected family's own, never the other family's.
@MainActor
final class EntitlementMultiFamilyPayerTests: XCTestCase {
  nonisolated deinit {}

  private let renewal = Date(timeIntervalSince1970: 4_000_000_000)

  private var seatedActive: FamilySubscription {
    FamilySubscription(
      familyUnitId: "family-a", status: .active, source: "apple", trialEndsAt: nil, currentPeriodEnd: renewal
    )
  }

  private let unseatedReadOnly = FamilySubscription(
    familyUnitId: "family-b", status: .readOnly, source: "none", trialEndsAt: nil, currentPeriodEnd: nil
  )

  private func makeStore() -> (EntitlementStore, MockEntitlementService) {
    let mock = MockEntitlementService()
    mock.subscriptionsByFamilyId = ["family-a": seatedActive, "family-b": unseatedReadOnly]
    return (EntitlementStore(service: mock), mock)
  }

  func test_planFollowsTheSelectedFamilyAcrossASwitch() async {
    let (store, mock) = makeStore()

    await store.load(familyUnitId: "family-a")
    XCTAssertEqual(store.subscription?.familyUnitId, "family-a")
    XCTAssertTrue(store.planLabel.hasPrefix("Active — renews"), store.planLabel)
    XCTAssertTrue(store.canWrite)

    await store.load(familyUnitId: "family-b")
    XCTAssertEqual(store.subscription?.familyUnitId, "family-b")
    XCTAssertEqual(store.planLabel, "Read-only — subscription needed")
    XCTAssertFalse(store.canWrite, "the unseated family stays read-only even though the payer's other family is active")

    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.canWrite)
    XCTAssertEqual(mock.requestedFamilyIds, ["family-a", "family-b", "family-a"])
  }

  func test_aFamilyWithoutASubscriptionRowIsNotGivenTheOtherFamilysPlan() async {
    let mock = MockEntitlementService()
    mock.subscriptionsByFamilyId = ["family-a": seatedActive]
    let store = EntitlementStore(service: mock)
    await store.load(familyUnitId: "family-a")

    await store.load(familyUnitId: "family-b")

    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
  }

  func test_aSlowLoadForTheFamilyJustLeftDoesNotOverwriteTheFamilySwitchedTo() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate()
    mock.fetchGateByFamily = { familyId in
      if familyId == "family-a" { await gate.wait() }
    }

    let slowA = Task { await store.load(familyUnitId: "family-a") }
    let enteredA = await gate.untilEntered()
    XCTAssertTrue(enteredA)
    await store.load(familyUnitId: "family-b")
    gate.open()
    await slowA.value

    XCTAssertEqual(store.subscription?.familyUnitId, "family-b")
    XCTAssertFalse(store.canWrite, "family A's late answer must not unlock writes in read-only family B")
  }

  func test_aSameFamilyReloadStillAppliesTheLatestAnswer() async {
    let (store, mock) = makeStore()
    await store.load(familyUnitId: "family-b")
    mock.subscriptionsByFamilyId["family-b"] = FamilySubscription(
      familyUnitId: "family-b", status: .active, source: "apple", trialEndsAt: nil, currentPeriodEnd: renewal
    )

    await store.load(familyUnitId: "family-b")

    XCTAssertTrue(store.canWrite)
  }

  func test_resetDiscardsAnInFlightLoad() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate()
    mock.fetchGateByFamily = { _ in await gate.wait() }

    let inFlight = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    store.reset()
    gate.open()
    await inFlight.value

    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.hasLoaded)
  }

  func test_aNoFamilyLoadThatOvertakesAFetchInFlightClearsLoadingAndStaysUnloaded() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate()
    mock.fetchGateByFamily = { _ in await gate.wait() }
    let inFlight = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)

    await store.load(familyUnitId: nil)
    gate.open()
    await inFlight.value

    XCTAssertFalse(store.isLoading, "the overtaken fetch returns early, so the no-family load clears the spinner")
    XCTAssertTrue(store.hasLoaded)
    XCTAssertNil(store.subscription)
    XCTAssertEqual(store.planLabel, PlanLabel.noFamily)
  }

  func test_afterASwitchThePlanIsNeverTheFamilyJustLeftNotEvenWhileTheNewOneLoads() async {
    let (store, mock) = makeStore()
    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.canWrite)
    let gate = AsyncGate()
    mock.fetchGateByFamily = { familyId in
      if familyId == "family-b" { await gate.wait() }
    }

    let switching = Task { await store.load(familyUnitId: "family-b") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)

    XCTAssertNil(store.subscription, "family A's plan must not stand in for B's while B loads")
    XCTAssertFalse(store.canWrite)
    XCTAssertFalse(store.hasLoaded)
    gate.open()
    await switching.value
    XCTAssertEqual(store.subscription?.familyUnitId, "family-b")
  }

  func test_aCancelledLoadWithNothingElseInFlightLeavesNoPlanRatherThanTheOldFamilys() async {
    let (store, mock) = makeStore()
    await store.load(familyUnitId: "family-a")
    mock.error = CancellationError()

    await store.load(familyUnitId: "family-b")

    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite, "a cancelled switch must not leave family A's write access in place")
    XCTAssertFalse(store.hasLoaded)
    XCTAssertFalse(store.isLoading)
  }

  func test_aLaterCancelledLoadForTheSameFamilyDoesNotStrandTheEarlierLoadsResult() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate(blockedEntries: 1)
    mock.fetchGateByFamily = { _ in await gate.wait() }
    mock.errorsByCallIndex[1] = CancellationError()

    let earlier = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.isLoading, "the earlier fetch for this family is still running")
    gate.open()
    await earlier.value

    XCTAssertTrue(store.hasLoaded, "PlanView spins forever unless the earlier answer lands")
    XCTAssertFalse(store.isLoading)
    XCTAssertEqual(store.subscription?.familyUnitId, "family-a")
    XCTAssertTrue(store.canWrite)
  }

  func test_anOlderFailedAnswerDoesNotOverwriteANewerSuccessForTheSameFamily() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate(blockedEntries: 1)
    mock.fetchGateByFamily = { _ in await gate.wait() }
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    let older = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.canWrite)

    gate.open()
    await older.value

    XCTAssertTrue(store.canWrite, "an older failed answer revoked write access")
    XCTAssertNil(store.errorMessage)
    XCTAssertEqual(store.subscription?.familyUnitId, "family-a")
  }

  func test_aFailedAnswerForTheFamilyJustLeftDoesNotSurfaceWhileTheNewOneLoads() async {
    let (store, mock) = makeStore()
    let gateA = AsyncGate()
    let gateB = AsyncGate()
    mock.fetchGateByFamily = { familyId in
      if familyId == "family-a" { await gateA.wait() } else { await gateB.wait() }
    }
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    let leftFamily = Task { await store.load(familyUnitId: "family-a") }
    let enteredA = await gateA.untilEntered()
    XCTAssertTrue(enteredA)
    let selectedFamily = Task { await store.load(familyUnitId: "family-b") }
    let enteredB = await gateB.untilEntered()
    XCTAssertTrue(enteredB)

    gateA.open()
    await leftFamily.value

    XCTAssertNil(store.errorMessage, "family A's failure surfaced while B loads")
    XCTAssertTrue(store.isLoading)
    gateB.open()
    await selectedFamily.value
    XCTAssertEqual(store.subscription?.familyUnitId, "family-b")
    XCTAssertNil(store.errorMessage)
  }

  // MARK: - Following the selected family (#617)

  /// Stands in for `FamilyManager.familyUnitId`, which changes without anyone calling `load`.
  private final class Selection {
    var familyUnitId: String?
    init(_ familyUnitId: String?) { self.familyUnitId = familyUnitId }
  }

  private func makeFollowingStore(selecting selection: Selection) -> EntitlementStore {
    let mock = MockEntitlementService()
    mock.subscriptionsByFamilyId = ["family-a": seatedActive, "family-b": unseatedReadOnly]
    return EntitlementStore(service: mock, selectedFamilyUnitId: { selection.familyUnitId })
  }

  func test_aSwitchWithNoLoadYetNeverReadsAsTheFamilyJustLeft() async {
    let selection = Selection("family-a")
    let store = makeFollowingStore(selecting: selection)
    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.canWrite)

    selection.familyUnitId = "family-b"

    XCTAssertNil(store.subscription, "family A's row must not stand in for B before anything has loaded B")
    XCTAssertFalse(store.canWrite)
    XCTAssertFalse(store.hasLoaded)
    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    await store.load(familyUnitId: "family-b")
    XCTAssertEqual(store.planLabel, "Read-only — subscription needed")
  }

  func test_leavingTheLastFamilyWithNoLoadYetNeverReadsAsTheFamilyJustLeft() async {
    let selection = Selection("family-a")
    let store = makeFollowingStore(selecting: selection)
    await store.load(familyUnitId: "family-a")

    selection.familyUnitId = nil

    XCTAssertFalse(store.canWrite)
    XCTAssertFalse(store.hasLoaded)
  }

  func test_loadedStateReturnsWhenTheSelectionComesBackToTheLoadedFamily() async {
    let selection = Selection("family-a")
    let store = makeFollowingStore(selecting: selection)
    await store.load(familyUnitId: "family-a")
    selection.familyUnitId = "family-b"
    selection.familyUnitId = "family-a"

    XCTAssertTrue(store.canWrite)
    XCTAssertTrue(store.hasLoaded)
  }

  func test_aNoFamilyLoadThenTheSameFamilyAgainStillTakesTheSlowEarlierAnswer() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate(blockedEntries: 1)
    mock.fetchGateByFamily = { _ in await gate.wait() }
    mock.errorsByCallIndex[1] = CancellationError()
    let slow = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await store.load(familyUnitId: nil)
    await store.load(familyUnitId: "family-a")
    XCTAssertFalse(store.hasLoaded, "the cancelled reload applied nothing and the slow load is still running")

    gate.open()
    await slow.value

    XCTAssertTrue(store.hasLoaded, "the store stays stranded unloaded with nothing in flight")
    XCTAssertFalse(store.isLoading)
    XCTAssertEqual(store.subscription?.familyUnitId, "family-a")
    XCTAssertTrue(store.canWrite)
  }

  func test_aNoFamilyLoadStillDropsASlowAnswerWhileNoFamilyIsTheLatestRequest() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate()
    mock.fetchGateByFamily = { _ in await gate.wait() }
    let slow = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await store.load(familyUnitId: nil)

    gate.open()
    await slow.value

    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertEqual(store.planLabel, PlanLabel.noFamily)
  }

  func test_anOlderFailureWhileANewerLoadIsInFlightNeitherFlashesNorRevokesAPayingFamily() async {
    let (store, mock) = makeStore()
    await store.load(familyUnitId: "family-a")
    XCTAssertTrue(store.canWrite)
    let first = AsyncGate(blockedEntries: 1)
    let second = AsyncGate()
    mock.fetchGateByFamily = { _ in
      if await first.enteredCount == 0 { await first.wait() } else { await second.wait() }
    }
    mock.errorsByCallIndex[1] = URLError(.timedOut)
    let older = Task { await store.load(familyUnitId: "family-a") }
    let enteredFirst = await first.untilEntered()
    XCTAssertTrue(enteredFirst)
    let newer = Task { await store.load(familyUnitId: "family-a") }
    let enteredSecond = await second.untilEntered()
    XCTAssertTrue(enteredSecond)

    first.open()
    await older.value

    XCTAssertNil(store.errorMessage, "an older failure flashed the error while the newer load is still running")
    XCTAssertTrue(store.canWrite, "an older failure revoked a paying family's write access")
    XCTAssertTrue(store.isLoading)
    second.open()
    await newer.value
    XCTAssertTrue(store.canWrite)
    XCTAssertNil(store.errorMessage)
  }

  func test_anOlderFailureWithNothingNewerInFlightStillSurfaces() async {
    let (store, mock) = makeStore()
    let gate = AsyncGate(blockedEntries: 1)
    mock.fetchGateByFamily = { _ in await gate.wait() }
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[1] = CancellationError()
    let older = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await store.load(familyUnitId: "family-a")

    gate.open()
    await older.value

    XCTAssertNotNil(store.errorMessage, "the only answer that landed is a failure; hiding it leaves a silent blank")
    XCTAssertFalse(store.isLoading)
  }

  func test_noFamilyLabelDoesNotLingerOverTheNextFamilyWhileItLoads() async {
    let (store, mock) = makeStore()
    await store.load(familyUnitId: nil)
    XCTAssertEqual(store.planLabel, PlanLabel.noFamily)
    let gate = AsyncGate()
    mock.fetchGateByFamily = { _ in await gate.wait() }

    let joining = Task { await store.load(familyUnitId: "family-a") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)

    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    gate.open()
    await joining.value
  }

  /// Hands the Nth gated fetch (0-based) its own gate, so a test controls each fetch independently.
  private func gateEachCall(_ mock: MockEntitlementService, _ gates: [AsyncGate]) {
    mock.fetchGateByFamily = { _ in
      for gate in gates {
        if await gate.enteredCount == 0 {
          await gate.wait()
          return
        }
      }
    }
  }

  func test_aFetchFromBeforeResetDoesNotClearTheNewSessionsSpinner() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    let stale = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    store.reset()
    let fresh = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)

    gates[0].open()
    await stale.value

    XCTAssertTrue(store.isLoading, "a pre-reset fetch cleared the spinner while the new session's load runs")
    gates[1].open()
    await fresh.value
    XCTAssertFalse(store.isLoading)
    XCTAssertTrue(store.canWrite)
  }

  func test_aFetchFromBeforeResetDoesNotLetAnOlderFailureFlash() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    mock.errorsByCallIndex[1] = URLError(.timedOut)
    let stale = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    store.reset()
    let older = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)
    let newer = Task { await store.load(familyUnitId: "family-a") }
    let e2 = await gates[2].untilEntered()
    XCTAssertTrue(e2)

    gates[0].open()
    await stale.value
    gates[1].open()
    await older.value

    XCTAssertNil(store.errorMessage, "older failure flashed while the newer load is still in flight")
    gates[2].open()
    await newer.value
    XCTAssertTrue(store.canWrite)
    XCTAssertNil(store.errorMessage)
  }

  /// Older load fails first while a newer one runs, then the newer one is cancelled (user backs out of Plan).
  /// The PR's own invariant: "With nothing else running, the failure is the final word and must show."
  func test_anOlderFailureThenTheNewerLoadCancelledStillShowsTheFailure() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[1] = CancellationError()
    let older = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    let newer = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)

    gates[0].open()
    await older.value
    gates[1].open()
    await newer.value

    XCTAssertFalse(store.isLoading)
    XCTAssertTrue(
      store.errorMessage != nil || store.hasLoaded,
      "nothing in flight, no error, not loaded: a silent blank with no retry prompt"
    )
  }

  /// The latest load fails while an older one for the same family is still running and later is cancelled.
  func test_theLatestFailureStillShowsWhenTheOlderLoadIsThenCancelled() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    mock.errorsByCallIndex[0] = CancellationError()
    mock.errorsByCallIndex[1] = URLError(.timedOut)
    let older = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    let newer = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)

    gates[1].open()
    await newer.value
    XCTAssertNotNil(store.errorMessage, "the latest load's failure waited on an older load instead of showing")
    gates[0].open()
    await older.value

    XCTAssertFalse(store.isLoading)
    XCTAssertNotNil(store.errorMessage, "the latest load's failure never surfaced")
  }

  func test_aSuppressedFailureForAFamilyNoLongerRequestedNeverSurfaces() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[1] = CancellationError()
    mock.errorsByCallIndex[2] = CancellationError()
    let first = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    let second = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)
    gates[0].open()
    await first.value
    let toB = Task { await store.load(familyUnitId: "family-b") }
    let e2 = await gates[2].untilEntered()
    XCTAssertTrue(e2)

    gates[1].open()
    await second.value
    gates[2].open()
    await toB.value

    XCTAssertNil(store.errorMessage, "family A's held-back failure surfaced for B")
    XCTAssertFalse(store.canWrite)
  }

  func test_aSuppressedFailureWaitsForEveryOtherLoadToEnd() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    gateEachCall(mock, gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[1] = CancellationError()
    let first = Task { await store.load(familyUnitId: "family-a") }
    let e0 = await gates[0].untilEntered()
    XCTAssertTrue(e0)
    let second = Task { await store.load(familyUnitId: "family-a") }
    let e1 = await gates[1].untilEntered()
    XCTAssertTrue(e1)
    let third = Task { await store.load(familyUnitId: "family-a") }
    let e2 = await gates[2].untilEntered()
    XCTAssertTrue(e2)
    gates[0].open()
    await first.value

    gates[1].open()
    await second.value

    XCTAssertNil(store.errorMessage, "the held-back failure surfaced while the newest load is still running")
    XCTAssertTrue(store.isLoading)
    gates[2].open()
    await third.value
    XCTAssertTrue(store.canWrite)
    XCTAssertNil(store.errorMessage)
  }
}
