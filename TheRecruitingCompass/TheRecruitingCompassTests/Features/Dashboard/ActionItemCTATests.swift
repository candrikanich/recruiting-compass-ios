import XCTest
@testable import TheRecruitingCompass

final class ActionItemCTATests: XCTestCase {
  func test_addSchool_mapsToAddSchoolWithLabel() {
    let cta = ActionItemCTA(actionType: "add_school")
    XCTAssertEqual(cta, .addSchool)
    XCTAssertEqual(cta.label, "Add School")
  }

  func test_logInteraction_mapsToLogInteractionWithLabel() {
    let cta = ActionItemCTA(actionType: "log_interaction")
    XCTAssertEqual(cta, .logInteraction)
    XCTAssertEqual(cta.label, "Log Interaction")
  }

  func test_videoAndUnknownAndNil_mapToNoneWithNilLabel() {
    XCTAssertEqual(ActionItemCTA(actionType: "add_video"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: "update_video"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: "something_new"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: nil), .none)
    XCTAssertNil(ActionItemCTA(actionType: nil).label)
  }
}
