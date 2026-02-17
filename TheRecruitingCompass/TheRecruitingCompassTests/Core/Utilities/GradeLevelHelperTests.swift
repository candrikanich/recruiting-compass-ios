import XCTest
@testable import TheRecruitingCompass

final class GradeLevelHelperTests: XCTestCase {

  var calendar: Calendar { Calendar.current }

  func testCalculateCurrentGrade_ReturnsValueIn9To12() {
    for gradYear in [2026, 2027, 2028, 2029, 2030] {
      let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: gradYear)
      XCTAssertGreaterThanOrEqual(grade, 9, "gradYear \(gradYear)")
      XCTAssertLessThanOrEqual(grade, 12, "gradYear \(gradYear)")
    }
  }

  func testCalculateCurrentGrade_February_Graduation2026_IsSenior() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2026, referenceDate: ref)
    XCTAssertEqual(grade, 12) // senior
  }

  func testCalculateCurrentGrade_February_Graduation2027_IsJunior() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2027, referenceDate: ref)
    XCTAssertEqual(grade, 11) // junior
  }

  func testCalculateCurrentGrade_February_Graduation2028_IsSophomore() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028, referenceDate: ref)
    XCTAssertEqual(grade, 10) // sophomore
  }

  func testCalculateCurrentGrade_February_Graduation2029_IsFreshman() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2029, referenceDate: ref)
    XCTAssertEqual(grade, 9) // freshman
  }

  func testCalculateCurrentGrade_September_AdvancesSchoolYear() {
    // Sept 2025: school year 2025-26, end year 2026. Grad 2026 -> 12.
    let refSept = date(2025, 9, 1)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2026, referenceDate: refSept), 12)
    // June 2026: still 2025-26, end 2026. Grad 2026 -> 12.
    let refJune = date(2026, 6, 15)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2026, referenceDate: refJune), 12)
    // July 2026: 2026-27 hasn't started; end year = 2026 (summer after June).
    let refJuly = date(2026, 7, 1)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2026, referenceDate: refJuly), 12)
    // Sept 2026: 2026-27, end 2027. Grad 2027 -> 12.
    let refSept26 = date(2026, 9, 1)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2027, referenceDate: refSept26), 12)
  }

  func testCalculateCurrentGrade_Clamped_DoesNotExceed12() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2024, referenceDate: ref)
    XCTAssertEqual(grade, 12)
  }

  func testCalculateCurrentGrade_Clamped_DoesNotGoBelow9() {
    let ref = date(2026, 2, 15)
    let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: 2032, referenceDate: ref)
    XCTAssertEqual(grade, 9)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    return calendar.date(from: comps)!
  }
}
