import XCTest
@testable import TheRecruitingCompass

final class SchoolStatusHistoryNullActorTests: XCTestCase {
  func testDecode_nullChangedBy_decodesWithNilActor() throws {
    let json = Data("""
    {"id":"h1","school_id":"s1","new_status":"interested","previous_status":null,"notes":null,
     "changed_at":"2026-02-10T10:00:00.000Z","changed_by":null,"created_at":"2026-02-10T10:00:00.000Z"}
    """.utf8)

    let history = try JSONDecoder().decode(SchoolStatusHistory.self, from: json)

    XCTAssertNil(history.changedBy)
  }

  func testDecode_missingChangedBy_decodesWithNilActor() throws {
    let json = Data("""
    {"id":"h1","school_id":"s1","new_status":"interested",
     "changed_at":"2026-02-10T10:00:00Z","created_at":"2026-02-10T10:00:00Z"}
    """.utf8)

    XCTAssertNoThrow(try JSONDecoder().decode(SchoolStatusHistory.self, from: json))
  }
}
