import XCTest
@testable import TheRecruitingCompass

final class FamilyConstantsTests: XCTestCase {

    /// Parent-onboarding sport list is derived from the position registry (the iOS
    /// SSOT) plus an "Other" catch-all — this guard fails loudly if the derivation
    /// is ever replaced with a hardcoded list that could drift out of parity.
    func testSportsAllDerivedFromCanonicalPositionsPlusOther() {
        XCTAssertEqual(
            FamilyConstants.Sports.all,
            CanonicalPositions.bySport.keys.sorted() + ["Other"]
        )
    }

    func testSportsAllCoversEveryCanonicalSport() {
        for sport in CanonicalPositions.bySport.keys {
            XCTAssertTrue(FamilyConstants.Sports.all.contains(sport),
                          "\(sport) missing from parent-onboarding sport list")
        }
    }

    func testSportsAllIncludesNewSportsAndOther() {
        XCTAssertTrue(FamilyConstants.Sports.all.contains("Gymnastics"))
        XCTAssertTrue(FamilyConstants.Sports.all.contains("Beach Volleyball"))
        XCTAssertEqual(FamilyConstants.Sports.all.last, "Other")
    }
}
