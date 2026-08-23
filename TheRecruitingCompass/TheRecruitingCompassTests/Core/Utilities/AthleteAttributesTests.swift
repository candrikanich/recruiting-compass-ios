import XCTest
@testable import TheRecruitingCompass

final class AthleteAttributesTests: XCTestCase {

    private func keys(_ sport: String?) -> [String] {
        AthleteAttributes.attributes(for: sport).map(\.key)
    }

    // MARK: - Per-sport membership

    func testBaseballHasBatsAndThrows() {
        XCTAssertEqual(keys("Baseball"), ["bats", "throws"])
    }

    func testSoftballMirrorsBaseball() {
        XCTAssertEqual(keys("Softball"), ["bats", "throws"])
    }

    func testBasketballHasShootingHandOnly() {
        XCTAssertEqual(keys("Basketball"), ["shooting_hand"])
    }

    func testIceHockeyListsShootsAlwaysAndCatchesGoalieGated() {
        let attrs = AthleteAttributes.attributes(for: "Ice Hockey")
        XCTAssertEqual(attrs.map(\.key), ["shoots", "catches"])

        let shoots = attrs.first { $0.key == "shoots" }
        XCTAssertEqual(shoots?.positions, [], "Shoots renders for every ice-hockey athlete")

        let catches = attrs.first { $0.key == "catches" }
        XCTAssertEqual(catches?.positions, ["Goalie"], "Catches is gated to Goalie")
    }

    func testFootballThrowingHandGatedToQuarterback() {
        let attrs = AthleteAttributes.attributes(for: "Football")
        XCTAssertEqual(attrs.map(\.key), ["throwing_hand", "kicking_foot"])
        XCTAssertEqual(attrs.first { $0.key == "throwing_hand" }?.positions, ["Quarterback"])
        XCTAssertEqual(attrs.first { $0.key == "kicking_foot" }?.positions, ["Kicker", "Punter"])
    }

    // MARK: - Sports with no attributes

    func testWrestlingHasNoAttributes() {
        XCTAssertTrue(keys("Wrestling").isEmpty)
    }

    func testTrackAndFieldHasNoAttributes() {
        XCTAssertTrue(keys("Track & Field").isEmpty)
    }

    func testNilSportReturnsEmpty() {
        XCTAssertTrue(keys(nil).isEmpty)
    }

    func testUnknownSportReturnsEmpty() {
        XCTAssertTrue(keys("Chess").isEmpty)
    }

    // MARK: - Option tokens (byte-identical contract)

    func testBatsOptionTokens() {
        let bats = AthleteAttributes.attributes(for: "Baseball").first { $0.key == "bats" }
        XCTAssertEqual(bats?.options, ["L", "R", "S"])
    }

    func testTennisBackhandTokens() {
        let backhand = AthleteAttributes.attributes(for: "Tennis").first { $0.key == "backhand_style" }
        XCTAssertEqual(backhand?.options, ["one", "two"])
    }

    func testRowingSideTokens() {
        let side = AthleteAttributes.attributes(for: "Rowing").first { $0.key == "rowing_side" }
        XCTAssertEqual(side?.options, ["port", "starboard", "both", "cox"])
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(keys("baseball"), keys("Baseball"))
    }
}
