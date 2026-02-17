import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class DeadlineUrgencyTests: XCTestCase {

  // MARK: - color Tests

  func testColor_Overdue_ReturnsErrorRed() {
    XCTAssertEqual(DeadlineUrgency.overdue.color, .errorRed)
  }

  func testColor_Critical_ReturnsErrorRed() {
    XCTAssertEqual(DeadlineUrgency.critical.color, .errorRed)
  }

  func testColor_Urgent_ReturnsAmber() {
    XCTAssertEqual(DeadlineUrgency.urgent.color, .amberGold)
  }

  func testColor_Normal_ReturnsSecondary() {
    XCTAssertEqual(DeadlineUrgency.normal.color, .secondary)
  }

  func testColor_None_ReturnsSecondary() {
    XCTAssertEqual(DeadlineUrgency.none.color, .secondary)
  }

  // MARK: - label Tests

  func testLabel_Overdue() {
    XCTAssertEqual(DeadlineUrgency.overdue.label, "Overdue")
  }

  func testLabel_Critical() {
    XCTAssertEqual(DeadlineUrgency.critical.label, "Deadline Soon")
  }

  func testLabel_Urgent() {
    XCTAssertEqual(DeadlineUrgency.urgent.label, "Upcoming")
  }

  func testLabel_Normal_Nil() {
    XCTAssertNil(DeadlineUrgency.normal.label)
  }

  func testLabel_None_Nil() {
    XCTAssertNil(DeadlineUrgency.none.label)
  }
}
