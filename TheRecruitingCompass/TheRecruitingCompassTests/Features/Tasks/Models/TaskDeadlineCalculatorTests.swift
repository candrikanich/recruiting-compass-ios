import XCTest
@testable import TheRecruitingCompass

final class TaskDeadlineCalculatorTests: XCTestCase {

  private var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }

  private func ymd(_ date: Date) -> (Int, Int, Int) {
    let c = utc.dateComponents([.year, .month, .day], from: date)
    return (c.year!, c.month!, c.day!)
  }

  func testNilInputs_returnNil() {
    XCTAssertNil(TaskDeadlineCalculator.deadlineDate(graduationYear: nil, offsetMonths: 6, calendar: utc))
    XCTAssertNil(TaskDeadlineCalculator.deadlineDate(graduationYear: 2027, offsetMonths: nil, calendar: utc))
  }

  // Anchor = June 1 of grad year, minus offset months, day pinned to 1st.
  func testSeniorOffset6_isDecemberOfSeniorFall() {
    let date = TaskDeadlineCalculator.deadlineDate(graduationYear: 2027, offsetMonths: 6, calendar: utc)
    XCTAssertNotNil(date)
    XCTAssertTrue(ymd(date!) == (2026, 12, 1), "expected 2026-12-01, got \(ymd(date!))")
  }

  func testFreshmanOffset42_isDecemberFourYearsBeforeGrad() {
    // June 2027 - 42 months = Dec 2023
    let date = TaskDeadlineCalculator.deadlineDate(graduationYear: 2027, offsetMonths: 42, calendar: utc)
    XCTAssertTrue(ymd(date!) == (2023, 12, 1), "expected 2023-12-01, got \(ymd(date!))")
  }

  func testGrade11Offset18_isDecemberOfJuniorFall() {
    // June 2027 - 18 months = Dec 2025
    let date = TaskDeadlineCalculator.deadlineDate(graduationYear: 2027, offsetMonths: 18, calendar: utc)
    XCTAssertTrue(ymd(date!) == (2025, 12, 1), "expected 2025-12-01, got \(ymd(date!))")
  }

  func testGrade10Offset30_isDecemberOfSophomoreFall() {
    // June 2027 - 30 months = Dec 2024
    let date = TaskDeadlineCalculator.deadlineDate(graduationYear: 2027, offsetMonths: 30, calendar: utc)
    XCTAssertTrue(ymd(date!) == (2024, 12, 1), "expected 2024-12-01, got \(ymd(date!))")
  }
}
