import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PaywallViewModelTests: XCTestCase {
  nonisolated deinit {}

  private let uid = "3f2b8c1e-9a4d-4e6f-8b1a-5c7d9e0f1a2b"
  private let family = "fam-1"
  /// What the auth layer reports right now; a test changes it to simulate an account switch.
  private var signedInUserId: String?
  private var signedInRole: UserRole? = .parent

  private struct Rig {
    let model: PaywallViewModel
    let purchases: FakePurchases
    let entitlements: MockEntitlementService
    let store: EntitlementStore
    let flagStore: FeatureFlagStore
    let flagService: MockFeatureFlagService
    let sleeps: SleepLog
  }

  @MainActor
  final class SleepLog {
    var count = 0
    var onSleep: (() -> Void)?
  }

  private func subscription(_ status: SubscriptionStatus) -> FamilySubscription {
    FamilySubscription(
      familyUnitId: "fam-1", status: status, source: "x",
      trialEndsAt: Date().addingTimeInterval(86_400), currentPeriodEnd: nil
    )
  }

  private func rig(
    status: SubscriptionStatus = .trialing,
    disabled: [String] = [],
    pollAttempts: Int = 3,
    configure: (FakePurchases) -> Void = { _ in }
  ) async -> Rig {
    let purchases = FakePurchases()
    purchases.packages = FakePurchases.launchOffering
    configure(purchases)
    signedInUserId = uid
    signedInRole = .parent
    let entitlements = MockEntitlementService()
    entitlements.subscription = subscription(status)
    let store = EntitlementStore(service: entitlements)
    await store.load(familyUnitId: family)
    let flagService = MockFeatureFlagService()
    flagService.disabledKeys = disabled
    let flags = FeatureFlagStore(service: flagService, defaults: UserDefaults(suiteName: "PaywallVM-\(UUID())")!)
    await flags.refresh()
    let session = BillingSession(purchases: purchases, role: { [unowned self] in signedInRole })
    let sleeps = SleepLog()
    let model = PaywallViewModel(
      session: session, entitlements: store, flags: flags,
      userId: { [unowned self] in signedInUserId },
      role: { [unowned self] in signedInRole },
      familyUnitId: { [family] in family },
      pollAttempts: pollAttempts, pollInterval: .zero,
      sleep: { _ in
        sleeps.count += 1
        sleeps.onSleep?()
      }
    )
    return Rig(
      model: model, purchases: purchases, entitlements: entitlements, store: store,
      flagStore: flags, flagService: flagService, sleeps: sleeps
    )
  }

  // MARK: Who sees it

  func test_foundingFamilyNeverLoadsOrBuys() async {
    let rig = await rig(status: .founding)
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .unavailable)
    XCTAssertEqual(rig.purchases.availablePackagesCount, 0)
    XCTAssertTrue(rig.purchases.logInCalls.isEmpty)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  func test_killSwitchStopsLoadAndPurchase() async {
    let rig = await rig(disabled: ["paywall"])
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .unavailable)
    XCTAssertEqual(rig.purchases.availablePackagesCount, 0)
    await rig.model.purchase()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
  }

  func test_killSwitchFlippedAfterLoadingStopsPurchaseAndRestore() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertTrue(rig.model.canPurchase)
    rig.flagService.disabledKeys = ["paywall"]
    await rig.flagStore.refresh()
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  func test_aFamilyThatBecomesFoundingMidSessionCannotBuyOrRestore() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertTrue(rig.model.canPurchase)
    rig.entitlements.subscription = subscription(.founding)
    await rig.store.load(familyUnitId: family)
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  // MARK: Parents only

  func test_athleteCannotLoadBuyOrRestore() async {
    let rig = await rig()
    signedInRole = .player
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .unavailable)
    XCTAssertEqual(rig.purchases.availablePackagesCount, 0)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  func test_roleChangingToAthleteAfterLoadingStopsPurchaseAndRestore() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertTrue(rig.model.canPurchase)
    signedInRole = .player
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  func test_parentIsUnaffected() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .ready)
    XCTAssertTrue(rig.model.canPurchase)
  }

  // MARK: No SDK key

  func test_withoutAnSDKKeyNothingLoadsOrSells() async {
    let rig = await rig { $0.isConfigured = false }
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .unavailable)
    XCTAssertFalse(rig.model.isAvailable)
    XCTAssertEqual(rig.purchases.availablePackagesCount, 0)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  // MARK: Loading and choosing

  func test_showsTheOfferingsTiersSmallestFirst_forTheChosenPeriod() async {
    let rig = await rig { $0.packages = FakePurchases.launchOffering.reversed() }
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .ready)
    XCTAssertEqual(rig.model.tiers.map(\.product.id), ["trc_players_1_annual", "trc_players_2_annual"])
    rig.model.selectPeriod(.monthly)
    XCTAssertEqual(rig.model.tiers.map(\.product.id), ["trc_players_1_monthly", "trc_players_2_monthly"])
  }

  func test_pricesComeFromTheStoreNotFromTheApp() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertEqual(rig.model.tiers.map(\.priceText), ["STORE-trc_players_1_annual", "STORE-trc_players_2_annual"])
  }

  func test_aFutureTierAppearsFromTheOfferingAlone() async {
    let rig = await rig { $0.packages += [FakePurchases.package("trc_players_3_annual")] }
    await rig.model.load()
    XCTAssertEqual(rig.model.tiers.map(\.product.seats), [1, 2, 3])
  }

  func test_switchingPeriodKeepsTheChosenTier() async {
    let rig = await rig()
    await rig.model.load()
    rig.model.selectedPackageId = "pkg-trc_players_2_annual"
    rig.model.selectPeriod(.monthly)
    XCTAssertEqual(rig.model.selectedPackage?.product.id, "trc_players_2_monthly")
  }

  func test_theCurrentPlanIsNotSelectableAndSelectionSkipsIt() async {
    let rig = await rig { $0.currentProduct = "trc_players_1_annual" }
    await rig.model.load()
    XCTAssertEqual(rig.model.selectedPackage?.product.id, "trc_players_2_annual")
    rig.model.selectedPackageId = "pkg-trc_players_1_annual"
    XCTAssertNil(rig.model.selectedPackage)
    XCTAssertFalse(rig.model.canPurchase)
  }

  func test_emptyOrFailedOfferingIsUnavailable_notBlank() async {
    let empty = await rig { $0.packages = [] }
    await empty.model.load()
    XCTAssertEqual(empty.model.phase, .unavailable)
    let failing = await rig { $0.packagesError = FakePurchasesFailure() }
    await failing.model.load()
    XCTAssertEqual(failing.model.phase, .unavailable)
  }

  func test_loadingStateIsTheInitialState() async {
    let rig = await rig()
    XCTAssertEqual(rig.model.phase, .loading)
  }

  // MARK: Identity

  func test_noPurchaseUntilTheLoginFinishes() async {
    let rig = await rig { $0.logInError = FakePurchasesFailure() }
    await rig.model.load()
    XCTAssertEqual(rig.model.phase, .unavailable)
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    await rig.model.restore()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
    XCTAssertEqual(rig.purchases.restoreCount, 0)
  }

  func test_anAccountSwitchAfterLoadingLocksPurchasesUntilTheNewLoginFinishes() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertTrue(rig.model.canPurchase)
    signedInUserId = "bbbbbbbb-0000-0000-0000-000000000002"
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    XCTAssertTrue(rig.purchases.purchasedPackageIds.isEmpty)
  }

  func test_logsInWithTheLowercasedAuthUidBeforeLoadingPlans() async {
    let rig = await rig()
    await rig.model.load()
    XCTAssertEqual(rig.purchases.logInCalls, [uid])
  }

  // MARK: Purchase

  func test_purchaseWaitsForTheServerToShowThePlan() async {
    let rig = await rig(pollAttempts: 5)
    await rig.model.load()
    rig.sleeps.onSleep = {
      if rig.sleeps.count == 2 { rig.entitlements.subscription = self.subscription(.active) }
    }
    await rig.model.purchase()
    XCTAssertEqual(rig.purchases.purchasedPackageIds, ["pkg-trc_players_1_annual"])
    XCTAssertTrue(rig.model.didActivate)
    XCTAssertNil(rig.model.notice)
    XCTAssertEqual(rig.sleeps.count, 2)
    XCTAssertNil(rig.model.busy)
  }

  func test_purchaseTheServerNeverConfirmsEndsInSettingUp_notSuccess() async {
    let rig = await rig(pollAttempts: 3)
    await rig.model.load()
    await rig.model.purchase()
    XCTAssertFalse(rig.model.didActivate)
    XCTAssertEqual(rig.model.notice, .settingUp)
    XCTAssertEqual(rig.entitlements.requestedFamilyIds.count, 1 + 3)
    XCTAssertEqual(rig.sleeps.count, 2)
  }

  func test_cancelledPurchaseIsQuiet() async {
    let rig = await rig { $0.purchaseOutcome = .cancelled }
    await rig.model.load()
    await rig.model.purchase()
    XCTAssertNil(rig.model.notice)
    XCTAssertFalse(rig.model.didActivate)
    XCTAssertEqual(rig.entitlements.requestedFamilyIds.count, 1)
    XCTAssertNil(rig.model.busy)
  }

  func test_failedPurchaseShowsOurCopy_neverTheSDKError() async {
    let rig = await rig { $0.purchaseError = FakePurchasesFailure() }
    await rig.model.load()
    await rig.model.purchase()
    XCTAssertEqual(rig.model.notice, .purchaseFailed)
    XCTAssertFalse(rig.model.notice?.message.contains("RC-INTERNAL") ?? true)
    XCTAssertFalse(rig.model.didActivate)
    XCTAssertNil(rig.model.busy)
  }

  func test_aSecondTapWhileBuyingDoesNotBuyTwice() async {
    let gate = AsyncGate()
    let rig = await rig { $0.purchaseGate = { await gate.wait() } }
    await rig.model.load()
    let first = Task { await rig.model.purchase() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    XCTAssertEqual(rig.model.busy, .purchasing)
    XCTAssertFalse(rig.model.canPurchase)
    await rig.model.purchase()
    gate.open()
    await first.value
    XCTAssertEqual(rig.purchases.purchasedPackageIds.count, 1)
  }

  // MARK: Restore

  func test_restoreWithNothingToRestoreSaysSo() async {
    let rig = await rig()
    await rig.model.load()
    await rig.model.restore()
    XCTAssertEqual(rig.purchases.restoreCount, 1)
    XCTAssertEqual(rig.model.notice, .nothingToRestore)
    XCTAssertFalse(rig.model.didActivate)
  }

  func test_restoreOfAnOwnedPlanWaitsForTheServer() async {
    let rig = await rig { $0.productAfterRestore = "trc_players_1_annual" }
    await rig.model.load()
    rig.sleeps.onSleep = { rig.entitlements.subscription = self.subscription(.active) }
    await rig.model.restore()
    XCTAssertTrue(rig.model.didActivate)
    XCTAssertNil(rig.model.notice)
  }

  func test_failedRestoreShowsOurCopy() async {
    let rig = await rig { $0.restoreError = FakePurchasesFailure() }
    await rig.model.load()
    await rig.model.restore()
    XCTAssertEqual(rig.model.notice, .restoreFailed)
    XCTAssertFalse(rig.model.notice?.message.contains("RC-INTERNAL") ?? true)
  }
}
