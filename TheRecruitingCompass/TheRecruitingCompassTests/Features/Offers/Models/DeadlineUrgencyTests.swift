import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class DeadlineUrgencyTests: XCTestCase {

  // MARK: - color Tests
  // Note: SwiftUI Color equality is unreliable in XCTest — compare via UIColor RGBA components.

  func testColor_Overdue_ReturnsErrorRed() {
    assertColorMatches(DeadlineUrgency.overdue.color, expected: .errorRed)
  }

  func testColor_Critical_ReturnsErrorRed() {
    assertColorMatches(DeadlineUrgency.critical.color, expected: .errorRed)
  }

  func testColor_Urgent_ReturnsAmber() {
    assertColorMatches(DeadlineUrgency.urgent.color, expected: .amberGold)
  }

  func testColor_OverdueAndCritical_SameColor() {
    assertColorMatches(DeadlineUrgency.overdue.color, expected: DeadlineUrgency.critical.color)
  }

  func testColor_NormalAndNone_SameColor() {
    assertColorMatches(DeadlineUrgency.normal.color, expected: DeadlineUrgency.none.color)
  }

  func testColor_Urgent_DifferentFromNormal() {
    let urgentKey = colorKey(UIColor(DeadlineUrgency.urgent.color))
    let normalKey = colorKey(UIColor(DeadlineUrgency.normal.color))
    XCTAssertNotEqual(urgentKey, normalKey, "Urgent and normal deadlines should have different colors")
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

  // MARK: - Helpers

  private func assertColorMatches(_ color: Color, expected: Color, tolerance: CGFloat = 0.01, file: StaticString = #file, line: UInt = #line) {
    let c1 = UIColor(color).cgColor.components ?? []
    let c2 = UIColor(expected).cgColor.components ?? []
    guard c1.count >= 3, c2.count >= 3 else {
      XCTFail("Could not extract RGB components", file: file, line: line)
      return
    }
    XCTAssertEqual(c1[0], c2[0], accuracy: tolerance, "Red mismatch", file: file, line: line)
    XCTAssertEqual(c1[1], c2[1], accuracy: tolerance, "Green mismatch", file: file, line: line)
    XCTAssertEqual(c1[2], c2[2], accuracy: tolerance, "Blue mismatch", file: file, line: line)
  }

  private func colorKey(_ color: UIColor) -> String {
    let c = color.cgColor.components ?? []
    guard c.count >= 3 else { return "unknown" }
    return String(format: "%.2f-%.2f-%.2f", c[0], c[1], c[2])
  }
}
