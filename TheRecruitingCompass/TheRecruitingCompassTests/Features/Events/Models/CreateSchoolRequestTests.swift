import XCTest
@testable import TheRecruitingCompass

final class CreateSchoolRequestTests: XCTestCase {
  nonisolated deinit {}

  private func json(_ request: CreateSchoolRequest) throws -> [String: Any] {
    let data = try JSONEncoder().encode(request)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func testEncode_nilFamilyUnitId_omitsKey() throws {
    let request = CreateSchoolRequest(
      name: "Oregon State", location: nil, userId: "u1", familyUnitId: nil, status: "researching"
    )

    let payload = try json(request)

    XCTAssertFalse(payload.keys.contains("family_unit_id"))
    XCTAssertEqual(payload["user_id"] as? String, "u1")
  }

  func testEncode_familyUnitId_isStamped() throws {
    let request = CreateSchoolRequest(
      name: "Oregon State", location: nil, userId: "u1", familyUnitId: "fam-1", status: "researching"
    )

    XCTAssertEqual(try json(request)["family_unit_id"] as? String, "fam-1")
  }
}
