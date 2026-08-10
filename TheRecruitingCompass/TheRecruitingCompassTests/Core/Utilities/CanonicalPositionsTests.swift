import XCTest
@testable import TheRecruitingCompass

final class CanonicalPositionsTests: XCTestCase {

    // MARK: - positions(for:)

    func testPositionsForSportIsCaseInsensitive() {
        XCTAssertEqual(CanonicalPositions.positions(for: "baseball"),
                       CanonicalPositions.positions(for: "Baseball"))
    }

    func testSoftballSharesBaseballPositions() {
        XCTAssertEqual(CanonicalPositions.positions(for: "Softball"),
                       CanonicalPositions.positions(for: "Baseball"))
    }

    func testNoPickerListsCoarseBuckets() {
        for positions in CanonicalPositions.bySport.values {
            for coarse in ["Infielder", "Outfielder", "Guard", "Lineman"] {
                XCTAssertFalse(positions.contains(coarse), "Found coarse bucket \(coarse)")
            }
        }
    }

    func testUnknownSportReturnsEmpty() {
        XCTAssertTrue(CanonicalPositions.positions(for: "Other").isEmpty)
        XCTAssertTrue(CanonicalPositions.positions(for: nil).isEmpty)
    }

    // MARK: - normalize coarse buckets → Utility

    func testInfielderCollapsesToUtility() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "Infielder"), "Utility")
    }

    func testOutfielderCollapsesToUtility() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "OF"), "Utility")
    }

    // MARK: - abbreviation expansion + sport-scoped collisions

    func testBaseballCIsCatcher() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "C"), "Catcher")
    }

    func testBasketballCIsCenter() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Basketball", "C"), "Center")
    }

    func testBaseballPIsPitcher() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "P"), "Pitcher")
    }

    func testFootballPIsPunter() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Football", "P"), "Punter")
    }

    func testBaseballAbbreviationsExpand() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "SS"), "Shortstop")
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "1b"), "First Base")
    }

    // MARK: - canonical passthrough + preservation

    func testAlreadyCanonicalSnapsToCanonicalCasing() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "shortstop"), "Shortstop")
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Basketball", "point guard"), "Point Guard")
    }

    func testUnknownValueIsPreserved() {
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "Designated Runner"),
                       "Designated Runner")
    }

    func testNilAndEmptyPassThrough() {
        XCTAssertNil(CanonicalPositions.normalize(sport: "Baseball", nil))
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "   "), "   ")
    }
}
