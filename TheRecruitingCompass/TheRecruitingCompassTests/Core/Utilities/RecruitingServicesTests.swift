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

    // MARK: - Services v2 gates

    func testAthleticNetOnlyTrackAndCrossCountry() {
        for sport in ["Track & Field", "Cross Country"] {
            XCTAssertTrue(keys(sport).contains("athletic_net_id"),
                          "Athletic.net missing for \(sport)")
            XCTAssertTrue(keys(sport).contains("milesplit_url"),
                          "MileSplit missing for \(sport)")
        }
        for sport in ["Baseball", "Swimming", "Football", "Tennis", "Rowing"] {
            XCTAssertFalse(keys(sport).contains("athletic_net_id"),
                           "Athletic.net should not appear for \(sport)")
        }
    }

    func testSwimCloudOnlySwimming() {
        XCTAssertTrue(keys("Swimming").contains("swimcloud_id"))
        for sport in ["Baseball", "Track & Field", "Water Polo", "Tennis"] {
            XCTAssertFalse(keys(sport).contains("swimcloud_id"),
                           "SwimCloud should not appear for \(sport)")
        }
    }

    func testOn3And247OnlyFootballBasketballAndAreUrlKind() {
        for sport in ["Football", "Basketball"] {
            let k = keys(sport)
            XCTAssertTrue(k.contains("on3_url"), "On3 missing for \(sport)")
            XCTAssertTrue(k.contains("sports247_url"), "247Sports missing for \(sport)")
        }
        for sport in ["Baseball", "Soccer", "Tennis", "Rowing"] {
            let k = keys(sport)
            XCTAssertFalse(k.contains("on3_url"))
            XCTAssertFalse(k.contains("sports247_url"))
        }
        for key in ["on3_url", "sports247_url"] {
            let svc = RecruitingServices.service(forKey: key)
            XCTAssertEqual(svc?.valueKind, .url, "\(key) should be url-kind")
            XCTAssertNil(svc?.urlTemplate, "\(key) should have no template (value is the link)")
        }
    }

    func testTennisAndHockeyAndRowingV2Gates() {
        for key in ["utr_id", "tennis_recruiting_id"] {
            XCTAssertTrue(keys("Tennis").contains(key), "\(key) missing for Tennis")
            XCTAssertFalse(keys("Golf").contains(key))
        }
        XCTAssertTrue(keys("Ice Hockey").contains("elite_prospects_id"))
        XCTAssertFalse(keys("Soccer").contains("elite_prospects_id"))
        XCTAssertTrue(keys("Rowing").contains("concept2_id"))
        XCTAssertFalse(keys("Swimming").contains("concept2_id"))
    }

    func testSportsRecruitsGate() {
        for sport in ["Soccer", "Lacrosse", "Volleyball", "Field Hockey"] {
            XCTAssertTrue(keys(sport).contains("sportsrecruits_id"),
                          "SportsRecruits missing for \(sport)")
        }
        for sport in ["Baseball", "Football", "Tennis"] {
            XCTAssertFalse(keys(sport).contains("sportsrecruits_id"))
        }
    }

    func testV2IdUrlTemplatesExact() {
        XCTAssertEqual(RecruitingServices.service(forKey: "athletic_net_id")?.urlTemplate,
                       "https://www.athletic.net/athlete/{value}")
        XCTAssertEqual(RecruitingServices.service(forKey: "swimcloud_id")?.urlTemplate,
                       "https://www.swimcloud.com/swimmer/{value}/")
        XCTAssertEqual(RecruitingServices.service(forKey: "utr_id")?.urlTemplate,
                       "https://app.utrsports.net/profiles/{value}")
        XCTAssertEqual(RecruitingServices.service(forKey: "tennis_recruiting_id")?.urlTemplate,
                       "https://www.tennisrecruiting.net/player.asp?id={value}")
        XCTAssertEqual(RecruitingServices.service(forKey: "elite_prospects_id")?.urlTemplate,
                       "https://www.eliteprospects.com/player/{value}")
        XCTAssertEqual(RecruitingServices.service(forKey: "sportsrecruits_id")?.urlTemplate,
                       "https://sportsrecruits.com/athlete/{value}")
        XCTAssertEqual(RecruitingServices.service(forKey: "concept2_id")?.urlTemplate,
                       "https://log.concept2.com/profile/{value}")
    }

    func testV2OrderedAfterV1() {
        // Swimming: only NCSA (v1, all-sports) then SwimCloud (v2).
        XCTAssertEqual(keys("Swimming"), ["ncsa_id", "swimcloud_id"])
        // Football: NCSA + Hudl (v1) precede On3 + 247Sports (v2).
        XCTAssertEqual(keys("Football"),
                       ["ncsa_id", "hudl_url", "on3_url", "sports247_url"])
    }
}
