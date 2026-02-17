import XCTest
@testable import TheRecruitingCompass

final class TaskStatusFilterTests: XCTestCase {

  func testMatches_All_MatchesAny() {
    XCTAssertTrue(TaskStatusFilter.all.matches(.notStarted))
    XCTAssertTrue(TaskStatusFilter.all.matches(.inProgress))
    XCTAssertTrue(TaskStatusFilter.all.matches(.completed))
  }

  func testMatches_NotStarted() {
    XCTAssertTrue(TaskStatusFilter.notStarted.matches(.notStarted))
    XCTAssertFalse(TaskStatusFilter.notStarted.matches(.completed))
  }

  func testMatches_Completed() {
    XCTAssertTrue(TaskStatusFilter.completed.matches(.completed))
    XCTAssertFalse(TaskStatusFilter.completed.matches(.inProgress))
  }
}
