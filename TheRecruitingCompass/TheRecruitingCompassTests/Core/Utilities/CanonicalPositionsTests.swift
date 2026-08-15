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
            for coarse in ["Infielder", "Outfielder", "Utility", "Guard", "Lineman"] {
                XCTAssertFalse(positions.contains(coarse), "Found coarse bucket \(coarse)")
            }
        }
    }

    func testUnknownSportReturnsEmpty() {
        XCTAssertTrue(CanonicalPositions.positions(for: "Other").isEmpty)
        XCTAssertTrue(CanonicalPositions.positions(for: nil).isEmpty)
    }

    // MARK: - vague catch-alls no longer resolve (preserved raw, not fabricated)

    func testCoarseBucketsNoLongerResolve() {
        // Recruiting output must name a specific position — these preserve raw
        // (so backfill migrates them) instead of resolving to a fake "Utility".
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "Infielder"), "Infielder")
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "Outfielder"), "Outfielder")
        XCTAssertEqual(CanonicalPositions.normalize(sport: "Baseball", "Utility"), "Utility")
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

    // MARK: - abbreviation

    func testAbbreviationBaseball() {
        XCTAssertEqual(CanonicalPositions.abbreviation(sport: "Baseball", "Third Base"), "3B")
        XCTAssertEqual(CanonicalPositions.abbreviation(sport: "Softball", "Shortstop"), "SS")
    }

    func testAbbreviationFallsBackToFullNameForUnmappedSport() {
        // Volleyball has no abbreviation table → full name is returned as-is.
        XCTAssertEqual(CanonicalPositions.abbreviation(sport: "Volleyball", "Outside Hitter"), "Outside Hitter")
    }

    // MARK: - formatPositionsShort (ordered primary/secondary)

    func testFormatPositionsShortJoinsFirstTwoAbbreviated() {
        XCTAssertEqual(
            CanonicalPositions.formatPositionsShort(
                sport: "Baseball", positions: ["Third Base", "Shortstop", "Pitcher"], fallback: nil),
            "3B/SS")
    }

    func testFormatPositionsShortPrimaryOnlyWhenNoSecondary() {
        XCTAssertEqual(
            CanonicalPositions.formatPositionsShort(
                sport: "Baseball", positions: ["Third Base"], fallback: nil),
            "3B")
    }

    func testFormatPositionsShortUsesFallbackWhenArrayEmpty() {
        XCTAssertEqual(
            CanonicalPositions.formatPositionsShort(
                sport: "Baseball", positions: [], fallback: "Shortstop"),
            "SS")
    }

    func testFormatPositionsShortEmptyWhenNothingEntered() {
        XCTAssertEqual(
            CanonicalPositions.formatPositionsShort(sport: "Baseball", positions: nil, fallback: nil),
            "")
    }
}
