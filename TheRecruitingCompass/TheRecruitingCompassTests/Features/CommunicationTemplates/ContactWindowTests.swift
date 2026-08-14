import XCTest
@testable import TheRecruitingCompass

final class ContactWindowTests: XCTestCase {
  private func rule(_ sport: String, _ div: String, _ kind: String,
                    ref: String? = nil, date: String? = nil) -> ContactWindowRule {
    ContactWindowRule(sport: sport, division: div, ruleKind: kind,
                      reference: ref, windowDate: date, notes: nil)
  }
  private func cal(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
  }

  func test_computeOpenDate_dateAfterGrade() {
    let r = rule("football", "D1", "date_after_grade", ref: "sophomore", date: "Sept 1")
    XCTAssertEqual(ContactWindow.computeWindowOpenDate(r, gradYear: 2027), cal(2025, 9, 1))
  }

  func test_computeOpenDate_dateBeforeGrade() {
    let r = rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")
    XCTAssertEqual(ContactWindow.computeWindowOpenDate(r, gradYear: 2027), cal(2025, 8, 1))
  }

  func test_computeOpenDate_unrestrictedOrUnparseable_nil() {
    XCTAssertNil(ContactWindow.computeWindowOpenDate(rule("*", "D3", "unrestricted"), gradYear: 2027))
    XCTAssertNil(ContactWindow.computeWindowOpenDate(
      rule("*", "D1", "date_after_grade", ref: "bogus", date: "Sept 1"), gradYear: 2027))
    XCTAssertNil(ContactWindow.computeWindowOpenDate(
      rule("*", "D1", "date_after_grade", ref: "junior", date: "notadate"), gradYear: 2027))
  }

  func test_evaluate_missingDivisionOrGradYear_failsOpen() {
    let rules = [rule("*", "D1", "date_after_grade", ref: "sophomore", date: "Jun 15")]
    XCTAssertEqual(ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: nil, gradYear: 2027, today: cal(2024, 1, 1))).state, .open)
    XCTAssertEqual(ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: "D1", gradYear: nil, today: cal(2024, 1, 1))).state, .open)
  }

  func test_evaluate_prefersExactSportOverWildcard() {
    let rules = [
      rule("*", "D1", "date_after_grade", ref: "sophomore", date: "Jun 15"),
      rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")
    ]
    let res = ContactWindow.evaluate(rules: rules,
      input: .init(sport: "Baseball", division: "D1", gradYear: 2027, today: cal(2024, 1, 1)))
    XCTAssertEqual(res.rule?.ruleKind, "date_before_grade")
    XCTAssertEqual(res.state, .pre)
  }

  func test_evaluate_afterOpenDate_isOpen() {
    let rules = [rule("baseball", "D1", "date_before_grade", ref: "junior", date: "Aug 1")]
    let res = ContactWindow.evaluate(rules: rules,
      input: .init(sport: "baseball", division: "D1", gradYear: 2027, today: cal(2026, 1, 1)))
    XCTAssertEqual(res.state, .open)
  }

  func test_evaluate_noMatchingRule_failsOpen() {
    let res = ContactWindow.evaluate(rules: [rule("*", "D2", "unrestricted")],
      input: .init(sport: "baseball", division: "D1", gradYear: 2027, today: cal(2024, 1, 1)))
    XCTAssertEqual(res.state, .open)
    XCTAssertNil(res.rule)
  }

  private struct T { let type: String; let stage: String; let window: String? }
  private func filt(_ items: [T], _ state: ContactWindowState) -> [T] {
    ContactWindow.filterByWindow(items, state: state,
      group: { "\($0.type):\($0.stage)" }, window: { $0.window })
  }

  func test_filter_open_hidesPreTemplates() {
    let items = [T(type: "email", stage: "intro", window: "pre"),
                 T(type: "email", stage: "intro", window: "any")]
    XCTAssertEqual(filt(items, .open).map(\.window), ["any"])
  }

  func test_filter_pre_hidesAnyWhenPreSiblingExists() {
    let items = [T(type: "email", stage: "intro", window: "pre"),
                 T(type: "email", stage: "intro", window: "any"),
                 T(type: "email", stage: "followup", window: "any")]
    let kept = filt(items, .pre)
    XCTAssertEqual(kept.map { "\($0.stage):\($0.window ?? "")" }, ["intro:pre", "followup:any"])
  }
}
