import XCTest
@testable import TheRecruitingCompass

/// The edit-coach save sends `CoachUpdateRequest` straight to PostgREST, which rejects the whole update
/// (PGRST204) if any key is not a `coaches` column. These tests pin the wire format to the real table.
final class CoachUpdateRequestTests: XCTestCase {
  /// `public.coaches` columns (web repo migrations, including 20261003000000).
  private static let coachesColumns: Set<String> = [
    "id", "user_id", "school_id", "family_unit_id", "first_name", "last_name", "role",
    "email", "phone", "twitter_handle", "instagram_handle", "notes", "tags", "source",
    "last_contact_date", "next_contact_date", "follow_up_threshold_days",
    "created_at", "created_by", "updated_at", "updated_by"
  ]

  private func encodedObject(_ request: CoachUpdateRequest) throws -> [String: Any] {
    let data = try JSONEncoder().encode(request)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func editedCoach() -> EditableCoach {
    EditableCoach(
      firstName: "Pat",
      lastName: "Coach",
      email: "pat@example.edu",
      phone: "555-0100",
      position: "head",
      twitterHandle: "patcoach",
      instagramHandle: "patcoach",
      notes: "Met at camp",
      tags: ["visit"],
      source: "camp",
      nextContactDate: Date(timeIntervalSince1970: 1_793_491_200),
      followUpThresholdDays: 14
    )
  }

  func testEditFormSaveSendsOnlyCoachesColumns() throws {
    let keys = Set(try encodedObject(editedCoach().toUpdateRequest()).keys)

    XCTAssertTrue(
      keys.isSubset(of: Self.coachesColumns),
      "Not columns of public.coaches: \(keys.subtracting(Self.coachesColumns).sorted())"
    )
  }

  func testEditFormSaveSendsTheCoachTypeAsRole() throws {
    let object = try encodedObject(editedCoach().toUpdateRequest())

    XCTAssertEqual(object["role"] as? String, "head")
    XCTAssertNil(object["position"])
  }

  func testEditFormSaveSendsTheFollowUpFields() throws {
    let object = try encodedObject(editedCoach().toUpdateRequest())

    XCTAssertEqual(object["follow_up_threshold_days"] as? Int, 14)
    XCTAssertNotNil(object["next_contact_date"] as? String)
  }

  func testSingleFieldUpdatesSendOnlyThatField() throws {
    let object = try encodedObject(CoachUpdateRequest(tags: ["visit"]))

    XCTAssertEqual(Set(object.keys), ["tags"])
  }

  func testCoachDecodesTheTypeFromRole() throws {
    let json = """
      {"id":"c1","first_name":"Pat","last_name":"Coach","school_id":"s1","role":"recruiting",
       "tags":[],"created_at":"2026-10-03T00:00:00Z","updated_at":"2026-10-03T00:00:00Z"}
      """
    let coach = try JSONDecoder().decode(Coach.self, from: Data(json.utf8))

    XCTAssertEqual(coach.role, .recruiting)
  }
}
