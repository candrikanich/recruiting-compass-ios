import XCTest
@testable import TheRecruitingCompass

final class TemplateEventsTests: XCTestCase {
  private func e(_ name: String, start: String?, end: String? = nil,
                city: String? = nil, state: String? = nil, location: String? = nil) -> EventLite {
    EventLite(name: name, startDate: start, endDate: end, location: location,
              city: city, state: state, url: nil)
  }
  private let now = ISO8601DateFormatter().date(from: "2026-08-14T00:00:00Z")!

  func test_selectUpcomingFiltersPastSortsSoonestCaps() {
    let events = [
      e("Past", start: "2026-01-01", end: "2026-01-02"),
      e("Soon", start: "2026-09-01"),
      e("Later", start: "2026-12-01"),
      e("Today", start: "2026-08-14")
    ]
    let picked = TemplateComputed.selectUpcomingEvents(events, now: now, cap: 5).map { $0.name }
    XCTAssertEqual(picked, ["Today", "Soon", "Later"])
  }

  func test_renderScheduleFormatsRows() {
    let events = [e("Fall Showcase", start: "2026-09-05", city: "Columbus", state: "OH")]
    XCTAssertEqual(TemplateComputed.renderEventSchedule(events, now: now),
                   "- Sep 5 — Fall Showcase, Columbus, OH")
  }

  func test_renderScheduleLocationFallback() {
    let events = [e("Camp", start: "2026-09-05", location: "Ripken Complex")]
    XCTAssertEqual(TemplateComputed.renderEventSchedule(events, now: now),
                   "- Sep 5 — Camp, Ripken Complex")
  }

  func test_nextEventRangeAndSingle() {
    let range = TemplateComputed.nextEvent([e("Series", start: "2026-09-05", end: "2026-09-07")], now: now)
    XCTAssertEqual(range?.name, "Series")
    XCTAssertEqual(range?.dates, "Sep 5–Sep 7")
    let single = TemplateComputed.nextEvent([e("One Day", start: "2026-09-05", end: "2026-09-05")], now: now)
    XCTAssertEqual(single?.dates, "Sep 5")
  }

  func test_emptyScheduleNil() {
    XCTAssertNil(TemplateComputed.renderEventSchedule([], now: now))
    XCTAssertNil(TemplateComputed.nextEvent([], now: now))
  }
}
