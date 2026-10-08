import XCTest
@testable import TheRecruitingCompass

@MainActor
final class KillSwitchEntryPointTests: XCTestCase {
  nonisolated deinit {}

  private func store(disabled: [String]) async -> FeatureFlagStore {
    let service = MockFeatureFlagService()
    service.disabledKeys = disabled
    let defaults = UserDefaults(suiteName: "KillSwitchEntryPointTests-\(UUID().uuidString)")!
    let store = FeatureFlagStore(service: service, defaults: defaults)
    await store.refresh()
    return store
  }

  private func coach(id: String, email: String? = "coach@school.edu") -> Coach {
    Coach(
      id: id, firstName: "Pat", lastName: "Smith", email: email, phone: nil, position: "head",
      schoolId: "s1", twitterHandle: nil, instagramHandle: nil, notes: nil, lastContactDate: nil,
      createdAt: "2026-02-10T00:00:00Z", updatedAt: "2026-02-10T00:00:00Z"
    )
  }

  // MARK: School detail Quick Comm

  func test_schoolQuickComm_disabled_neverOpensDirectOrPicker() async {
    let flags = await store(disabled: ["athlete_messages"])
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [coach(id: "1")], flags: flags), .none)
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [coach(id: "1"), coach(id: "2")], flags: flags), .none)
  }

  func test_schoolQuickComm_enabled_keepsExistingBehaviour() async {
    let flags = await store(disabled: [])
    let one = coach(id: "1")
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [one], flags: flags), .direct(one))
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [one, coach(id: "2")], flags: flags), .pickCoach)
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [], flags: flags), .none)
  }

  func test_schoolQuickComm_withoutStore_failsOpen() {
    XCTAssertEqual(QuickCommEntry.resolve(coaches: [coach(id: "1"), coach(id: "2")], flags: nil), .pickCoach)
  }

  // MARK: Event coach card

  func test_eventCoachEmail_hiddenWhenAthleteMessagesDisabled() async {
    let flags = await store(disabled: ["athlete_messages"])
    XCTAssertFalse(EventCoachCard.showsEmailAction(for: coach(id: "1"), flags: flags))
  }

  func test_eventCoachEmail_shownWhenEnabled_andCoachHasEmail() async {
    let flags = await store(disabled: [])
    XCTAssertTrue(EventCoachCard.showsEmailAction(for: coach(id: "1"), flags: flags))
    XCTAssertFalse(EventCoachCard.showsEmailAction(for: coach(id: "1", email: nil), flags: flags))
    XCTAssertFalse(EventCoachCard.showsEmailAction(for: coach(id: "1", email: ""), flags: flags))
  }

  // MARK: Family Management forwarding card

  func test_forwardCard_draftsLinkHiddenWhenInboundDraftsDisabled() async {
    let off = await store(disabled: ["inbound_drafts"])
    let on = await store(disabled: [])
    XCTAssertFalse(ForwardCoachEmailsCard.showsDraftsLink(flags: off))
    XCTAssertTrue(ForwardCoachEmailsCard.showsDraftsLink(flags: on))
    XCTAssertTrue(ForwardCoachEmailsCard.showsDraftsLink(flags: nil))
  }
}
