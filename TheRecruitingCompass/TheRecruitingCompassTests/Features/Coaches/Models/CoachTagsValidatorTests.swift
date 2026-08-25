import XCTest
@testable import TheRecruitingCompass

final class CoachTagsValidatorTests: XCTestCase {
  nonisolated deinit {}

  func testSanitize_trimsDropsEmptyAndDupes() {
    XCTAssertEqual(
      CoachTagsValidator.sanitize(["  Football ", "Football", "", "   ", "Referral"]),
      ["Football", "Referral"]
    )
  }

  func testSanitize_capsAt20Items() {
    let input = (1...25).map { "tag\($0)" }
    XCTAssertEqual(CoachTagsValidator.sanitize(input).count, 20)
  }

  func testSanitize_dropsTagsOver40Chars() {
    let long = String(repeating: "a", count: 41)
    XCTAssertEqual(CoachTagsValidator.sanitize([long, "ok"]), ["ok"])
  }

  func testSanitizeSource_capsAt80AndNilIfEmpty() {
    XCTAssertNil(CoachTagsValidator.sanitizeSource("   "))
    XCTAssertEqual(CoachTagsValidator.sanitizeSource("LinkedIn"), "LinkedIn")
    XCTAssertNil(CoachTagsValidator.sanitizeSource(String(repeating: "a", count: 81)),
                 "over-cap source is rejected (nil), not truncated")
  }
}
