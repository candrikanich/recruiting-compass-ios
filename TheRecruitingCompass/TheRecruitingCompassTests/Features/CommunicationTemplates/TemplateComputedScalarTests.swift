import XCTest
@testable import TheRecruitingCompass

final class TemplateComputedScalarTests: XCTestCase {
  private func ctx(users: [String: String] = [:], coaches: [String: String] = [:],
                   schools: [String: String] = [:], now: Date = Date(timeIntervalSince1970: 0)) -> ResolverContext {
    ResolverContext(tables: ["users": users, "coaches": coaches, "schools": schools],
                    prefs: [:], authored: [:], derived: [:], metrics: [], events: [], now: now)
  }

  private func iso(_ s: String) -> Date {
    ISO8601DateFormatter().date(from: s)!
  }

  func test_playerFirstName() {
    XCTAssertEqual(TemplateResolver.computed["playerFirstName"]?(ctx(users: ["full_name": "Jordan Lee"])), "Jordan")
  }

  func test_heightInchesToFeetInches() {
    XCTAssertEqual(TemplateResolver.computed["height"]?(ctx(users: ["height_inches": "74"])), "6'2\"")
    XCTAssertNil(TemplateResolver.computed["height"]?(ctx(users: [:])))
  }

  func test_weight() {
    XCTAssertEqual(TemplateResolver.computed["weight"]?(ctx(users: ["weight_lbs": "185"])), "185 lbs")
  }

  func test_coachSalutation() {
    XCTAssertEqual(TemplateResolver.computed["coachSalutation"]?(ctx(coaches: ["last_name": "Smith"])), "Coach Smith")
  }

  func test_schoolShortName_stripsUniversityCollege() {
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "Wooster College"])), "Wooster")
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "Duke University"])), "Duke")
    XCTAssertEqual(TemplateResolver.computed["schoolShortName"]?(ctx(schools: ["name": "MIT"])), "MIT")
  }

  func test_testLabelAndScorePreferACT() {
    let c = ctx(users: ["act_score": "31", "sat_score": "1350"])
    XCTAssertEqual(TemplateResolver.computed["testLabel"]?(c), "ACT")
    XCTAssertEqual(TemplateResolver.computed["testScore"]?(c), "31")
    let satOnly = ctx(users: ["sat_score": "1350"])
    XCTAssertEqual(TemplateResolver.computed["testLabel"]?(satOnly), "SAT")
    XCTAssertEqual(TemplateResolver.computed["testScore"]?(satOnly), "1350")
  }

  func test_seasonLabelByMonthUTC() {
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: Date(timeIntervalSince1970: 0))), "winter")
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-05-15T12:00:00Z"))), "spring")
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-08-15T12:00:00Z"))), "summer")
    XCTAssertEqual(TemplateResolver.computed["seasonLabel"]?(ctx(now: iso("2026-10-15T12:00:00Z"))), "fall")
  }

  func test_todayDateLongUTC() {
    XCTAssertEqual(TemplateResolver.computed["todayDate"]?(ctx(now: iso("2026-08-14T00:00:00Z"))), "August 14, 2026")
  }
}
