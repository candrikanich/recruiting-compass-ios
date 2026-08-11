import XCTest
@testable import TheRecruitingCompass

final class CoachFollowupTests: XCTestCase {

  /// 2026-01-15 12:00:00 UTC — fixed "now" so tests are deterministic.
  private let now = Date(timeIntervalSince1970: 1_768_478_400)

  private func coach(id: String, lastContact: String?) -> Coach {
    Coach(
      id: id, firstName: "C\(id)", lastName: "L",
      schoolId: "s1", lastContactDate: lastContact,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  /// ISO string `days` before `now`.
  private func iso(daysAgo days: Int) -> String {
    let d = Calendar.current.date(byAdding: .day, value: -days, to: now)!
    let f = ISO8601DateFormatter()
    return f.string(from: d)
  }

  func testNeverContactedNeedsFollowup() {
    XCTAssertTrue(CoachFollowup.needsFollowup(coach(id: "1", lastContact: nil), asOf: now))
  }

  func testThirteenDaysAgoIsNotStale() {
    XCTAssertFalse(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 13)), asOf: now))
  }

  func testFourteenDaysAgoIsNotStale() {
    // Boundary: exactly 14 days ago is NOT stale (strictly older than cutoff required).
    XCTAssertFalse(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 14)), asOf: now))
  }

  func testFifteenDaysAgoIsStale() {
    XCTAssertTrue(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 15)), asOf: now))
  }

  func testStaleFiltersAndSortsNeverFirstThenOldest() {
    let recent = coach(id: "recent", lastContact: iso(daysAgo: 2))   // excluded
    let never = coach(id: "never", lastContact: nil)                 // included, first
    let old20 = coach(id: "old20", lastContact: iso(daysAgo: 20))    // included
    let old40 = coach(id: "old40", lastContact: iso(daysAgo: 40))    // included, oldest

    let result = CoachFollowup.stale([recent, never, old20, old40], asOf: now)

    XCTAssertEqual(result.map(\.id), ["never", "old40", "old20"])
  }

  func testDaysSinceLabelNever() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: nil), asOf: now),
                   String(localized: "Never contacted"))
  }

  func testDaysSinceLabelPlural() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: iso(daysAgo: 20)), asOf: now),
                   String(localized: "20 days ago"))
  }

  func testDaysSinceLabelSingular() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: iso(daysAgo: 1)), asOf: now),
                   String(localized: "1 day ago"))
  }
}
