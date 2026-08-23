import XCTest
@testable import TheRecruitingCompass

final class CoachMetricsCalculatorTests: XCTestCase {

  private let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private func hoursAgo(_ hours: Double) -> String {
    iso.string(from: Date(timeIntervalSinceNow: -hours * 3600))
  }

  private func interaction(
    id: String,
    coachId: String = "coach-1",
    type: InteractionType = .email,
    direction: Direction = .outbound,
    sentiment: Sentiment? = .neutral,
    occurredAt: String
  ) -> Interaction {
    Interaction(
      id: id, type: type, direction: direction, schoolId: "school-1", coachId: coachId,
      subject: "Subject", content: "Body", sentiment: sentiment, occurredAt: occurredAt,
      loggedBy: "user-1", attachments: nil, familyUnitId: "family-1",
      createdAt: occurredAt, updatedAt: nil
    )
  }

  private func coach(id: String, schoolId: String = "school-1") -> Coach {
    Coach(
      id: id, firstName: "A", lastName: "B", schoolId: schoolId,
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z"
    )
  }

  // MARK: - metrics

  func testMetrics_countsAndResponseRate() {
    let interactions = [
      interaction(id: "1", direction: .inbound, occurredAt: hoursAgo(1)),
      interaction(id: "2", direction: .inbound, occurredAt: hoursAgo(3)),
      interaction(id: "3", direction: .outbound, occurredAt: hoursAgo(5)),
      interaction(id: "4", direction: .outbound, occurredAt: hoursAgo(7))
    ]
    let m = CoachMetricsCalculator.metrics(for: "coach-1", in: interactions)
    XCTAssertEqual(m.totalInteractions, 4)
    XCTAssertEqual(m.outboundCount, 2)
    XCTAssertEqual(m.inboundCount, 2)
    XCTAssertEqual(m.responseRate, 100) // 2 inbound / 2 outbound
  }

  func testMetrics_zeroOutbound_isZeroResponseRate() {
    let interactions = [
      interaction(id: "1", direction: .inbound, occurredAt: hoursAgo(1)),
      interaction(id: "2", direction: .inbound, occurredAt: hoursAgo(2))
    ]
    let m = CoachMetricsCalculator.metrics(for: "coach-1", in: interactions)
    XCTAssertEqual(m.responseRate, 0)
  }

  func testMetrics_noInteractions_daysSinceContactIsNegativeOne() {
    let m = CoachMetricsCalculator.metrics(for: "coach-1", in: [])
    XCTAssertEqual(m.totalInteractions, 0)
    XCTAssertEqual(m.daysSinceContact, -1)
    XCTAssertEqual(m.averageResponseTime, 0)
  }

  func testMetrics_preferredMethodIsMostFrequentInbound() {
    let interactions = [
      interaction(id: "1", type: .email, direction: .inbound, occurredAt: hoursAgo(1)),
      interaction(id: "2", type: .email, direction: .inbound, occurredAt: hoursAgo(2)),
      interaction(id: "3", type: .phoneCall, direction: .inbound, occurredAt: hoursAgo(3))
    ]
    let m = CoachMetricsCalculator.metrics(for: "coach-1", in: interactions)
    XCTAssertEqual(m.preferredMethod, InteractionType.email.displayName)
  }

  func testMetrics_defaultsToEmailWithoutInbound() {
    let interactions = [interaction(id: "1", direction: .outbound, occurredAt: hoursAgo(1))]
    let m = CoachMetricsCalculator.metrics(for: "coach-1", in: interactions)
    XCTAssertEqual(m.preferredMethod, InteractionType.email.displayName)
  }

  func testMetrics_ignoresOtherCoaches() {
    let interactions = [
      interaction(id: "1", coachId: "coach-1", occurredAt: hoursAgo(1)),
      interaction(id: "2", coachId: "coach-2", occurredAt: hoursAgo(2))
    ]
    XCTAssertEqual(CoachMetricsCalculator.metrics(for: "coach-1", in: interactions).totalInteractions, 1)
  }

  // MARK: - comparison

  func testComparison_nilWithoutSchool() {
    XCTAssertNil(CoachMetricsCalculator.comparison(for: "coach-1", schoolId: nil, interactions: [], coaches: []))
  }

  func testComparison_ranksAcrossSchoolCoaches() {
    let coaches = [coach(id: "coach-1"), coach(id: "coach-2"), coach(id: "coach-3")]
    let interactions = [
      // coach-1: 1 out, 1 in -> 100%
      interaction(id: "a", coachId: "coach-1", direction: .inbound, occurredAt: hoursAgo(1)),
      interaction(id: "b", coachId: "coach-1", direction: .outbound, occurredAt: hoursAgo(2)),
      // coach-2: 1 out, 0 in -> 0%
      interaction(id: "c", coachId: "coach-2", direction: .outbound, occurredAt: hoursAgo(3)),
      // coach-3: 1 out, 0 in -> 0%
      interaction(id: "d", coachId: "coach-3", direction: .outbound, occurredAt: hoursAgo(4))
    ]
    let comp = CoachMetricsCalculator.comparison(for: "coach-1", schoolId: "school-1", interactions: interactions, coaches: coaches)
    XCTAssertNotNil(comp)
    XCTAssertEqual(comp?.totalCoaches, 3)
    XCTAssertEqual(comp?.rank, 1) // best response rate
  }

  // MARK: - insights

  func testInsights_flagsStaleContact() {
    let interactions = [interaction(id: "1", occurredAt: hoursAgo(24 * 60))]
    let insights = CoachMetricsCalculator.insights(for: "coach-1", in: interactions)
    XCTAssertTrue(insights.contains { $0.contains("No contact") })
  }

  func testInsights_reportsPreferredMethod() {
    let interactions = [
      interaction(id: "1", type: .phoneCall, direction: .inbound, occurredAt: hoursAgo(1)),
      interaction(id: "2", type: .phoneCall, direction: .inbound, occurredAt: hoursAgo(2))
    ]
    let insights = CoachMetricsCalculator.insights(for: "coach-1", in: interactions)
    XCTAssertTrue(insights.contains { $0.contains(InteractionType.phoneCall.displayName) })
  }
}
