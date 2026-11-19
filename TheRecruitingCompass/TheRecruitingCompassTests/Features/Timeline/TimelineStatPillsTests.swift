import XCTest
@testable import TheRecruitingCompass

final class TimelineStatPillsTests: XCTestCase {
  nonisolated deinit {}

  private func pills(status: TimelineStatPills.Status?) -> TimelineStatPills {
    TimelineStatPills(
      status: status, taskCompleted: 1, taskTotal: 2, milestonesCompleted: 1, milestonesTotal: 4
    )
  }

  func testNoStatus_hidesTheStatusCard() {
    XCTAssertEqual(pills(status: nil).visibleCards, [.tasks, .milestones])
  }

  func testStatus_showsTheStatusCardFirst() {
    XCTAssertEqual(pills(status: .init(score: 50, label: .onTrack)).visibleCards, [.status, .tasks, .milestones])
  }
}
