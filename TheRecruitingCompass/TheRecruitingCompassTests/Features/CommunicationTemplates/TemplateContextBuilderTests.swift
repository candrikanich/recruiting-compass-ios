import XCTest
@testable import TheRecruitingCompass

final class TemplateContextBuilderTests: XCTestCase {
  private let now = ISO8601DateFormatter().date(from: "2026-08-14T00:00:00Z")!

  func test_derivesSportPositionFromPrefs() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["primary_sport": "Baseball", "primary_position": "Shortstop"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: 2027, now: now)
    XCTAssertEqual(d["sport"], "Baseball")
    XCTAssertEqual(d["position"], "Shortstop")
  }

  func test_profileAndTranscriptAndVideoLinks() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: [], profileSlug: "jordan-lee",
      transcriptURL: "https://x/tr.pdf", videoPrimaryURL: "https://x/film",
      gradYear: nil, now: now)
    XCTAssertEqual(d["profileLink"], "/jordan-lee")
    XCTAssertEqual(d["transcriptLink"], "https://x/tr.pdf")
    XCTAssertEqual(d["videoLink"], "https://x/film")
  }

  func test_gradeAppropriateHsCoach() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["twelfth_grade_coach": "Coach Twelve", "ninth_grade_coach": "Coach Nine"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: 2027, now: now)
    XCTAssertEqual(d["hsCoachName"], "Coach Twelve")
  }

  func test_hsCoachFallbackWhenGradeMissing() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: ["tenth_grade_coach": "Coach Ten"],
      metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertEqual(d["hsCoachName"], "Coach Ten", "falls back 12→9 when grade unknown")
  }

  func test_eventScheduleAndNextEvent() {
    let events = [EventLite(name: "Showcase", startDate: "2026-09-05", endDate: "2026-09-06",
                            location: nil, city: "Columbus", state: "OH", url: nil)]
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: events, profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertEqual(d["eventSchedule"], "- Sep 5 — Showcase, Columbus, OH")
    XCTAssertEqual(d["nextEventName"], "Showcase")
    XCTAssertEqual(d["nextEventDates"], "Sep 5–Sep 6")
  }

  func test_emptyInputsProduceNoKeys() {
    let d = TemplateContextBuilder.buildDerived(
      prefs: [:], metrics: [], events: [], profileSlug: nil, transcriptURL: nil,
      videoPrimaryURL: nil, gradYear: nil, now: now)
    XCTAssertNil(d["sport"])
    XCTAssertNil(d["hsCoachName"])
    XCTAssertNil(d["eventSchedule"])
  }
}
