import XCTest
@testable import TheRecruitingCompass

final class VideoLinkModelTests: XCTestCase {
  private func decode(_ json: String) throws -> VideoLink {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return try d.decode(VideoLink.self, from: Data(json.utf8))
  }

  func test_decodesSnakeCaseRow() throws {
    let link = try decode("""
    {"id":"v1","user_id":"u1","family_unit_id":"f1","platform":"hudl",
     "url":"https://hudl.com/x","title":"Fall reel","position":0,
     "health_status":"healthy","last_health_check":null,
     "created_at":null,"updated_at":null}
    """)
    XCTAssertEqual(link.id, "v1")
    XCTAssertEqual(link.userId, "u1")
    XCTAssertEqual(link.familyUnitId, "f1")
    XCTAssertEqual(link.platform, .hudl)
    XCTAssertEqual(link.healthStatus, .healthy)
    XCTAssertEqual(link.position, 0)
  }

  func test_unknownPlatformAndHealthFallBack() throws {
    let link = try decode("""
    {"id":"v2","user_id":"u1","family_unit_id":null,"platform":"tiktok",
     "url":"https://x","title":null,"position":1,"health_status":"weird",
     "last_health_check":null,"created_at":null,"updated_at":null}
    """)
    XCTAssertEqual(link.platform, .unknown)
    XCTAssertEqual(link.healthStatus, .unknown)
    XCTAssertNil(link.title)
    XCTAssertNil(link.familyUnitId)
  }

  func test_decodesOtherPlatform() throws {
    let link = try decode("""
    {"id":"v3","user_id":"u1","family_unit_id":null,"platform":"other",
     "url":"https://drive.example/x","title":null,"position":0,"health_status":"healthy",
     "last_health_check":null,"created_at":null,"updated_at":null}
    """)
    XCTAssertEqual(link.platform, .other)
    XCTAssertEqual(link.platform.displayName, "Other")
  }

  func test_otherPlatformEncodesToDBAllowedRawValue() throws {
    // DB CHECK allows only hudl/youtube/vimeo/other — the user-chosen catch-all
    // must persist as "other", never "unknown".
    XCTAssertEqual(VideoLinkPlatform.other.rawValue, "other")
    XCTAssertTrue(VideoLinkPlatform.selectable.contains(.other))
    XCTAssertFalse(VideoLinkPlatform.selectable.contains(.unknown))
  }
}
