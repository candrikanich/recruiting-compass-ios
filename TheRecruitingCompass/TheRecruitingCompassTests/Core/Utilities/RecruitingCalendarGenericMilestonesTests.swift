import XCTest
@testable import TheRecruitingCompass

final class RecruitingCalendarGenericMilestonesTests: XCTestCase {
    // Generic milestones must surface for a sport whose calendar has no milestones
    // (e.g. a non-baseball/football sport), proving the merge is sport-agnostic.
    func testGenericMilestonesSurfaceForAnySport() {
        let result = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "soccer", division: "D1",
            gender: "male", graduationYear: nil, limit: 50)
        XCTAssertTrue(result.contains { $0.type == .test && $0.title.contains("SAT") },
                      "SAT test dates should appear for any sport")
        XCTAssertTrue(result.contains { $0.title.contains("FAFSA") },
                      "FAFSA Opens should appear")
    }

    func testGenericMilestoneCountMatchesPort() {
        // SAT (8) + ACT (7) + NCAA (1) + NAIA (1) + college application/FAFSA (6) = 23
        XCTAssertEqual(RecruitingCalendarData.genericMilestones.count, 23)
    }

    func testSATDatesAreRealPortedValues() {
        let sat = RecruitingCalendarData.genericMilestones.filter { $0.title.contains("SAT") }
        XCTAssertEqual(sat.count, 8)
        XCTAssertTrue(sat.contains { $0.date == "2026-10-03" })
    }

    // Division-filtering parity (web `matchesDivision`): NCAA eligibility entry is
    // tagged "D1" and must only surface for D1 athletes.
    func testNCAAEligibilityEntryPresentForD1() {
        let result = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "soccer", division: "D1",
            gender: "male", graduationYear: nil, limit: 50)
        XCTAssertTrue(result.contains { $0.title == "NCAA Eligibility Center Registration - Juniors" })
    }

    func testNCAAEligibilityEntryAbsentForD2() {
        let result = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "soccer", division: "D2",
            gender: "male", graduationYear: nil, limit: 50)
        XCTAssertFalse(result.contains { $0.title == "NCAA Eligibility Center Registration - Juniors" })
    }

    // NAIA entry's division ("NAIA") never equals "D1"/"D2"/"D3" — matches web,
    // where it likewise never surfaces via `matchesDivision` for any Division value.
    func testNAIAEntryAbsentForAllNCAADivisions() {
        for division in ["D1", "D2", "D3"] {
            let result = RecruitingCalendar.upcomingMilestones(
                "2026-01-01", sport: "soccer", division: division,
                gender: "male", graduationYear: nil, limit: 50)
            XCTAssertFalse(result.contains { $0.title == "NAIA Eligibility Center Registration" },
                          "NAIA entry should not surface for division \(division)")
        }
    }

    // SAT/ACT/FAFSA entries are division-agnostic ("ALL") — present for every division.
    func testDivisionAgnosticEntriesPresentForD1AndD2() {
        for division in ["D1", "D2"] {
            let result = RecruitingCalendar.upcomingMilestones(
                "2026-01-01", sport: "soccer", division: division,
                gender: "male", graduationYear: nil, limit: 50)
            XCTAssertTrue(result.contains { $0.type == .test && $0.title.contains("SAT") },
                          "SAT dates should appear for division \(division)")
            XCTAssertTrue(result.contains { $0.title.contains("FAFSA") },
                          "FAFSA Opens should appear for division \(division)")
        }
    }
}
