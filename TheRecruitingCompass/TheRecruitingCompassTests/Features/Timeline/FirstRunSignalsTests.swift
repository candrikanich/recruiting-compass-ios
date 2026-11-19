import XCTest
@testable import TheRecruitingCompass

final class FirstRunSignalsTests: XCTestCase {
  nonisolated deinit {}

  private func signals(coaches: Int, conversations: Int) -> FirstRunSignals {
    FirstRunSignals(coachCount: coaches, conversationCount: conversations, favoriteSchoolName: nil)
  }

  func testScoreVisible_needsBothACoachAndAConversation() {
    XCTAssertFalse(signals(coaches: 0, conversations: 0).isStatusScoreVisible)
    XCTAssertFalse(signals(coaches: 1, conversations: 0).isStatusScoreVisible)
    XCTAssertFalse(signals(coaches: 0, conversations: 1).isStatusScoreVisible)
    XCTAssertTrue(signals(coaches: 1, conversations: 1).isStatusScoreVisible)
    XCTAssertTrue(signals(coaches: 7, conversations: 30).isStatusScoreVisible)
  }
}
