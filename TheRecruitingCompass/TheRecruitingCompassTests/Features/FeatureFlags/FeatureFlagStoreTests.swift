import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FeatureFlagStoreTests: XCTestCase {
  nonisolated deinit {}

  private struct Offline: Error {}

  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: "FeatureFlagStoreTests-\(UUID().uuidString)")
  }

  override func tearDown() {
    defaults = nil
    super.tearDown()
  }

  private func makeStore(disabled: [String] = []) -> (FeatureFlagStore, MockFeatureFlagService) {
    let service = MockFeatureFlagService()
    service.disabledKeys = disabled
    return (FeatureFlagStore(service: service, defaults: defaults), service)
  }

  func test_coldLaunch_honoursPersistedDisabledSet_beforeFirstRefresh() async {
    let (first, _) = makeStore(disabled: ["guardian_claim", "athlete_messages"])
    await first.refresh()

    let (relaunched, _) = makeStore()
    XCTAssertFalse(relaunched.isEnabled(.guardianClaim))
    XCTAssertFalse(relaunched.isEnabled(.athleteMessages))
    XCTAssertTrue(relaunched.isEnabled(.familyInvites))
  }

  func test_coldLaunch_withNothingPersisted_failsOpen() {
    let (store, _) = makeStore()
    FeatureKey.allCases.forEach { XCTAssertTrue(store.isEnabled($0)) }
  }

  func test_persistedSet_isReplacedWhenFeatureTurnedBackOn() async {
    let (first, service) = makeStore(disabled: ["guardian_claim"])
    await first.refresh()
    service.disabledKeys = []
    await first.refresh()

    let (relaunched, _) = makeStore()
    XCTAssertTrue(relaunched.isEnabled(.guardianClaim))
  }

  func test_failedRefresh_keepsPersistedSet() async {
    let (first, _) = makeStore(disabled: ["guardian_claim"])
    await first.refresh()

    let (relaunched, service) = makeStore()
    service.error = Offline()
    await relaunched.refresh()
    XCTAssertFalse(relaunched.isEnabled(.guardianClaim))
  }

  func test_waitForInitialState_returnsAfterFirstRefresh_withFreshServerAnswer() async {
    let (store, _) = makeStore(disabled: ["guardian_claim"])
    XCTAssertFalse(store.hasResolvedInitialState)
    let waiter = Task { await store.waitForInitialState(timeout: .seconds(5)) }
    await store.refresh()
    await waiter.value
    XCTAssertTrue(store.hasResolvedInitialState)
    XCTAssertFalse(store.isEnabled(.guardianClaim))
  }

  func test_waitForInitialState_failsOpenAfterTimeout_whenNoRefreshArrives() async {
    let (store, _) = makeStore()
    let started = ContinuousClock.now
    await store.waitForInitialState(timeout: .milliseconds(100))
    XCTAssertLessThan(ContinuousClock.now - started, .seconds(2))
    XCTAssertFalse(store.hasResolvedInitialState)
    FeatureKey.allCases.forEach { XCTAssertTrue(store.isEnabled($0)) }
  }

  func test_supersededRefresh_doesNotResolveInitialState_untilLatestCompletes() async {
    let gated = GatedFlagService()
    let store = FeatureFlagStore(service: gated, defaults: defaults)
    let first = Task { await store.refresh() }
    await gated.waitForCalls(1)
    let second = Task { await store.refresh() }
    await gated.waitForCalls(2)

    await gated.release(call: 0, keys: [])
    await first.value
    XCTAssertFalse(store.hasResolvedInitialState)

    await gated.release(call: 1, keys: ["guardian_claim"])
    await second.value
    XCTAssertTrue(store.hasResolvedInitialState)
    XCTAssertFalse(store.isEnabled(.guardianClaim))
  }

  func test_waitForInitialState_resolvesEvenWhenRefreshFails() async {
    let (store, service) = makeStore()
    service.error = Offline()
    await store.refresh()
    XCTAssertTrue(store.hasResolvedInitialState)
  }

  func test_beforeAnyRefresh_everythingIsOn() {
    let (store, _) = makeStore(disabled: ["inbound_drafts"])
    FeatureKey.allCases.forEach { XCTAssertTrue(store.isEnabled($0)) }
  }

  func test_emptyList_everythingIsOn() async {
    let (store, _) = makeStore()
    await store.refresh()
    FeatureKey.allCases.forEach { XCTAssertTrue(store.isEnabled($0)) }
  }

  func test_listedKey_isOff_othersStayOn() async {
    let (store, _) = makeStore(disabled: ["guardian_claim"])
    await store.refresh()
    XCTAssertFalse(store.isEnabled(.guardianClaim))
    XCTAssertTrue(store.isEnabled(.inboundDrafts))
    XCTAssertTrue(store.isEnabled(.familyInvites))
    XCTAssertTrue(store.isEnabled(.athleteMessages))
  }

  func test_fetchThrows_everythingIsOn() async {
    let (store, service) = makeStore()
    service.error = Offline()
    await store.refresh()
    FeatureKey.allCases.forEach { XCTAssertTrue(store.isEnabled($0)) }
  }

  func test_unknownKey_isIgnored() async {
    let (store, _) = makeStore(disabled: ["some_future_feature", "family_invites"])
    await store.refresh()
    XCTAssertFalse(store.isEnabled(.familyInvites))
    XCTAssertTrue(store.isEnabled(.inboundDrafts))
  }

  func test_keyRemovedFromList_turnsBackOn() async {
    let (store, service) = makeStore(disabled: ["athlete_messages"])
    await store.refresh()
    XCTAssertFalse(store.isEnabled(.athleteMessages))
    service.disabledKeys = []
    await store.refresh()
    XCTAssertTrue(store.isEnabled(.athleteMessages))
  }

  func test_failedRefresh_keepsLastKnownState() async {
    let (store, service) = makeStore(disabled: ["athlete_messages"])
    await store.refresh()
    service.error = Offline()
    await store.refresh()
    XCTAssertFalse(store.isEnabled(.athleteMessages))
  }

  func test_keyRawValuesArePermanent() {
    XCTAssertEqual(
      Set(FeatureKey.allCases.map(\.rawValue)),
      ["inbound_drafts", "guardian_claim", "family_invites", "athlete_messages"]
    )
  }
}

/// Lets a test decide when each in-flight fetch returns.
private actor GatedFlagService: FeatureFlagFetching {
  private var continuations: [CheckedContinuation<[String], Never>] = []

  func fetchDisabledFeatureKeys() async throws -> [String] {
    await withCheckedContinuation { continuations.append($0) }
  }

  func waitForCalls(_ count: Int) async {
    while continuations.count < count { try? await Task.sleep(for: .milliseconds(10)) }
  }

  func release(call index: Int, keys: [String]) {
    continuations[index].resume(returning: keys)
  }
}
