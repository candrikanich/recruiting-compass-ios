import XCTest
@testable import TheRecruitingCompass

final class DocumentInsertPayloadTests: XCTestCase {
  nonisolated deinit {}

  private func json(familyUnitId: String?) throws -> [String: Any] {
    let payload = DocumentInsertPayload(
      userId: "u1", familyUnitId: familyUnitId, uploadedBy: "u1", type: "resume", title: "Resume",
      description: nil, fileUrl: "https://x.invalid/f", fileType: "application/pdf", version: 1,
      schoolId: nil, isCurrent: true, sharedWithSchools: []
    )
    let data = try JSONEncoder().encode(payload)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func testEncode_stampsFamilyUnitId() throws {
    XCTAssertEqual(try json(familyUnitId: "fam-1")["family_unit_id"] as? String, "fam-1")
  }

  func testEncode_nilFamilyUnitId_omitsKey() throws {
    XCTAssertFalse(try json(familyUnitId: nil).keys.contains("family_unit_id"))
  }
}
