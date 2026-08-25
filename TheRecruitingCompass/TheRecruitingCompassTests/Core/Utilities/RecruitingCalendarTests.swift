import XCTest
@testable import TheRecruitingCompass

final class RecruitingCalendarTests: XCTestCase {
    // resolver — all 17 sports incl. gender/subdivision/null-default
    func test_resolveKey_singleAndSplitSports() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Baseball"), .MBA)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Softball"), .WSB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "male"), .MBB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "female"), .WBB)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: nil), .MBB) // default men's
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Basketball", gender: "Female"), .WBB) // case-insensitive
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Lacrosse", gender: "female"), .WLA)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Golf", gender: "male"), .MGO)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Golf", gender: "female"), .other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football"), .FBS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football", footballSubdivision: "FCS"), .FCS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Track & Field"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Cross Country"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Soccer", gender: "female"), .OTHER_WSOCCER)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Wrestling", gender: "male"), .OTHER_MWRESTLING)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Tennis"), .other)
    }
    // gymnastics gender split (women → dedicated OTHER_WGYM table; men → generic Other)
    // + beach volleyball always falls through to the generic Other default
    func test_resolveKey_gymnasticsAndBeachVolleyball() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Gymnastics", gender: "female"), .otherWGYM)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Gymnastics", gender: "Female"), .otherWGYM) // case-insensitive
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Gymnastics", gender: "male"), .other) // men's default
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Gymnastics", gender: nil), .other) // nil → men's default
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Beach Volleyball", gender: "female"), .other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Beach Volleyball", gender: "male"), .other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Beach Volleyball"), .other)
    }
    func test_resolveKey_unknownAndNil_returnsOther_noBaseballFallback() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: nil), .other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Quidditch"), .other)
    }
    // integrity: every key has a calendar with source+verifiedOn + non-empty periods
    func test_everyCalendarWellFormed() {
        for key in NcaaCalendarKey.allCases {
            let cal = RecruitingCalendar.calendarFor(key: key)
            XCTAssertTrue(cal.source.contains("ncaaorg.s3.amazonaws.com"), "\(key)")
            // Most calendars share the file constant (2026-08-23); OTHER_WGYM was
            // transcribed later (2026-08-25) and carries its own verification date.
            XCTAssertTrue(["2026-08-23", "2026-08-25"].contains(cal.verifiedOn), "\(key) \(cal.verifiedOn)")
            for p in cal.periods {
                XCTAssertTrue(p.start <= p.end, "\(key) \(p.description)")
                XCTAssertEqual(p.start.count, 10) // yyyy-MM-dd
            }
        }
    }
    // plausibility (L3): dead/shutdown in sane months
    func test_plausibility_holidayMonths() {
        for key in NcaaCalendarKey.allCases {
            for p in RecruitingCalendar.calendarFor(key: key).periods {
                let month = Int(p.start.dropFirst(5).prefix(2))!
                if p.description.lowercased().contains("thanksgiving") { XCTAssertEqual(month, 11, "\(key)") }
                if p.description.lowercased().contains("july 4") || p.description.lowercased().contains("independence") { XCTAssertEqual(month, 7, "\(key)") }
            }
        }
    }
    // PARITY GUARD: per-key period counts match web (fill EXPECTED from the web calendarData.ts you port from)
    func test_parity_periodCounts() {
        let expected: [NcaaCalendarKey: Int] = [
            .MBA: 12, .WSB: 13, .MBB: 18, .WBB: 24, .FBS: 4, .FCS: 7, .XCTF: 7, .WVB: 13,
            .MGO: 7, .MLA: 16, .WLA: 18, .other: 1, .OTHER_MSOCCER: 3, .OTHER_WSOCCER: 4,
            .OTHER_SWIM: 4, .OTHER_MICEHOCKEY: 2, .OTHER_WICEHOCKEY: 3, .OTHER_ROWING: 2,
            .OTHER_FIELDHOCKEY: 2, .OTHER_MWRESTLING: 3, .OTHER_WWRESTLING: 2,
            .otherWGYM: 7,
        ]
        for (key, n) in expected { XCTAssertEqual(RecruitingCalendar.calendarFor(key: key).periods.count, n, "\(key)") }
    }
    // sport-specificity regression (mirrors web): July-4 dead for Baseball, not Tennis
    func test_isDeadPeriod_sportSpecific() {
        XCTAssertTrue(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Baseball", division: "D1"))
        XCTAssertFalse(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Tennis", division: "D1"))
    }

    // women's gymnastics resolves to its dedicated OTHER_WGYM windows; men's gymnastics
    // and beach volleyball ride the generic Other track (no May quiet window there)
    func test_womensGymnastics_calendarWindows() {
        XCTAssertTrue(RecruitingCalendar.isDeadPeriod(
            "2026-11-10", sport: "Gymnastics", division: "D1", gender: "female"))
        XCTAssertTrue(RecruitingCalendar.isQuietPeriod(
            "2027-05-20", sport: "Gymnastics", division: "D1", gender: "female"))
        // Men's gymnastics uses the generic Other track (only the Nov signing dead window).
        XCTAssertFalse(RecruitingCalendar.isQuietPeriod(
            "2027-05-20", sport: "Gymnastics", division: "D1", gender: "male"))
        XCTAssertFalse(RecruitingCalendar.isQuietPeriod(
            "2027-05-20", sport: "Beach Volleyball", division: "D1", gender: "female"))
    }

    // grad-year milestone filter parity (web resolver.ts getUpcomingMilestones): signing-type
    // milestones only surface for graduationYear == currentYear + 3 (senior); underclassmen
    // (freshman/sophomore) never see them. Baseball's MBA calendar has a real 2026-11-11 signing
    // milestone, and `dateISO`'s year (2026) stands in for "currentYear".
    func test_upcomingMilestones_underclassman_excludesSigning() {
        let milestones = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "Baseball", division: "D1", graduationYear: 2030 // frosh: 2026+4
        )
        XCTAssertFalse(milestones.contains { $0.type == .signing })
    }

    func test_upcomingMilestones_senior_includesSigning() {
        let milestones = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "Baseball", division: "D1", graduationYear: 2029 // senior: 2026+3
        )
        XCTAssertTrue(milestones.contains { $0.type == .signing })
    }

    func test_upcomingMilestones_junior_excludesSigning() {
        let milestones = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "Baseball", division: "D1", graduationYear: 2028 // junior: 2026+2
        )
        XCTAssertFalse(milestones.contains { $0.type == .signing })
    }

    func test_upcomingMilestones_noGraduationYear_unfiltered() {
        let milestones = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "Baseball", division: "D1", graduationYear: nil
        )
        XCTAssertTrue(milestones.contains { $0.type == .signing })
    }
}
