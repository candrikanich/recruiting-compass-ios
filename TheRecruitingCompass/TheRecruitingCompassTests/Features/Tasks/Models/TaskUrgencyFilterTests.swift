import XCTest
@testable import TheRecruitingCompass

final class TaskUrgencyFilterTests: XCTestCase {

  func testMatches_All_MatchesAny() {
    XCTAssertTrue(TaskUrgencyFilter.all.matches(.critical))
    XCTAssertTrue(TaskUrgencyFilter.all.matches(.urgent))
    XCTAssertTrue(TaskUrgencyFilter.all.matches(.upcoming))
    XCTAssertTrue(TaskUrgencyFilter.all.matches(.future))
    XCTAssertTrue(TaskUrgencyFilter.all.matches(.none))
  }

  func testMatches_Critical() {
    XCTAssertTrue(TaskUrgencyFilter.critical.matches(.critical))
    XCTAssertFalse(TaskUrgencyFilter.critical.matches(.urgent))
  }

  func testMatches_Urgent() {
    XCTAssertTrue(TaskUrgencyFilter.urgent.matches(.urgent))
    XCTAssertFalse(TaskUrgencyFilter.urgent.matches(.none))
  }
}
