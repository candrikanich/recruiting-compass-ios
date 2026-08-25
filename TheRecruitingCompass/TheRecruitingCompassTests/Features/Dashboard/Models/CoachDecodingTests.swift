import XCTest
@testable import TheRecruitingCompass

final class CoachDecodingTests: XCTestCase {
  nonisolated deinit {}

  private func decode(_ json: String) throws -> Coach {
    try JSONDecoder().decode(Coach.self, from: Data(json.utf8))
  }

  func testDecode_withTagsAndSource() throws {
    let coach = try decode(#"""
    {"id":"c1","first_name":"Dana","last_name":"Whitfield","school_id":"s1",
     "created_at":"2026-01-15T00:00:00Z","updated_at":"2026-08-10T00:00:00Z",
     "tags":["Football","Division I"],"source":"LinkedIn"}
    """#)
    XCTAssertEqual(coach.tags, ["Football", "Division I"])
    XCTAssertEqual(coach.source, "LinkedIn")
  }

  func testDecode_missingTagsAndSource_defaults() throws {
    let coach = try decode(#"""
    {"id":"c1","first_name":"Dana","last_name":"Whitfield","school_id":"s1",
     "created_at":"2026-01-15T00:00:00Z","updated_at":"2026-08-10T00:00:00Z"}
    """#)
    XCTAssertEqual(coach.tags, [])
    XCTAssertNil(coach.source)
  }
}
