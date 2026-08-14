import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableDefTests: XCTestCase {
  func test_decodesColumnRow() throws {
    let json = """
    {"key":"coachFirstName","label":"Coach First Name","category":"program",
     "source_type":"column","source_path":"column:coaches.first_name",
     "is_required_default":false,"sort_order":40}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.key, "coachFirstName")
    XCTAssertEqual(d.sourceType, .column)
    XCTAssertEqual(d.sourcePath, "column:coaches.first_name")
    XCTAssertFalse(d.isRequiredDefault)
  }

  func test_decodesRequiredAuthoredRow() throws {
    let json = """
    {"key":"programNote","label":"Program Note","category":"authored",
     "source_type":"authored","is_required_default":true}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.sourceType, .authored)
    XCTAssertTrue(d.isRequiredDefault)
    XCTAssertNil(d.sourcePath)
  }

  func test_unknownSourceTypeIsFailSoft() throws {
    let json = """
    {"key":"weird","label":"W","category":"system","source_type":"quantum"}
    """
    let d = try JSONDecoder().decode(TemplateVariableDef.self, from: Data(json.utf8))
    XCTAssertEqual(d.sourceType, .unknown)
    XCTAssertFalse(d.isRequiredDefault, "missing is_required_default defaults to false")
  }

  func test_arrayWithBadRowDoesNotThrow() throws {
    let json = """
    [{"key":"a","label":"A","category":"system","source_type":"system"},
     {"key":"b","label":"B","category":"x","source_type":"???"}]
    """
    let list = try JSONDecoder().decode([TemplateVariableDef].self, from: Data(json.utf8))
    XCTAssertEqual(list.map(\.sourceType), [.system, .unknown])
  }
}
