import XCTest
@testable import TheRecruitingCompass

final class EventLinkedRequestsFamilyStampTests: XCTestCase {
  nonisolated deinit {}

  private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func metric(familyUnitId: String?) -> CreateMetricRequest {
    CreateMetricRequest(
      userId: "u1", familyUnitId: familyUnitId, metricType: "velocity", value: 90, unit: "mph",
      recordedDate: "2026-10-13", eventId: "e1", verified: false, notes: nil
    )
  }

  private func interaction(familyUnitId: String?) -> CreateInteractionRequest {
    CreateInteractionRequest(
      userId: "u1", familyUnitId: familyUnitId, eventId: "e1", coachId: nil,
      type: "email", direction: "outbound", sentiment: nil, notes: nil
    )
  }

  func testMetric_stampsFamilyUnitId() throws {
    XCTAssertEqual(try json(metric(familyUnitId: "fam-1"))["family_unit_id"] as? String, "fam-1")
  }

  func testMetric_nilFamilyUnitId_omitsKey() throws {
    XCTAssertFalse(try json(metric(familyUnitId: nil)).keys.contains("family_unit_id"))
  }

  func testInteraction_stampsFamilyUnitId() throws {
    XCTAssertEqual(try json(interaction(familyUnitId: "fam-1"))["family_unit_id"] as? String, "fam-1")
  }

  func testInteraction_nilFamilyUnitId_omitsKey() throws {
    XCTAssertFalse(try json(interaction(familyUnitId: nil)).keys.contains("family_unit_id"))
  }
}
