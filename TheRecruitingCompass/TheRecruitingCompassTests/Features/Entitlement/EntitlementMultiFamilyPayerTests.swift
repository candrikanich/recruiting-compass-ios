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
}
