import XCTest
@testable import TheRecruitingCompass

final class TemplateMetricsTests: XCTestCase {
  private func m(_ type: String, _ value: Double? = nil, display: String? = nil,
                primary: Bool = false, verified: Bool = false,
                date: String? = nil, unit: String? = nil, source: String? = nil) -> TemplateMetricRow {
    TemplateMetricRow(metricType: type, value: value, unit: unit, displayValue: display,
              isPrimary: primary, verified: verified, recordedDate: date, source: source)
  }
  private func ctx(_ metrics: [TemplateMetricRow]) -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: [:], derived: [:],
                    metrics: metrics, events: [], now: Date(timeIntervalSince1970: 0))
  }

  func test_renderMetricsRanksPrimaryThenVerifiedThenRecentCap4() {
    let metrics = [
      m("sixty_time", display: "6.8s", date: "2026-01-01"),
      m("exit_velo", display: "95 mph", primary: true, date: "2025-06-01", source: "PBR"),
      m("pop_time", display: "1.9s", verified: true, date: "2025-01-01"),
      m("velocity", display: "88 mph", date: "2026-08-01"),
      m("batting_avg", display: ".410", date: "2024-01-01")
    ]
    let out = TemplateResolver.computed["metrics"]?(ctx(metrics)) ?? ""
    let lines = out.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines.count, 4, "capped at 4")
    XCTAssertEqual(lines[0], "- exit velo: 95 mph (PBR, Jun 2025)", "primary leads, provenance appended")
    XCTAssertEqual(lines[1], "- pop time: 1.9s (Jan 2025)", "verified next; date-only provenance")
    XCTAssertTrue(lines[2].contains("velocity"), "then most recent recorded_date")
  }

  func test_renderMetricsDedupesToMostRecentPerType() {
    let metrics = [
      m("velocity", display: "77 mph", date: "2026-01-01"),
      m("velocity", display: "82 mph", date: "2026-08-01"),   // newer — should win
      m("sixty_time", display: "7.2s", date: "2026-03-01")
    ]
    let out = TemplateResolver.computed["metrics"]?(ctx(metrics)) ?? ""
    let lines = out.split(separator: "\n").map(String.init)
    XCTAssertEqual(lines.count, 2, "one row per metric_type")
    XCTAssertTrue(out.contains("82 mph"), "keeps the most recent velocity")
    XCTAssertFalse(out.contains("77 mph"), "drops the older velocity")
    XCTAssertTrue(out.contains("7.2s"), "unrelated type retained")
  }

  func test_renderMetricsDedupeTieBreaksToVerified() {
    let metrics = [
      m("velocity", display: "80 mph", verified: false, date: "2026-08-01"),
      m("velocity", display: "82 mph", verified: true, date: "2026-08-01")   // same date, verified wins
    ]
    let out = TemplateResolver.computed["metrics"]?(ctx(metrics)) ?? ""
    XCTAssertTrue(out.contains("82 mph"))
    XCTAssertFalse(out.contains("80 mph"))
  }

  func test_carryingToolIsPrimaryValueAndLabel() {
    let out = TemplateResolver.computed["carryingTool"]?(ctx([
      m("exit_velo", display: "95 mph", primary: true),
      m("sixty_time", display: "6.8s")
    ]))
    XCTAssertEqual(out, "95 mph exit velo")
  }

  func test_carryingToolNilWhenNoPrimary() {
    XCTAssertNil(TemplateResolver.computed["carryingTool"]?(ctx([m("sixty_time", display: "6.8s")])))
  }

  func test_metricDisplayFallsBackToValueUnit() {
    let out = TemplateResolver.computed["metrics"]?(ctx([m("velocity", 88, primary: true, unit: "mph")]))
    XCTAssertEqual(out, "- velocity: 88.0 mph")   // type-aware: velocity renders to a tenth
  }

  func test_metricsAsOfLatestMonthYear() {
    let out = TemplateResolver.computed["metricsAsOf"]?(ctx([
      m("a", display: "1", date: "2025-03-10"),
      m("b", display: "2", date: "2026-07-22")
    ]))
    XCTAssertEqual(out, "Jul 2026")
  }

  func test_emptyMetricsNil() {
    XCTAssertNil(TemplateResolver.computed["metrics"]?(ctx([])))
  }
}
