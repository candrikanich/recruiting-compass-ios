import XCTest
@testable import TheRecruitingCompass

@MainActor
final class EntitlementStoreTests: XCTestCase {
  nonisolated deinit {}

  private func makeStore(_ sub: FamilySubscription?) -> (EntitlementStore, MockEntitlementService) {
    let mock = MockEntitlementService()
    mock.subscription = sub
    return (EntitlementStore(service: mock), mock)
  }

  private let founding = FamilySubscription(
    familyUnitId: "fam-1", status: .founding, source: "founding", trialEndsAt: nil, currentPeriodEnd: nil
  )

  func test_loadPopulatesSubscriptionAndDerivedState() async {
    let (store, mock) = makeStore(founding)
    XCTAssertFalse(store.hasLoaded)
    await store.load(familyUnitId: "fam-1")
    XCTAssertEqual(mock.requestedFamilyIds, ["fam-1"])
    XCTAssertEqual(store.subscription, founding)
    XCTAssertTrue(store.canWrite)
    XCTAssertEqual(store.planLabel, "Founding Family — free for life")
    XCTAssertNil(store.errorMessage)
    XCTAssertTrue(store.hasLoaded)
  }

  func test_nilFamilyClearsState() async {
    let (store, mock) = makeStore(founding)
    await store.load(familyUnitId: "fam-1")
    await store.load(familyUnitId: nil)
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    XCTAssertEqual(mock.requestedFamilyIds, ["fam-1"])
    XCTAssertTrue(store.hasLoaded)
  }

  func test_nilFamilySetsHasLoadedOnFirstCall() async {
    let (store, _) = makeStore(nil)
    XCTAssertFalse(store.hasLoaded)
    await store.load(familyUnitId: nil)
    XCTAssertTrue(store.hasLoaded)
  }

  func test_missingRowIsUnavailableNotError() async {
    let (store, _) = makeStore(nil)
    await store.load(familyUnitId: "fam-1")
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertEqual(store.planLabel, PlanLabel.unavailable)
    XCTAssertNil(store.errorMessage)
    XCTAssertTrue(store.hasLoaded)
  }

  func test_serviceErrorSetsMessageAndClears() async {
    let (store, mock) = makeStore(founding)
    await store.load(familyUnitId: "fam-1")
    mock.error = URLError(.notConnectedToInternet)
    await store.load(familyUnitId: "fam-1")
    XCTAssertNil(store.subscription)
    XCTAssertFalse(store.canWrite)
    XCTAssertNotNil(store.errorMessage)
    XCTAssertTrue(store.hasLoaded)
  }
}
