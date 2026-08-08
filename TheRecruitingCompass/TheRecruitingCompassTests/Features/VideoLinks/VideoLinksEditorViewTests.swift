import XCTest
@testable import TheRecruitingCompass

@MainActor
final class VideoLinksEditorViewTests: XCTestCase {
  nonisolated deinit {}

  func test_readOnlyHidesAddButton() {
    let view = VideoLinksEditorView(athleteUserId: "u1", familyUnitId: "f1",
                                    isReadOnly: true, service: MockVideoLinksService())
    XCTAssertFalse(view.showsAddButton)
  }

  func test_playerShowsAddButton() {
    let view = VideoLinksEditorView(athleteUserId: "u1", familyUnitId: "f1",
                                    isReadOnly: false, service: MockVideoLinksService())
    XCTAssertTrue(view.showsAddButton)
  }
}
