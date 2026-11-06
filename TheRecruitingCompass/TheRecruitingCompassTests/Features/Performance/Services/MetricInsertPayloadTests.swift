import XCTest
@testable import TheRecruitingCompass

final class MetricInsertPayloadTests: XCTestCase {
  nonisolated deinit {}

  private func json(familyUnitId: String?) throws -> [String: Any] {
    let payload = MetricInsertPayload(
      userId: "u1", familyUnitId: familyUnitId, metricType: "velocity", value: 90, unit: "mph",
      recordedDate: "2026-10-13", verified: false, notes: nil
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
