import XCTest
@testable import TheRecruitingCompass

struct MockContactWindowService: ContactWindowServicing {
  let rules: [ContactWindowRule]
  func fetchRules() async throws -> [ContactWindowRule] { rules }
}

final class ContactWindowServiceTests: XCTestCase {
  func test_mockReturnsInjectedRules() async throws {
    let svc = MockContactWindowService(rules: [
      ContactWindowRule(sport: "*", division: "D1", ruleKind: "unrestricted",
                        reference: nil, windowDate: nil, notes: nil)])
    let rules = try await svc.fetchRules()
    XCTAssertEqual(rules.count, 1)
    XCTAssertEqual(rules.first?.division, "D1")
  }

  func test_ruleDecodesSnakeCaseColumns() throws {
    let json = Data("""
    {"sport":"baseball","division":"D1","rule_kind":"date_before_grade",
     "reference":"junior","window_date":"Aug 1","notes":"n"}
    """.utf8)
    let rule = try JSONDecoder().decode(ContactWindowRule.self, from: json)
    XCTAssertEqual(rule.ruleKind, "date_before_grade")
    XCTAssertEqual(rule.windowDate, "Aug 1")
  }

  func test_implFailsOpenOnFetchError() async throws {
    let svc = ContactWindowServiceImpl(fetch: {
      throw NSError(domain: "test", code: 1)
    })
    let rules = try await svc.fetchRules()
    XCTAssertTrue(rules.isEmpty)
  }
}
