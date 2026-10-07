import XCTest
@testable import TheRecruitingCompass

final class InteractionTrendWindowTests: XCTestCase {
  private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    return calendar
  }()

  // 2026-10-06 15:00 Chicago (CDT, UTC-5)
  private let now = ISO8601DateFormatter().date(from: "2026-10-06T20:00:00Z")!

  private func makeInteraction(id: String, occurredAt: String?, createdAt: String = "2026-10-05T12:00:00Z")
    -> Interaction {
    Interaction(
      id: id, type: .email, direction: .outbound, schoolId: nil, coachId: nil, subject: nil, content: nil,
      sentiment: nil, occurredAt: occurredAt, loggedBy: "u", attachments: nil, familyUnitId: "f",
      createdAt: createdAt, updatedAt: nil
    )
  }

  private func summarize(_ interactions: [Interaction]) -> InteractionTrendSummary {
    InteractionTrendWindow.summarize(interactions, now: now, calendar: calendar)
  }

  func testCountsOnlyInteractionsInsideWindow() {
    let summary = summarize([
      makeInteraction(id: "a", occurredAt: "2026-10-06T10:00:00Z"),
      makeInteraction(id: "b", occurredAt: "2026-10-06T11:00:00Z"),
      makeInteraction(id: "c", occurredAt: "2026-09-20T10:00:00Z"),
      makeInteraction(id: "old", occurredAt: "2025-01-01T10:00:00Z")
    ])

    XCTAssertEqual(summary.total, 3)
    XCTAssertEqual(summary.trends.map(\.id), ["2026-09-20", "2026-10-06"])
    XCTAssertEqual(summary.trends.map(\.count), [1, 2])
  }

  func testWindowIsThirtyCalendarDaysTodayInclusive() {
    // Today is Oct 6, so the window starts Sep 7 (Oct 6 minus 29 days) at local midnight.
    let summary = summarize([
      makeInteraction(id: "first-day", occurredAt: "2026-09-07T05:30:00Z"),  // Sep 7 00:30 local
      makeInteraction(id: "day-before", occurredAt: "2026-09-07T04:30:00Z")  // Sep 6 23:30 local
    ])

    XCTAssertEqual(summary.total, 1)
    XCTAssertEqual(summary.trends.map(\.id), ["2026-09-07"])
  }

  func testBucketsByUserTimeZoneDay() {
    // 02:00 UTC on Oct 6 is still Oct 5 in Chicago.
    let summary = summarize([makeInteraction(id: "a", occurredAt: "2026-10-06T02:00:00Z")])

    XCTAssertEqual(summary.trends.map(\.id), ["2026-10-05"])
  }

  func testFallsBackToCreatedAtOnlyWhenOccurredAtIsNil() {
    let summary = summarize([
      makeInteraction(id: "nil-occurred", occurredAt: nil, createdAt: "2026-10-01T12:00:00Z"),
      makeInteraction(id: "old-occurred", occurredAt: "2025-01-01T12:00:00Z", createdAt: "2026-10-01T12:00:00Z")
    ])

    XCTAssertEqual(summary.total, 1)
    XCTAssertEqual(summary.trends.map(\.id), ["2026-10-01"])
  }

  func testEmptyWindowWithOlderInteractionsReportsMostRecentOccurredAt() {
    let summary = summarize([
      makeInteraction(id: "older", occurredAt: "2026-03-01T12:00:00Z"),
      makeInteraction(id: "newer", occurredAt: "2026-08-15T12:00:00Z")
    ])

    XCTAssertTrue(summary.trends.isEmpty)
    XCTAssertEqual(summary.total, 0)
    XCTAssertEqual(summary.lastInteractionDate, ISO8601DateFormatter().date(from: "2026-08-15T12:00:00Z"))
  }

  func testNoInteractionsAtAllHasNoLastInteractionDate() {
    let summary = summarize([])

    XCTAssertTrue(summary.trends.isEmpty)
    XCTAssertNil(summary.lastInteractionDate)
  }

  func testWindowStartIsLocalMidnightThirtyDaysBack() {
    let start = InteractionTrendWindow.windowStart(now: now, calendar: calendar)

    XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: start),
                   DateComponents(year: 2026, month: 9, day: 7, hour: 0))
  }
}
