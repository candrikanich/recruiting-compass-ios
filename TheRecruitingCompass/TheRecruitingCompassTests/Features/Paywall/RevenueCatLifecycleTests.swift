import XCTest
@testable import TheRecruitingCompass

/// Privacy contract (ios#541 round 5): starting the RevenueCat SDK contacts RevenueCat, so it must not start at
/// launch, for an athlete, for a build without a key or with the `paywall` kill switch on, and when it does start
/// it starts already identified as the signed-in parent, so no anonymous customer is ever created.
@MainActor
final class RevenueCatLifecycleTests: XCTestCase {
  nonisolated deinit {}

  private let parentA = "3F2B8C1E-9A4D-4E6F-8B1A-5C7D9E0F1A2B"
  private let parentB = "AAAAAAAA-0000-0000-0000-000000000002"
  private let key = "appl_test_key"

  private struct Rig {
    let sdk: RecordingLifecycle
    let session: BillingSession
  }

  private func rig(
    role: @escaping () -> UserRole? = { .parent },
    paywallEnabled: @escaping @MainActor () async -> Bool = { true },
    apiKey: String? = "appl_test_key"
  ) -> Rig {
    let sdk = RecordingLifecycle()
    let adapter = RevenueCatPurchases(apiKey: { apiKey }, lifecycle: sdk.lifecycle)
    return Rig(sdk: sdk, session: BillingSession(purchases: adapter, isPaywallEnabled: paywallEnabled, role: role))
  }

  // MARK: Never started

  func test_launchWithNoSignedInUserNeverStartsTheSDK() async {
    let rig = rig()
    await rig.session.sync(userId: nil)
    XCTAssertEqual(rig.sdk.events, [])
  }

  func test_anAthleteNeverStartsTheSDK_inAnyWayTheSessionReachesIt() async {
    for role in [UserRole.player, nil] {
      let rig = rig(role: { role })
      await rig.session.sync(userId: parentA)
      _ = await rig.session.ensureIdentified(as: parentA)
      _ = await rig.session.currentProductId(as: parentA)
      await rig.session.sync(userId: nil)
      XCTAssertEqual(rig.sdk.events, [], "\(String(describing: role))")
    }
  }

  func test_withTheKillSwitchOnAParentNeverStartsTheSDK() async {
    let rig = rig(paywallEnabled: { false })
    await rig.session.sync(userId: parentA)
    _ = await rig.session.ensureIdentified(as: parentA)
    XCTAssertEqual(rig.sdk.events, [])
    XCTAssertFalse(rig.session.isIdentified(as: parentA))
  }

  func test_withoutAnAPIKeyAParentNeverStartsTheSDK() async {
    let rig = rig(apiKey: nil)
    await rig.session.sync(userId: parentA)
    _ = await rig.session.ensureIdentified(as: parentA)
    XCTAssertEqual(rig.sdk.events, [])
    XCTAssertFalse(rig.session.purchases.hasAPIKey)
  }

  /// The cold-launch flag refresh can finish after the first sync; a switch the server has set must still win.
  func test_aKillSwitchThatResolvesAfterTheSyncStartedStillKeepsTheSDKStopped() async {
    let gate = AsyncGate()
    let rig = rig(paywallEnabled: {
      await gate.wait()
      return false
    })
    let pending = Task { await rig.session.sync(userId: parentA) }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    XCTAssertEqual(rig.sdk.events, [], "nothing may start while the kill switch is unknown")
    gate.open()
    await pending.value
    XCTAssertEqual(rig.sdk.events, [])
  }

  /// A parent who signs out while the kill switch is still resolving must not start the SDK as that parent.
  func test_aSignOutDuringTheKillSwitchWaitStopsTheSDKFromStartingAsTheLeftAccount() async {
    let gate = AsyncGate(blockedEntries: 1)
    let rig = rig(paywallEnabled: {
      await gate.wait()
      return true
    })
    let stale = Task { await rig.session.sync(userId: parentA) }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await rig.session.sync(userId: nil)
    gate.open()
    await stale.value
    XCTAssertEqual(rig.sdk.startCount, 0)
    XCTAssertFalse(rig.session.isIdentified(as: parentA))
  }

  func test_anAthleteNeverWaitsOnTheKillSwitch() async {
    var asked = 0
    let rig = rig(role: { .player }, paywallEnabled: {
      asked += 1
      return true
    })
    await rig.session.sync(userId: parentA)
    XCTAssertEqual(asked, 0)
  }

  // MARK: Started once, as the parent

  func test_aParentStartsTheSDKOnce_asThemselves_withTheLowercasedSupabaseId() async {
    let rig = rig()
    await rig.session.sync(userId: parentA)
    XCTAssertEqual(rig.sdk.events, [.start(apiKey: key, appUserId: parentA.lowercased())])
    XCTAssertTrue(rig.session.isIdentified(as: parentA))
  }

  func test_aRoleReloadForTheSameParentDoesNotStartTheSDKAgain() async {
    let rig = rig()
    await rig.session.sync(userId: parentA)
    await rig.session.sync(userId: parentA)
    XCTAssertEqual(rig.sdk.startCount, 1)
    XCTAssertTrue(rig.session.isIdentified(as: parentA))
  }

  // MARK: Switching accounts

  /// Logging in from one identified user to another switches customers; only an anonymous customer is merged, so
  /// parent A's purchases can never be attached to parent B.
  func test_parentAThenParentBSwitchesCustomers_withoutRestartingOrSigningOut() async {
    let rig = rig()
    await rig.session.sync(userId: parentA)
    await rig.session.sync(userId: parentB)
    XCTAssertEqual(rig.sdk.events, [
      .start(apiKey: key, appUserId: parentA.lowercased()),
      .logIn(parentB.lowercased())
    ])
    XCTAssertTrue(rig.session.isIdentified(as: parentB))
    XCTAssertFalse(rig.session.isIdentified(as: parentA))
  }

  func test_parentAThenSignOutThenParentB_detachesAAndLogsInB_neverRestarting() async {
    let rig = rig()
    await rig.session.sync(userId: parentA)
    await rig.session.sync(userId: nil)
    await rig.session.sync(userId: parentB)
    XCTAssertEqual(rig.sdk.events, [
      .start(apiKey: key, appUserId: parentA.lowercased()),
      .logOut,
      .logIn(parentB.lowercased())
    ])
  }

  func test_anAthleteAfterAParentLeavesNoCustomerAttached() async {
    var role: UserRole? = .parent
    let rig = rig(role: { role })
    await rig.session.sync(userId: parentA)
    role = .player
    await rig.session.sync(userId: parentB)
    XCTAssertEqual(rig.sdk.events, [.start(apiKey: key, appUserId: parentA.lowercased()), .logOut])
    XCTAssertNil(rig.session.identifiedUserId)
  }

  func test_aParentAfterAnAthleteStartsTheSDKForTheFirstTime_asTheParent() async {
    var role: UserRole? = .player
    let rig = rig(role: { role })
    await rig.session.sync(userId: parentB)
    XCTAssertEqual(rig.sdk.events, [])
    role = .parent
    await rig.session.sync(userId: parentA)
    XCTAssertEqual(rig.sdk.events, [.start(apiKey: key, appUserId: parentA.lowercased())])
  }

  // MARK: The adapter itself

  func test_anAdapterThatNeverStartedRefusesEverySDKCall() async {
    let sdk = RecordingLifecycle()
    let adapter = RevenueCatPurchases(apiKey: { nil }, lifecycle: sdk.lifecycle)
    let calls: [() async throws -> Void] = [
      { _ = try await adapter.availablePackages() },
      { _ = try await adapter.currentProductId() },
      { try await adapter.restorePurchases() },
      { try await adapter.presentManageSubscriptions() },
      { try await adapter.logIn(appUserId: "abc") }
    ]
    for call in calls {
      do {
        try await call()
        XCTFail("a stopped adapter must not reach the SDK")
      } catch {
        XCTAssertEqual(error as? PurchasesError, .notConfigured)
      }
    }
    XCTAssertEqual(sdk.events, [])
  }

  func test_signingOutAnAdapterThatNeverStartedDoesNothingAndDoesNotStartIt() async throws {
    let sdk = RecordingLifecycle()
    let adapter = RevenueCatPurchases(apiKey: { "appl_test_key" }, lifecycle: sdk.lifecycle)
    try await adapter.logOut()
    XCTAssertEqual(sdk.events, [])
  }

  func test_hasAPIKeyReportsTheKeyNotTheSDKState() {
    let sdk = RecordingLifecycle()
    XCTAssertTrue(RevenueCatPurchases(apiKey: { "appl_test_key" }, lifecycle: sdk.lifecycle).hasAPIKey)
    XCTAssertFalse(RevenueCatPurchases(apiKey: { nil }, lifecycle: sdk.lifecycle).hasAPIKey)
    XCTAssertFalse(sdk.isStarted, "having a key must not start the SDK")
  }
}
