import XCTest
@testable import TheRecruitingCompass

@MainActor
final class NotificationDestinationGateTests: XCTestCase {
  nonisolated deinit {}

  private func store(disabled: [String]) async -> FeatureFlagStore {
    let service = MockFeatureFlagService()
    service.disabledKeys = disabled
    let store = FeatureFlagStore(service: service)
    await store.refresh()
    return store
  }

  func test_inboundDraftsList_isDropped_whenFeatureDisabled() async {
    let flags = await store(disabled: ["inbound_drafts"])
    XCTAssertNil(NotificationDestination.inboundDraftsList.gated(by: flags))
  }

  func test_inboundDraftsList_passesThrough_whenEnabled() async {
    let flags = await store(disabled: [])
    XCTAssertEqual(NotificationDestination.inboundDraftsList.gated(by: flags), .inboundDraftsList)
  }

  func test_inboundDraftsList_passesThrough_withoutStore() {
    XCTAssertEqual(NotificationDestination.inboundDraftsList.gated(by: nil), .inboundDraftsList)
  }

  func test_otherDestinations_unaffectedByInboundSwitch() async {
    let flags = await store(disabled: ["inbound_drafts"])
    XCTAssertEqual(NotificationDestination.coachDetail(id: "1").gated(by: flags), .coachDetail(id: "1"))
  }
}
