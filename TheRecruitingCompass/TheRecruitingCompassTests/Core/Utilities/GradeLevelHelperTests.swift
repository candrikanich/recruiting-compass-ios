import XCTest
@testable import TheRecruitingCompass

final class GradeLevelHelperTests: XCTestCase {

  var calendar: Calendar { Calendar.current }

  func testAllowedGraduationYears_IsCurrentThroughCurrentPlus5() {
    let years = GradeLevelHelper.allowedGraduationYears
    let current = calendar.component(.year, from: Date())
    XCTAssertEqual(years.count, 6, "Should show current year + 5 (6 years total) — web parity, lets rising 8th graders pick")
    XCTAssertEqual(years, Array(current...(current + 5)), "Should be consecutive from current through current+5")
    XCTAssertEqual(years.last, current + 5, "Upper bound must be current+5")
  }

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
    // July 2026: July 1 roll pivot -> rising into 2026-27, end year 2027. Grad 2027 -> 12.
    let refJuly = date(2026, 7, 1)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2027, referenceDate: refJuly), 12)
    // Sept 2026: 2026-27, end 2027. Grad 2027 -> 12.
    let refSept26 = date(2026, 9, 1)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2027, referenceDate: refSept26), 12)
  }

  // Regression: rising junior in summer must read as junior, not sophomore (July 1 pivot).
  // Owen, grad 2028, viewed Aug 2026 -> grade 11 (was 10 under old Sept pivot).
  func testCalculateCurrentGrade_August_RisingJunior_IsJunior() {
    let refAug = date(2026, 8, 10)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028, referenceDate: refAug), 11)
  }

  // June still counts the just-finished grade (pivot is July 1, not June).
  func testCalculateCurrentGrade_June_RisingJunior_StillSophomore() {
    let refJune = date(2026, 6, 15)
    XCTAssertEqual(GradeLevelHelper.calculateCurrentGrade(graduationYear: 2028, referenceDate: refJune), 10)
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

  // MARK: - daysUntilGraduation

  func testDaysUntilGraduation_CountsToJune1() {
    let ref = date(2026, 6, 1)
    // 2027 graduation, one year out: 2026-06-01 → 2027-06-01 = 365 days (2027 is not a leap year)
    XCTAssertEqual(GradeLevelHelper.daysUntilGraduation(graduationYear: 2027, referenceDate: ref), 365)
  }

  func testDaysUntilGraduation_SameDayIsZero() {
    let ref = date(2027, 6, 1)
    XCTAssertEqual(GradeLevelHelper.daysUntilGraduation(graduationYear: 2027, referenceDate: ref), 0)
  }

  func testDaysUntilGraduation_IgnoresTimeOfDay() {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 1; comps.hour = 23; comps.minute = 59
    let ref = calendar.date(from: comps)!
    // Whole-day granularity: late on 2026-06-01 still counts a full 365 to 2027-06-01
    XCTAssertEqual(GradeLevelHelper.daysUntilGraduation(graduationYear: 2027, referenceDate: ref), 365)
  }

  func testDaysUntilGraduation_PastGraduationReturnsNil() {
    let ref = date(2027, 6, 2)
    XCTAssertNil(GradeLevelHelper.daysUntilGraduation(graduationYear: 2027, referenceDate: ref))
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    return calendar.date(from: comps)!
  }
}
