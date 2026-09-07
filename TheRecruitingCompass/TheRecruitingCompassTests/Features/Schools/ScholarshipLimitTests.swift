import XCTest
@testable import TheRecruitingCompass

final class ScholarshipLimitTests: XCTestCase {
  private let baseballD1 = ScholarshipLimit(
    sport: "Baseball", division: "D1", total: 11.7, headCount: nil, equivalency: 11.7, notes: nil
  )
  private let footballD1 = ScholarshipLimit(
    sport: "Football", division: "D1", total: 85, headCount: 85, equivalency: nil, notes: nil
  )

  func test_decodesSnakeCaseColumns() throws {
    let json = Data("""
    {"sport":"Baseball","division":"D1","total":11.7,"head_count":null,"equivalency":11.7,"notes":"n"}
    """.utf8)
    let limit = try JSONDecoder().decode(ScholarshipLimit.self, from: json)
    XCTAssertEqual(limit.headCount, nil)
    XCTAssertEqual(limit.equivalency, 11.7)
  }

  func test_selectMatchesExactSportAndDivisionCaseInsensitiveSport() {
    let rows = [baseballD1, footballD1]
    XCTAssertEqual(selectScholarshipLimit(rows, sport: "baseball", division: "D1"), baseballD1)
    XCTAssertEqual(selectScholarshipLimit(rows, sport: "BASEBALL", division: "D1"), baseballD1)
  }

  func test_selectReturnsNilOnDivisionOrSportMismatch() {
    let rows = [baseballD1]
    XCTAssertNil(selectScholarshipLimit(rows, sport: "Baseball", division: "D2"))
    XCTAssertNil(selectScholarshipLimit(rows, sport: "Softball", division: "D1"))
  }

  func test_selectReturnsNilOnMissingInput() {
    XCTAssertNil(selectScholarshipLimit([baseballD1], sport: nil, division: "D1"))
    XCTAssertNil(selectScholarshipLimit([baseballD1], sport: "Baseball", division: nil))
  }

  func test_formatEquivalencySport() {
    XCTAssertEqual(
      formatScholarshipLine(baseballD1, sport: "Baseball", division: "D1"),
      "Athletic Scholarships: 11.7 equivalency (D1 Baseball)"
    )
  }

  func test_formatHeadCountSport() {
    XCTAssertEqual(
      formatScholarshipLine(footballD1, sport: "Football", division: "D1"),
      "Athletic Scholarships: 85 head-count (D1 Football)"
    )
  }
}
