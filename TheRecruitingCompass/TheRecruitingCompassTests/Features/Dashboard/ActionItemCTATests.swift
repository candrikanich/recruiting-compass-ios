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

  func test_addVideoMapsToAddVideoWithLabel() {
    let cta = ActionItemCTA(actionType: "add_video")
    XCTAssertEqual(cta, .addVideo)
    XCTAssertEqual(cta.label, String(localized: "Add Video"))
  }

  func test_updateVideoMapsToUpdateVideoWithLabel() {
    let cta = ActionItemCTA(actionType: "update_video")
    XCTAssertEqual(cta, .updateVideo)
    XCTAssertEqual(cta.label, String(localized: "Update Video"))
  }

  func test_unknownAndNilMapToNoneWithNilLabel() {
    XCTAssertEqual(ActionItemCTA(actionType: "wat"), .none)
    XCTAssertEqual(ActionItemCTA(actionType: nil), .none)
    XCTAssertNil(ActionItemCTA(actionType: nil).label)
  }
}
