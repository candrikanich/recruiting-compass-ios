import XCTest
@testable import TheRecruitingCompass

/// The school list tile shows `displayLocation`. Most stored schools have no `location` or `city`, only
/// `state` plus College Scorecard city/state in `academic_info`, so the tile must fall back to those.
final class SchoolDisplayLocationTests: XCTestCase {
  func testPrefersFreeTextLocation() throws {
    let school = try makeSchool(location: "Oxford, OH", city: "Oxford", state: "OH")
    XCTAssertEqual(school.displayLocation, "Oxford, OH")
  }

  func testFallsBackToSchoolCityAndState() throws {
    let school = try makeSchool(city: "Alliance", state: "OH")
    XCTAssertEqual(school.displayLocation, "Alliance, OH")
  }

  func testFallsBackToAcademicInfoCityWhenOnlyStateIsStored() throws {
    // The common production shape: state on the row, city only in Scorecard data.
    let school = try makeSchool(state: "OH", academicInfo: ["city": "Alliance", "state": "OH"])
    XCTAssertEqual(school.displayLocation, "Alliance, OH")
  }

  func testUsesAcademicInfoWhenRowHasNoLocationFields() throws {
    let school = try makeSchool(academicInfo: ["city": "Muncie", "state": "IN"])
    XCTAssertEqual(school.displayLocation, "Muncie, IN")
  }

  func testTreatsBlankStringsAsMissing() throws {
    let school = try makeSchool(location: "  ", city: "", state: "OH", academicInfo: ["city": "Ada"])
    XCTAssertEqual(school.displayLocation, "Ada, OH")
  }

  func testStateOnly() throws {
    let school = try makeSchool(state: "OH")
    XCTAssertEqual(school.displayLocation, "OH")
  }

  func testNilWhenNothingIsKnown() throws {
    let school = try makeSchool()
    XCTAssertNil(school.displayLocation)
  }

  // MARK: - Helpers

  private func makeSchool(
    location: String? = nil,
    city: String? = nil,
    state: String? = nil,
    academicInfo: [String: String]? = nil
  ) throws -> School {
    var json: [String: Any] = [
      "id": "school-1",
      "user_id": "user-1",
      "name": "Test University",
      "status": "researching",
      "family_unit_id": "family-1",
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z"
    ]
    json["location"] = location
    json["city"] = city
    json["state"] = state
    json["academic_info"] = academicInfo
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(School.self, from: data)
  }
}
