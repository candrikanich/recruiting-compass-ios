import XCTest
@testable import TheRecruitingCompass

final class COPPAHelperTests: XCTestCase {

  private let calendar = Calendar.current

  private func dobString(yearsAgo: Int, extraDays: Int = 0) -> String {
    let dob = calendar.date(byAdding: .year, value: -yearsAgo, to: Date.now)!
    let adjusted = calendar.date(byAdding: .day, value: extraDays, to: dob)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: adjusted)
  }

  func testIsUnderAge_TwelveYearsOld_IsUnderAge() {
    XCTAssertTrue(COPPAHelper.isUnderAge(dobString(yearsAgo: 12)))
  }

  func testIsUnderAge_FourteenYearsOld_IsNotUnderAge() {
    XCTAssertFalse(COPPAHelper.isUnderAge(dobString(yearsAgo: 14)))
  }

  func testIsUnderAge_ThirteenthBirthdayToday_IsNotUnderAge() {
    XCTAssertFalse(COPPAHelper.isUnderAge(dobString(yearsAgo: 13)))
  }

  func testIsUnderAge_OneDayBeforeThirteenthBirthday_IsUnderAge() {
    XCTAssertTrue(COPPAHelper.isUnderAge(dobString(yearsAgo: 13, extraDays: 1)))
  }

  func testIsUnderAge_ISO8601FullDate_Parses() {
    XCTAssertTrue(COPPAHelper.isUnderAge(dobString(yearsAgo: 10)))
    XCTAssertFalse(COPPAHelper.isUnderAge("2000-01-15"))
  }

  func testIsUnderAge_UnparseableDOB_FailsClosed() {
    XCTAssertTrue(COPPAHelper.isUnderAge("not-a-date"), "Unparseable DOB must be treated as under-age (fail closed)")
    XCTAssertTrue(COPPAHelper.isUnderAge(""), "Empty DOB must be treated as under-age (fail closed)")
    XCTAssertTrue(COPPAHelper.isUnderAge("13"), "Bare number must be treated as under-age (fail closed)")
  }

  // MARK: - requiresGuardianInvite (13-17 band)

  func testRequiresGuardianInvite_Under13_IsFalse() {
    XCTAssertFalse(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 10)))
  }

  func testRequiresGuardianInvite_ThirteenToSeventeen_IsTrue() {
    XCTAssertTrue(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 13)))
    XCTAssertTrue(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 15)))
    XCTAssertTrue(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 17)))
  }

  func testRequiresGuardianInvite_EighteenAndOver_IsFalse() {
    XCTAssertFalse(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 18)))
    XCTAssertFalse(COPPAHelper.requiresGuardianInvite(dobString(yearsAgo: 25)))
  }

  func testRequiresGuardianInvite_UnparseableDOB_IsFalse() {
    XCTAssertFalse(COPPAHelper.requiresGuardianInvite("not-a-date"))
    XCTAssertFalse(COPPAHelper.requiresGuardianInvite(""))
  }
}
