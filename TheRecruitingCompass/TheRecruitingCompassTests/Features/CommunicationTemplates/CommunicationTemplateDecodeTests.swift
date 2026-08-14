import XCTest
@testable import TheRecruitingCompass

final class CommunicationTemplateDecodeTests: XCTestCase {
  func test_decodesFullWebRow() throws {
    let json = """
    {"id":"t1","user_id":null,"name":"First contact","type":"email",
     "subject":"{{gradYear}} {{position}}","body":"{{coachSalutation}},",
     "slug":"intro-standard","stage":"intro","contact_window":"any",
     "required_variables":["programNote"],"sort_order":10,"is_predefined":true,
     "created_at":"2026-08-16T00:00:00Z","updated_at":"2026-08-16T00:00:00Z"}
    """
    let t = try JSONDecoder().decode(CommunicationTemplate.self, from: Data(json.utf8))
    XCTAssertEqual(t.type, .email)
    XCTAssertEqual(t.subject, "{{gradYear}} {{position}}")
    XCTAssertEqual(t.slug, "intro-standard")
    XCTAssertEqual(t.stage, "intro")
    XCTAssertEqual(t.contactWindow, "any")
    XCTAssertEqual(t.requiredVariables, ["programNote"])
    XCTAssertEqual(t.sortOrder, 10)
    XCTAssertEqual(t.isPredefined, true)
    XCTAssertEqual(t.userId, "", "null user_id maps to empty string")
  }

  func test_decodesLegacyMinimalRow_noNewKeys() throws {
    let json = """
    {"id":"t2","user_id":"u9","name":"My template","type":"message","body":"hi",
     "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
    """
    let t = try JSONDecoder().decode(CommunicationTemplate.self, from: Data(json.utf8))
    XCTAssertEqual(t.type, .message)
    XCTAssertNil(t.subject)
    XCTAssertNil(t.slug)
    XCTAssertNil(t.requiredVariables)
    XCTAssertNil(t.isPredefined)
  }

  func test_arrayWithMixedTypesDoesNotThrow() throws {
    let json = """
    [{"id":"a","name":"e","type":"email","body":"b","created_at":"","updated_at":""},
     {"id":"b","name":"m","type":"social","body":"b","created_at":"","updated_at":""},
     {"id":"c","name":"x","type":"phone_script","body":"b","created_at":"","updated_at":""}]
    """
    let list = try JSONDecoder().decode([CommunicationTemplate].self, from: Data(json.utf8))
    XCTAssertEqual(list.count, 3)
    XCTAssertEqual(list.map(\.type), [.email, .social, .unknown])
  }
}
