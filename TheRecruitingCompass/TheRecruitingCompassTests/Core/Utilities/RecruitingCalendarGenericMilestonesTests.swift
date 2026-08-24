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
}
