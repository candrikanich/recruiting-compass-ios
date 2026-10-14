import XCTest
@testable import TheRecruitingCompass

final class FamilyUnitIDTests: XCTestCase {
  nonisolated deinit {}

  func testNormalized_nilAndBlank_areNil() {
    XCTAssertNil(FamilyUnitID.normalized(nil))
    XCTAssertNil(FamilyUnitID.normalized(""))
    XCTAssertNil(FamilyUnitID.normalized("  \n"))
  }

  func testNormalized_trimsValidId() {
    XCTAssertEqual(FamilyUnitID.normalized(" fam-1 "), "fam-1")
  }
}
