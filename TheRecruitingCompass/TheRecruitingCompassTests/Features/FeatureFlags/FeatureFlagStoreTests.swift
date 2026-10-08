import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FeatureFlagStoreTests: XCTestCase {
  nonisolated deinit {}

  private struct Offline: Error {}

  private func makeStore(disabled: [String] = []) -> (FeatureFlagStore, MockFeatureFlagService) {
    let service = MockFeatureFlagService()
    service.disabledKeys = disabled
    return (FeatureFlagStore(service: service), service)
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
