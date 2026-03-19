import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class DeadlineUrgencyTasksTests: XCTestCase {
  nonisolated deinit {}

  var calendar: Calendar { Calendar.current }

  func testFrom_NilDeadline_ReturnsNone() {
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: nil), .none)
  }

  func testFrom_Overdue_ReturnsCritical() {
    let ref = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: ref)!
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: yesterday, reference: ref), .critical)
  }

  func testFrom_ZeroDays_ReturnsUrgent() {
    let ref = calendar.startOfDay(for: Date())
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: ref, reference: ref), .urgent)
  }

  func testFrom_SevenDays_ReturnsUrgent() {
    let ref = calendar.startOfDay(for: Date())
    let in7 = calendar.date(byAdding: .day, value: 7, to: ref)!
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: in7, reference: ref), .urgent)
  }

  func testFrom_EightDays_ReturnsUpcoming() {
    let ref = calendar.startOfDay(for: Date())
    let in8 = calendar.date(byAdding: .day, value: 8, to: ref)!
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: in8, reference: ref), .upcoming)
  }

  func testFrom_FourteenDays_ReturnsUpcoming() {
    let ref = calendar.startOfDay(for: Date())
    let in14 = calendar.date(byAdding: .day, value: 14, to: ref)!
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: in14, reference: ref), .upcoming)
  }

  func testFrom_FifteenDays_ReturnsFuture() {
    let ref = calendar.startOfDay(for: Date())
    let in15 = calendar.date(byAdding: .day, value: 15, to: ref)!
    XCTAssertEqual(TaskDeadlineUrgency.from(deadline: in15, reference: ref), .future)
  }

  func testLabel_Critical() {
    XCTAssertEqual(TaskDeadlineUrgency.critical.label, "Overdue / Due Soon")
  }

  func testLabel_Urgent() {
    XCTAssertEqual(TaskDeadlineUrgency.urgent.label, "Due This Week")
  }

  func testLabel_Upcoming() {
    XCTAssertEqual(TaskDeadlineUrgency.upcoming.label, "Due In 2 Weeks")
  }

  func testLabel_NoneAndFuture_Nil() {
    XCTAssertNil(TaskDeadlineUrgency.none.label)
    XCTAssertNil(TaskDeadlineUrgency.future.label)
  }
}
