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
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Golf", gender: "female"), .Other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football"), .FBS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Football", footballSubdivision: "FCS"), .FCS)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Track & Field"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Cross Country"), .XCTF)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Soccer", gender: "female"), .OTHER_WSOCCER)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Wrestling", gender: "male"), .OTHER_MWRESTLING)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Tennis"), .Other)
    }
    func test_resolveKey_unknownAndNil_returnsOther_noBaseballFallback() {
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: nil), .Other)
        XCTAssertEqual(RecruitingCalendar.resolveKey(sport: "Quidditch"), .Other)
    }
    // integrity: every key has a calendar with source+verifiedOn + non-empty periods
    func test_everyCalendarWellFormed() {
        for key in NcaaCalendarKey.allCases {
            let cal = RecruitingCalendar.calendarFor(key: key)
            XCTAssertTrue(cal.source.contains("ncaaorg.s3.amazonaws.com"), "\(key)")
            XCTAssertEqual(cal.verifiedOn, "2026-08-23", "\(key)")
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
            .MGO: 7, .MLA: 16, .WLA: 18, .Other: 1, .OTHER_MSOCCER: 3, .OTHER_WSOCCER: 4,
            .OTHER_SWIM: 4, .OTHER_MICEHOCKEY: 2, .OTHER_WICEHOCKEY: 3, .OTHER_ROWING: 2,
            .OTHER_FIELDHOCKEY: 2, .OTHER_MWRESTLING: 3, .OTHER_WWRESTLING: 2,
        ]
        for (key, n) in expected { XCTAssertEqual(RecruitingCalendar.calendarFor(key: key).periods.count, n, "\(key)") }
    }
    // sport-specificity regression (mirrors web): July-4 dead for Baseball, not Tennis
    func test_isDeadPeriod_sportSpecific() {
        XCTAssertTrue(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Baseball", division: "D1"))
        XCTAssertFalse(RecruitingCalendar.isDeadPeriod("2027-07-04", sport: "Tennis", division: "D1"))
    }
}
