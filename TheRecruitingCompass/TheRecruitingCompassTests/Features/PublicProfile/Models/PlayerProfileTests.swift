import XCTest
@testable import TheRecruitingCompass

final class PlayerProfileTests: XCTestCase {
    nonisolated deinit {}

    func testDecodesSnakeCaseRowFromAPI() throws {
        let json = """
        {
          "id": "p1", "user_id": "u1", "family_unit_id": "f1",
          "hash_slug": "ab12cd", "vanity_slug": null, "is_published": false,
          "bio": null, "header_color": "slate",
          "show_academics": true, "show_athletic": true,
          "show_film": true, "show_schools": true,
          "created_at": "2026-08-10T00:00:00Z", "updated_at": "2026-08-10T00:00:00Z"
        }
        """.data(using: .utf8)!
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: json)
        XCTAssertEqual(profile.hashSlug, "ab12cd")
        XCTAssertNil(profile.vanitySlug)
        XCTAssertFalse(profile.isPublished)
        XCTAssertEqual(profile.headerColor, "slate")
        XCTAssertTrue(profile.showFilm)
    }

    func testUpdatePayloadOmitsNilFields() throws {
        let payload = UpdateProfilePayload(isPublished: true)
        let data = try JSONEncoder().encode(payload)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["is_published"] as? Bool, true)
        XCTAssertNil(obj["bio"])
        XCTAssertNil(obj["vanity_slug"])
    }

    func testTrackingLinkDecodes() throws {
        let json = """
        {"id":"t1","profile_id":"p1","coach_id":"c1","ref_token":"a1b2c3d4",
         "view_count":3,"last_viewed_at":null,"created_at":"2026-08-10T00:00:00Z"}
        """.data(using: .utf8)!
        let link = try JSONDecoder().decode(ProfileTrackingLink.self, from: json)
        XCTAssertEqual(link.refToken, "a1b2c3d4")
        XCTAssertEqual(link.viewCount, 3)
        XCTAssertNil(link.lastViewedAt)
    }

    func testUpdatePayloadEmitsNullWhenInnerNil() throws {
        let data = try JSONEncoder().encode(UpdateProfilePayload(bio: .some(nil)))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(obj.keys.contains("bio"))
        XCTAssertTrue(obj["bio"] is NSNull)
    }

    func testUpdatePayloadEmitsNullForVanitySlugWhenInnerNil() throws {
        let data = try JSONEncoder().encode(
            UpdateProfilePayload(vanitySlug: .some(nil))
        )
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(obj.keys.contains("vanity_slug"))
        XCTAssertTrue(obj["vanity_slug"] is NSNull)
    }
}
