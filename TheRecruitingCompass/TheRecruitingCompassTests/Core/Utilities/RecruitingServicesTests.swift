import XCTest
@testable import TheRecruitingCompass

final class RecruitingServicesTests: XCTestCase {

    private func keys(_ sport: String?) -> [String] {
        RecruitingServices.servicesForSport(sport).map(\.key)
    }

    // MARK: - NCSA everywhere

    func testNCSAAvailableForEveryKnownSport() {
        for sport in CanonicalPositions.bySport.keys {
            XCTAssertTrue(keys(sport).contains("ncsa_id"), "NCSA missing for \(sport)")
        }
    }

    func testNilAndUnknownSportReturnEmpty() {
        XCTAssertTrue(keys(nil).isEmpty)
        XCTAssertTrue(keys("Chess").isEmpty)
        XCTAssertTrue(keys("").isEmpty)
    }

    // MARK: - Hudl gate

    func testHudlOnlyForItsSportList() {
        let hudlSports = ["Football", "Basketball", "Volleyball", "Soccer", "Lacrosse",
                          "Ice Hockey", "Field Hockey", "Water Polo", "Wrestling"]
        for sport in hudlSports {
            XCTAssertTrue(keys(sport).contains("hudl_url"), "Hudl missing for \(sport)")
        }
        for sport in ["Baseball", "Softball", "Golf", "Tennis", "Track & Field",
                      "Cross Country", "Swimming", "Rowing"] {
            XCTAssertFalse(keys(sport).contains("hudl_url"), "Hudl should not appear for \(sport)")
        }
    }

    // MARK: - Perfect Game / Prep Baseball gate

    func testPerfectGameAndPrepBaseballOnlyBaseballSoftball() {
        for sport in ["Baseball", "Softball"] {
            let k = keys(sport)
            XCTAssertTrue(k.contains("perfect_game_id"))
            XCTAssertTrue(k.contains("prep_baseball_id"))
        }
        for sport in ["Basketball", "Football", "Soccer", "Golf"] {
            let k = keys(sport)
            XCTAssertFalse(k.contains("perfect_game_id"))
            XCTAssertFalse(k.contains("prep_baseball_id"))
        }
    }

    func testBaseballServiceOrder() {
        XCTAssertEqual(keys("Baseball"), ["ncsa_id", "perfect_game_id", "prep_baseball_id"])
    }

    // MARK: - URL templates (byte-identical contract)

    func testPerfectGameUrlTemplateExact() {
        let pg = RecruitingServices.service(forKey: "perfect_game_id")
        XCTAssertEqual(pg?.urlTemplate,
                       "https://www.perfectgame.org/Players/Playerprofile.aspx?ID={value}")
        XCTAssertEqual(pg?.valueKind, .id)
    }

    func testHudlIsUrlValueWithNoTemplate() {
        let hudl = RecruitingServices.service(forKey: "hudl_url")
        XCTAssertEqual(hudl?.valueKind, .url)
        XCTAssertNil(hudl?.urlTemplate)
    }

    func testPrepBaseballIsSignupOnly() {
        let pbr = RecruitingServices.service(forKey: "prep_baseball_id")
        XCTAssertNil(pbr?.urlTemplate)
        XCTAssertEqual(pbr?.signupUrl, "https://www.prepbaseballreport.com/")
    }
}
