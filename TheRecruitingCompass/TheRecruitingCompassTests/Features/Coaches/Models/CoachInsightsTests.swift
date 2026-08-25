import XCTest
@testable import TheRecruitingCompass

final class CoachInsightsTests: XCTestCase {
  nonisolated deinit {}

  private let now = ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z")!

  private func interaction(
    _ id: String, type: InteractionType = .email, direction: Direction = .outbound, daysAgo: Int
  ) -> Interaction {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
    let iso = ISO8601DateFormatter().string(from: date)
    return Interaction(
      id: id, type: type, direction: direction, schoolId: "s1", coachId: "c1",
      subject: nil, content: nil, sentiment: nil, occurredAt: iso, loggedBy: "u1",
      attachments: nil, familyUnitId: "f1", createdAt: iso, updatedAt: nil)
  }

  private func coach(lastContactDaysAgo: Int?) -> Coach {
    let last = lastContactDaysAgo.map {
      ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -$0, to: now)!)
    }
    return Coach(id: "c1", firstName: "Dana", lastName: "Whitfield", schoolId: "s1",
                 lastContactDate: last, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-08-01T00:00:00Z")
  }

  func testOverdueBoundary_14NotOverdue_15Overdue() {
    let notOverdue = CoachInsights.make(coach: coach(lastContactDaysAgo: 14), interactions: [], now: now)
    XCTAssertEqual(notOverdue.daysSinceContact, 14)
    XCTAssertFalse(notOverdue.isOverdue)
    let overdue = CoachInsights.make(coach: coach(lastContactDaysAgo: 15), interactions: [], now: now)
    XCTAssertTrue(overdue.isOverdue)
  }

  func testDaysSince_prefersNewestInteractionOverStored() {
    let i = CoachInsights.make(
      coach: coach(lastContactDaysAgo: 30),
      interactions: [interaction("1", daysAgo: 5), interaction("2", daysAgo: 1)], now: now)
    XCTAssertEqual(i.daysSinceContact, 1)
  }

  func testSentReceivedAndResponseRate() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 2), interactions: [
      interaction("1", direction: .outbound, daysAgo: 3),
      interaction("2", direction: .inbound, daysAgo: 2),
      interaction("3", direction: .inbound, daysAgo: 1)
    ], now: now)
    XCTAssertEqual(i.sent, 1)
    XCTAssertEqual(i.received, 2)
    XCTAssertEqual(i.responseRate, 67)   // round(2/3*100)
  }

  func testPreferredChannel_modeOfType() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 2), interactions: [
      interaction("1", type: .email, daysAgo: 3),
      interaction("2", type: .email, daysAgo: 2),
      interaction("3", type: .phoneCall, daysAgo: 1)
    ], now: now)
    XCTAssertEqual(i.preferredChannel, .email)
  }

  func testEmpty_nilsAndZeroes() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: nil), interactions: [], now: now)
    XCTAssertNil(i.daysSinceContact)
    XCTAssertFalse(i.isOverdue)
    XCTAssertNil(i.preferredChannel)
    XCTAssertFalse(i.channelPreferenceAlert)
    XCTAssertEqual(i.responseRate, 0)
  }

  func testIgnoresNilOccurredAt() {
    let dateless = Interaction(
      id: "x", type: .email, direction: .outbound, schoolId: "s1", coachId: "c1",
      subject: nil, content: nil, sentiment: nil, occurredAt: nil, loggedBy: "u1",
      attachments: nil, familyUnitId: "f1", createdAt: "2026-08-24T00:00:00Z", updatedAt: nil)
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 7), interactions: [dateless], now: now)
    XCTAssertEqual(i.daysSinceContact, 7)  // falls back to stored, not "today"
  }
}
