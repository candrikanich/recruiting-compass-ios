import XCTest
@testable import TheRecruitingCompass

final class EditEventDataTimeTests: XCTestCase {
  nonisolated deinit {}

  private func event(start: String?, end: String?, checkin: String?) -> FullEvent {
    FullEvent(
      id: "e1", name: "Showcase", type: "showcase", schoolId: nil, location: nil, address: nil,
      city: nil, state: nil, startDate: "2026-12-01", startTime: start, endDate: nil, endTime: end,
      checkinTime: checkin, url: nil, description: nil, eventSource: nil, cost: nil,
      registered: false, attended: false, performanceNotes: nil, userId: "u1",
      createdAt: "2026-11-01", coachesPresent: nil, updatedAt: "2026-11-01"
    )
  }

  private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func testFrom_normalizesSecondsToHHmm() {
    let data = EditEventData.from(event(start: "14:30:00", end: "16:00:00", checkin: "13:45:00"))
    XCTAssertEqual(data.startTime, "14:30")
    XCTAssertEqual(data.endTime, "16:00")
    XCTAssertEqual(data.checkinTime, "13:45")
  }

  func testUpdateRequest_sendsCheckinTime() throws {
    let data = EditEventData.from(event(start: "14:30:00", end: nil, checkin: "13:45:00"))
    XCTAssertEqual(try json(data.toUpdateRequest())["checkin_time"] as? String, "13:45")
  }

  func testUpdateRequest_clearedTimes_encodeExplicitNull() throws {
    var data = EditEventData.from(event(start: "14:30:00", end: "16:00:00", checkin: "13:45:00"))
    data.endTime = ""
    data.checkinTime = ""
    let body = try json(data.toUpdateRequest())
    XCTAssertTrue(body["end_time"] is NSNull)
    XCTAssertTrue(body["checkin_time"] is NSNull)
    XCTAssertEqual(body["start_time"] as? String, "14:30")
  }

  func testPartialUpdate_doesNotTouchTimes() throws {
    let body = try json(EventUpdateRequest(attended: true))
    XCTAssertFalse(body.keys.contains("start_time"))
    XCTAssertFalse(body.keys.contains("end_time"))
    XCTAssertFalse(body.keys.contains("checkin_time"))
  }

  func testCreateRequest_sendsCheckinTimeAs24Hour() throws {
    var form = CreateEventData()
    form.type = .showcase
    form.name = "Showcase"
    form.checkinTime = TimeOfDay.pickerDate(from: "13:45")
    let request = CreateEventRequest.from(formData: form, userId: "u1", familyUnitId: nil)
    XCTAssertEqual(try json(request)["checkin_time"] as? String, "13:45")
  }
}
