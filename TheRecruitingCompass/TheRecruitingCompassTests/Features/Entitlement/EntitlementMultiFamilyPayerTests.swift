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
}
