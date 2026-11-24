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
    PaywallAccess.actions(subscription: subscription(status), flags: flags, holdsSubscription: holdsSubscription)
  }

  func test_foundingFamilyNeverSeesAPaywall() async {
    for killSwitch in [[], ["paywall"]] {
      let store = await flags(disabled: killSwitch)
      XCTAssertFalse(PaywallAccess.isAvailable(subscription: subscription(.founding), flags: store))
      XCTAssertEqual(actions(.founding, store, holdsSubscription: true), [])
    }
    XCTAssertFalse(PaywallAccess.isAvailable(subscription: subscription(.founding), flags: nil))
  }

  func test_complimentaryUnknownAndUnloadedPlansNeverSeeAPaywall() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.comp, .unknown] {
      XCTAssertFalse(PaywallAccess.isAvailable(subscription: subscription(status), flags: store), "\(status)")
    }
    XCTAssertFalse(PaywallAccess.isAvailable(subscription: nil, flags: store))
    XCTAssertEqual(PaywallAccess.actions(subscription: nil, flags: store, holdsSubscription: true), [])
  }

  func test_trialingAndReadOnlyFamiliesSeePlans() async {
    let store = await flags(disabled: [])
    for status in [SubscriptionStatus.trialing, .readOnly] {
      XCTAssertTrue(PaywallAccess.isAvailable(subscription: subscription(status), flags: store), "\(status)")
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
      XCTAssertFalse(PaywallAccess.isAvailable(subscription: subscription(status), flags: store), "\(status)")
      XCTAssertEqual(actions(status, store, holdsSubscription: true), [], "\(status)")
    }
  }

  func test_otherKillSwitchesDoNotHideThePaywall() async {
    let store = await flags(disabled: ["inbound_drafts", "athlete_messages"])
    XCTAssertTrue(PaywallAccess.isAvailable(subscription: subscription(.trialing), flags: store))
  }

  func test_withoutAFlagStoreTheKillSwitchFailsOpenLikeEveryOtherKey() {
    XCTAssertTrue(PaywallAccess.isAvailable(subscription: subscription(.trialing), flags: nil))
  }

  func test_paywallKeyIsTheServerContract() {
    XCTAssertEqual(FeatureKey.paywall.rawValue, "paywall")
  }
}
