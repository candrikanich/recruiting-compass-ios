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

final class FamilyUnitIDRequireTests: XCTestCase {
  nonisolated deinit {}

  func testRequire_missingOrBlank_throwsMissing() {
    for raw in [nil, "", "   ", "\n"] as [String?] {
      XCTAssertThrowsError(try FamilyUnitID.require(raw)) { error in
        XCTAssertEqual(error as? FamilyUnitID.MissingError, .missing)
      }
    }
  }

  func testRequire_validId_returnsTrimmed() throws {
    XCTAssertEqual(try FamilyUnitID.require(" fam-1 "), "fam-1")
  }

  func testMissingError_usesTheLoadingCopy() {
    XCTAssertEqual(
      FamilyUnitID.MissingError.missing.errorDescription,
      "Your family account is still loading. Please wait a moment and try again."
    )
  }
}
