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

    // MARK: - Full-vocabulary regression guards (web is source of truth)

    /// Exact sport-key set. A future add/drop/rename fails loudly here (and in the
    /// snapshot below) so iOS never silently drifts from the web vocabulary.
    func testSportKeySetIsExactly19() {
        XCTAssertEqual(
            Set(CanonicalPositions.bySport.keys),
            [
                "Baseball", "Softball", "Basketball", "Football", "Soccer", "Volleyball",
                "Track & Field", "Swimming", "Cross Country", "Tennis", "Golf", "Lacrosse",
                "Field Hockey", "Ice Hockey", "Wrestling", "Rowing", "Water Polo",
                "Gymnastics", "Beach Volleyball"
            ]
        )
    }

    /// Every sport's exact ordered position list — snapshot mirror of web
    /// `SPORT_POSITIONS`. Order is load-bearing (primary/secondary derivation).
    func testFullPositionVocabularySnapshot() {
        let expected: [String: [String]] = [
            "Baseball": ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base",
                         "Shortstop", "Left Field", "Center Field", "Right Field", "Designated Hitter"],
            "Softball": ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base",
                         "Shortstop", "Left Field", "Center Field", "Right Field", "Designated Hitter"],
            "Basketball": ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center"],
            "Football": ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Offensive Line",
                         "Defensive Line", "Linebacker", "Defensive Back", "Kicker", "Punter"],
            "Soccer": ["Goalkeeper", "Defender", "Midfielder", "Forward"],
            "Volleyball": ["Outside Hitter", "Middle Blocker", "Setter", "Libero",
                           "Opposite Hitter", "Defensive Specialist"],
            "Track & Field": ["Sprinter", "Distance Runner", "Jumper", "Thrower", "Hurdler"],
            "Swimming": ["Freestyle", "Backstroke", "Breaststroke", "Butterfly", "Individual Medley", "Diver"],
            "Cross Country": ["Runner"],
            "Tennis": ["Singles", "Doubles"],
            "Golf": ["Golfer"],
            "Lacrosse": ["Attackman", "Midfielder", "Defenseman", "Goalie"],
            "Field Hockey": ["Forward", "Midfielder", "Defender", "Goalkeeper"],
            "Ice Hockey": ["Forward", "Defenseman", "Goalie"],
            "Wrestling": ["Wrestler"],
            "Rowing": ["Rower"],
            "Water Polo": ["Field Player", "Goalkeeper"],
            "Gymnastics": ["All-Around", "Vault", "Uneven Bars", "Balance Beam", "Floor Exercise",
                           "Pommel Horse", "Still Rings", "Parallel Bars", "Horizontal Bar"],
            "Beach Volleyball": ["Blocker", "Defender"]
        ]
        XCTAssertEqual(CanonicalPositions.bySport, expected)
    }

    func testGymnasticsPositionsOrderedAllAroundFirst() {
        let gym = CanonicalPositions.positions(for: "Gymnastics")
        XCTAssertEqual(gym.first, "All-Around")
        XCTAssertEqual(gym.count, 9)
    }

    func testBeachVolleyballPositions() {
        XCTAssertEqual(CanonicalPositions.positions(for: "Beach Volleyball"), ["Blocker", "Defender"])
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
