import XCTest
@testable import TheRecruitingCompass

/// The store holds back an older failed answer while a newer load for the same family is still in flight (#617), so
/// the failure neither flashes an error nor revokes a paying family's write access. These pin when that held failure
/// finally shows and, just as much, when it must never: each test asserts the whole visible state (spinner, error,
/// loaded, write access), because a wrong guard moves a different member each time.
@MainActor
final class EntitlementHeldFailureTests: XCTestCase {
  nonisolated deinit {}

  /// What a screen can observe of the store.
  private struct Shown: Equatable {
    var loading: Bool
    var error: Bool
    var loaded: Bool
    var canWrite: Bool
  }

  private let renewal = Date(timeIntervalSince1970: 4_000_000_000)

  private func makeStore() -> (EntitlementStore, MockEntitlementService) {
    let mock = MockEntitlementService()
    mock.subscriptionsByFamilyId = [
      "family-a": FamilySubscription(
        familyUnitId: "family-a", status: .active, source: "apple", trialEndsAt: nil, currentPeriodEnd: renewal
      ),
      "family-b": FamilySubscription(
        familyUnitId: "family-b", status: .readOnly, source: "none", trialEndsAt: nil, currentPeriodEnd: nil
      )
    ]
    return (EntitlementStore(service: mock), mock)
  }

  private func shown(_ store: EntitlementStore) -> Shown {
    Shown(
      loading: store.isLoading, error: store.errorMessage != nil, loaded: store.hasLoaded, canWrite: store.canWrite
    )
  }

  /// Starts a load and returns once its fetch is parked on `gate`.
  private func startLoad(
    _ store: EntitlementStore, _ familyUnitId: String?, gate: AsyncGate, line: UInt = #line
  ) async -> Task<Void, Never> {
    let load = Task { await store.load(familyUnitId: familyUnitId) }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered, "the load never reached its fetch", line: line)
    return load
  }

  private func finish(_ gate: AsyncGate, _ load: Task<Void, Never>) async {
    gate.open()
    await load.value
  }

  /// A1 fails and is held while B and then A2 load; A2 is cancelled; B, the last fetch running, lands and is
  /// dropped because A is the family requested. B's drop is the only event left, so the held failure shows then.
  func test_aHeldFailureShowsWhenTheLastFetchRunningIsDroppedForAnotherFamily() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[2] = CancellationError()
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let toB = await startLoad(store, "family-b", gate: gates[1])
    let a2 = await startLoad(store, "family-a", gate: gates[2])

    await finish(gates[0], a1)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: false, canWrite: false), "A1 held")
    await finish(gates[2], a2)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: false, canWrite: false), "B running")
    await finish(gates[1], toB)

    XCTAssertEqual(
      shown(store), Shown(loading: false, error: true, loaded: true, canWrite: false),
      "A requested, nothing running, A's only real answer was a failure: a silent blank with no retry prompt"
    )
    XCTAssertNil(store.subscription, "B's plan must never show under A")
  }

  /// A2 succeeds and A3 fails (held behind A4); A4 is cancelled; the stale A1 lands last and is dropped by the epoch
  /// guard. A3 is the newest real answer, so it settles then rather than lingering to surface on a later load.
  func test_aHeldFailureShowsWhenTheLastFetchRunningIsDroppedAsStale() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[2] = URLError(.timedOut)
    mock.errorsByCallIndex[3] = CancellationError()
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let a2 = await startLoad(store, "family-a", gate: gates[1])
    let a3 = await startLoad(store, "family-a", gate: gates[2])
    let a4 = await startLoad(store, "family-a", gate: gates[3])

    await finish(gates[1], a2)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: true, canWrite: true), "A2 applied")
    await finish(gates[2], a3)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: true, canWrite: true), "A3 held")
    await finish(gates[3], a4)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: true, canWrite: true), "A1 running")
    await finish(gates[0], a1)

    XCTAssertEqual(
      shown(store), Shown(loading: false, error: true, loaded: true, canWrite: false),
      "the newest answer failed and nothing is left running: it is the final word"
    )
  }

  /// A1 fails and is held, A2 succeeds, then A3 is cancelled: A1 is older than the success on screen, so it must
  /// never revoke the paying family's write access.
  func test_aHeldFailureNeverRevokesAFamilyThatALaterLoadSucceededFor() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[2] = CancellationError()
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let a2 = await startLoad(store, "family-a", gate: gates[1])
    let a3 = await startLoad(store, "family-a", gate: gates[2])

    await finish(gates[0], a1)
    await finish(gates[1], a2)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: true, canWrite: true), "A2 applied")
    await finish(gates[2], a3)

    XCTAssertEqual(
      shown(store), Shown(loading: false, error: false, loaded: true, canWrite: true),
      "an older failure revoked a paying family after a newer success"
    )
  }

  /// A failure held before sign-out belongs to the signed-out session: the next session's cancelled load must not
  /// surface it, nor mark that session loaded from a fetch made before sign-out.
  func test_aHeldFailureDoesNotSurviveSignOut() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[2] = CancellationError()
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let a2 = await startLoad(store, "family-a", gate: gates[1])
    await finish(gates[0], a1)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: false, canWrite: false), "A1 held")

    store.reset()
    let fresh = await startLoad(store, "family-a", gate: gates[2])
    await finish(gates[2], fresh)
    XCTAssertEqual(
      shown(store), Shown(loading: false, error: false, loaded: false, canWrite: false),
      "the signed-out session's held failure surfaced in the new session"
    )
    await finish(gates[1], a2)

    XCTAssertEqual(shown(store), Shown(loading: false, error: false, loaded: false, canWrite: false))
  }

  /// A no-family answer is newer than the failure held before it, so it supersedes it like any newer answer does.
  /// Asking for A again and having that load cancelled as the last fetch running must not bring the old failure
  /// back: the end state is the same unloaded one a lone cancelled load leaves, not an error for a failure from
  /// before the no-family answer.
  func test_aNoFamilyAnswerDiscardsAnEarlierHeldFailure() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    mock.errorsByCallIndex[1] = CancellationError()
    mock.errorsByCallIndex[2] = CancellationError()
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let a2 = await startLoad(store, "family-a", gate: gates[1])
    await finish(gates[0], a1)
    await store.load(familyUnitId: nil)
    XCTAssertEqual(shown(store), Shown(loading: false, error: false, loaded: true, canWrite: false), "no family")
    XCTAssertEqual(store.planLabel, PlanLabel.noFamily)
    let a3 = await startLoad(store, "family-a", gate: gates[2])

    await finish(gates[1], a2)
    XCTAssertEqual(shown(store), Shown(loading: true, error: false, loaded: false, canWrite: false), "A3 running")
    await finish(gates[2], a3)

    XCTAssertEqual(
      shown(store), Shown(loading: false, error: false, loaded: false, canWrite: false),
      "a failure from before the no-family answer surfaced"
    )
  }

  /// A held failure for A that is settled while B is the family requested is for a family nobody is looking at:
  /// it is discarded then, and does not come back when A is requested again and that load is cancelled.
  func test_aHeldFailureDiscardedWhileAnotherFamilyIsRequestedDoesNotReturnForTheOriginal() async {
    let (store, mock) = makeStore()
    let gates = [AsyncGate(), AsyncGate(), AsyncGate(), AsyncGate()]
    mock.gateEachCall(gates)
    mock.errorsByCallIndex[0] = URLError(.timedOut)
    for index in 1...3 { mock.errorsByCallIndex[index] = CancellationError() }
    let a1 = await startLoad(store, "family-a", gate: gates[0])
    let a2 = await startLoad(store, "family-a", gate: gates[1])
    await finish(gates[0], a1)
    let toB = await startLoad(store, "family-b", gate: gates[2])
    await finish(gates[1], a2)
    await finish(gates[2], toB)
    XCTAssertEqual(
      shown(store), Shown(loading: false, error: false, loaded: false, canWrite: false),
      "family A's held failure surfaced for B"
    )

    let backToA = await startLoad(store, "family-a", gate: gates[3])
    await finish(gates[3], backToA)

    XCTAssertEqual(
      shown(store), Shown(loading: false, error: false, loaded: false, canWrite: false),
      "a held failure discarded while B was requested came back for A"
    )
  }
}
