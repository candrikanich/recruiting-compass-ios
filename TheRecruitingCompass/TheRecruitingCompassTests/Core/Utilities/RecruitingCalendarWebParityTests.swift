import XCTest
@testable import TheRecruitingCompass

/// Field-by-field parity between `RecruitingCalendarData` and the web dataset it
/// mirrors. The fixture is exported from web by `scripts/export-web-calendar-fixture.ts`.
/// Web is the source of truth: on failure port the value into Swift (or re-export
/// the fixture if web changed) — never hand-edit the JSON.
final class RecruitingCalendarWebParityTests: XCTestCase {
    private struct Period: Decodable, Equatable {
        let type, start, end, description, confidence: String
    }

    private struct Milestone: Decodable, Equatable {
        let date, title, type: String
        let url, description, division: String?
    }

    private struct Calendar: Decodable {
        let periods: [Period]
        let milestones: [Milestone]
        let source, verifiedOn: String
    }

    private struct Fixture: Decodable {
        let season, seasonEnd: String
        let d1Calendars: [String: Calendar]
        let d2AllSports, d3Fallback: Calendar
        let genericMilestones: [Milestone]
    }

    private func loadFixture() throws -> Fixture {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "web-recruiting-calendar", withExtension: "json"),
            "web-recruiting-calendar.json missing from the test bundle"
        )
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func webShape(_ period: RecruitingPeriod) -> Period {
        Period(
            type: period.type.rawValue, start: period.start, end: period.end,
            description: period.description, confidence: period.confidence.rawValue
        )
    }

    private func webShape(_ milestone: CalendarMilestone) -> Milestone {
        Milestone(
            date: milestone.date, title: milestone.title, type: milestone.type.rawValue,
            url: milestone.url, description: milestone.description, division: milestone.division
        )
    }

    /// Web marks "applies to every division" as `"ALL"`; Swift ports that as `nil`.
    private func allDivisionsAsNil(_ milestone: Milestone) -> Milestone {
        Milestone(
            date: milestone.date, title: milestone.title, type: milestone.type,
            url: milestone.url, description: milestone.description,
            division: milestone.division == "ALL" ? nil : milestone.division
        )
    }

    private func assertElementsMatch<T: Equatable>(_ swift: [T], _ web: [T], _ label: String) {
        XCTAssertEqual(swift.count, web.count, "\(label) count")
        for (index, pair) in zip(swift, web).enumerated() {
            XCTAssertEqual(pair.0, pair.1, "\(label)[\(index)]")
        }
    }

    private func assertMatches(_ swift: SportCalendar, _ web: Calendar, _ label: String) {
        XCTAssertEqual(swift.source, web.source, "\(label) source")
        XCTAssertEqual(swift.verifiedOn, web.verifiedOn, "\(label) verifiedOn")
        assertElementsMatch(swift.periods.map(webShape), web.periods, "\(label) periods")
        assertElementsMatch(swift.milestones.map(webShape), web.milestones, "\(label) milestones")
    }

    func test_seasonMatchesWeb() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(RecruitingCalendarData.season, fixture.season)
        XCTAssertEqual(RecruitingCalendarData.seasonEnd, fixture.seasonEnd)
    }

    func test_d1CalendarsMatchWeb() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(Set(NcaaCalendarKey.allCases.map(\.rawValue)), Set(fixture.d1Calendars.keys))
        for key in NcaaCalendarKey.allCases {
            let web = try XCTUnwrap(fixture.d1Calendars[key.rawValue], "\(key.rawValue) missing from web")
            assertMatches(RecruitingCalendar.calendarFor(key: key), web, key.rawValue)
        }
    }

    func test_d2AndD3CalendarsMatchWeb() throws {
        let fixture = try loadFixture()
        assertMatches(RecruitingCalendarData.d2AllSports, fixture.d2AllSports, "D2")
        assertMatches(RecruitingCalendarData.d3Fallback, fixture.d3Fallback, "D3")
    }

    func test_genericMilestonesMatchWeb() throws {
        let fixture = try loadFixture()
        assertElementsMatch(
            RecruitingCalendarData.genericMilestones.map(webShape),
            fixture.genericMilestones.map(allDivisionsAsNil),
            "genericMilestones"
        )
    }
}
