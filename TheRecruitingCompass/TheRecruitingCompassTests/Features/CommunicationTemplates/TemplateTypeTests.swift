import XCTest
@testable import TheRecruitingCompass

final class TemplateTypeTests: XCTestCase {
  private func decode(_ raw: String) throws -> TemplateType {
    try JSONDecoder().decode(TemplateType.self, from: Data("\"\(raw)\"".utf8))
  }

  func test_decodesDBValues() throws {
    XCTAssertEqual(try decode("email"), .email)
    XCTAssertEqual(try decode("message"), .message)
    XCTAssertEqual(try decode("social"), .social)
  }

  func test_mapsLegacyIOSValues() throws {
    XCTAssertEqual(try decode("text"), .message)
    XCTAssertEqual(try decode("twitter"), .social)
  }

  func test_unknownStringDecodesToUnknown_neverThrows() throws {
    XCTAssertEqual(try decode("phone_script"), .unknown)
    XCTAssertEqual(try decode("garbage"), .unknown)
  }

  func test_selectableExcludesUnknown() {
    XCTAssertEqual(TemplateType.selectable, [.email, .message, .social])
    XCTAssertFalse(TemplateType.selectable.contains(.unknown))
  }
}
