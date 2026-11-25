import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PaywallAccessTests: XCTestCase {
  nonisolated deinit {}

  private func subscription(_ status: SubscriptionStatus) -> FamilySubscription {
    FamilySubscription(
      familyUnitId: "fam-1", status: status, source: "x",
      trialEndsAt: Date().addingTimeInterval(86_400), currentPeriodEnd: nil
    )
  }

  private func flags(disabled: [String]) async -> FeatureFlagStore {
    let service = MockFeatureFlagService()
    service.disabledKeys = disabled
    let store = FeatureFlagStore(service: service, defaults: UserDefaults(suiteName: "PaywallAccess-\(UUID())")!)
    await store.refresh()
    return store
  }

  private func actions(
    _ status: SubscriptionStatus, _ flags: FeatureFlagStore?, holdsSubscription: Bool
  ) -> [PlanAction] {
    PaywallAccess.actions(
      subscription: subscription(status), flags: flags, role: .parent, isConfigured: true,
      holdsSubscription: holdsSubscription
    )
  }

  private func available(
    _ status: SubscriptionStatus, _ flags: FeatureFlagStore?,
    role: UserRole? = .parent, isConfigured: Bool = true
  ) -> Bool {
    PaywallAccess.isAvailable(subscription: subscription(status), flags: flags, role: role, isConfigured: isConfigured)
  }

  func test_foundingFamilyNeverSeesAPaywall() async {
    for killSwitch in [[], ["paywall"]] {
      let store = await flags(disabled: killSwitch)
      XCTAssertFalse(available(.founding, store))
      XCTAssertEqual(actions(.founding, store, holdsSubscription: true), [])
    }
    XCTAssertFalse(available(.founding, nil))
  }

  func test_complimentaryUnknownAndUnloadedPlansNeverSeeAPaywall() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.comp, .unknown] {
      XCTAssertFalse(available(status, store), "\(status)")
    }
    XCTAssertFalse(PaywallAccess.isAvailable(subscription: nil, flags: store, role: .parent, isConfigured: true))
    let actions = PaywallAccess.actions(
      subscription: nil, flags: store, role: .parent, isConfigured: true, holdsSubscription: true
    )
    XCTAssertEqual(actions, [])
  }

  func test_trialingAndReadOnlyFamiliesSeePlans() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.trialing, .readOnly] {
      XCTAssertTrue(available(status, store), "\(status)")
      XCTAssertEqual(actions(status, store, holdsSubscription: false), [.seePlans])
    }
  }

  func test_activePayerCanChangeAndManage_butACoveredMemberCannot() async {
    let store = await flags(disabled: [])
    XCTAssertEqual(actions(.active, store, holdsSubscription: true), [.changePlan, .manageSubscription])
    XCTAssertEqual(actions(.active, store, holdsSubscription: false), [])
  }

  func test_killSwitchHidesEveryPurchaseSurfaceForEveryStatus() async {
    let store = await flags(disabled: ["paywall"])
    for status in [SubscriptionStatus.trialing, .readOnly, .active, .founding, .comp, .unknown] {
      XCTAssertFalse(available(status, store), "\(status)")
      XCTAssertEqual(actions(status, store, holdsSubscription: true), [], "\(status)")
    }
  }

  func test_otherKillSwitchesDoNotHideThePaywall() async {
    let store = await flags(disabled: ["inbound_drafts", "athlete_messages"])
    XCTAssertTrue(available(.trialing, store))
  }

  func test_withoutAFlagStoreTheKillSwitchFailsOpenLikeEveryOtherKey() {
    XCTAssertTrue(available(.trialing, nil))
  }

  func test_paywallKeyIsTheServerContract() {
    XCTAssertEqual(FeatureKey.paywall.rawValue, "paywall")
  }

  func test_athleteNeverSeesAPurchaseSurface_whateverThePlan() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.trialing, .readOnly, .active, .founding, .comp, .unknown] {
      XCTAssertFalse(available(status, store, role: .player), "\(status)")
      let actions = PaywallAccess.actions(
        subscription: subscription(status), flags: store, role: .player, isConfigured: true, holdsSubscription: true
      )
      XCTAssertEqual(actions, [], "\(status)")
    }
  }

  func test_aMissingRoleIsNotAParent() async {
    let store = await flags(disabled: [])
    XCTAssertFalse(available(.trialing, store, role: nil))
  }

  func test_noSDKKeyHidesEveryPurchaseSurface() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.trialing, .readOnly, .active] {
      XCTAssertFalse(available(status, store, isConfigured: false), "\(status)")
      let actions = PaywallAccess.actions(
        subscription: subscription(status), flags: store, role: .parent, isConfigured: false, holdsSubscription: true
      )
      XCTAssertEqual(actions, [], "\(status)")
    }
  }

  func test_athleteWhoseFamilyNeedsAPlanIsToldToAskAParent() {
    XCTAssertTrue(PaywallAccess.showsAskAParentNote(subscription: subscription(.trialing), role: .player))
    XCTAssertTrue(PaywallAccess.showsAskAParentNote(subscription: subscription(.readOnly), role: .player))
    for status in [SubscriptionStatus.founding, .comp, .active, .unknown] {
      XCTAssertFalse(PaywallAccess.showsAskAParentNote(subscription: subscription(status), role: .player), "\(status)")
    }
    XCTAssertFalse(PaywallAccess.showsAskAParentNote(subscription: subscription(.trialing), role: .parent))
    XCTAssertFalse(PaywallAccess.showsAskAParentNote(subscription: nil, role: .player))
  }

  func test_askAParentCopyHasNoPriceOrPressure() {
    let copy = PaywallAccess.askAParentCopy.lowercased()
    XCTAssertEqual(PaywallAccess.askAParentCopy, "A parent can choose a plan for your family.")
    for word in ["$", "now", "hurry", "limited", "expire"] { XCTAssertFalse(copy.contains(word), word) }
  }
}
