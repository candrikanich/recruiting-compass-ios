import XCTest
@testable import TheRecruitingCompass

@MainActor
final class MetricRequestTests: XCTestCase {

  // MARK: - MetricCreateRequest Tests

  func testCreateRequest_Init() {
    let request = MetricCreateRequest(
      metricType: "velocity",
      value: 92.5,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: true,
      notes: "Bullpen session"
    )

    XCTAssertEqual(request.metricType, "velocity")
    XCTAssertEqual(request.value, 92.5)
    XCTAssertEqual(request.unit, "mph")
    XCTAssertEqual(request.recordedDate, "2026-02-15")
    XCTAssertTrue(request.verified)
    XCTAssertEqual(request.notes, "Bullpen session")
  }

  func testCreateRequest_NilNotes() {
    let request = MetricCreateRequest(
      metricType: "exit_velo",
      value: 100.0,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: false,
      notes: nil
    )

    XCTAssertNil(request.notes)
  }

  func testCreateRequest_EncodesWithSnakeCaseKeys() throws {
    let request = MetricCreateRequest(
      metricType: "sixty_time",
      value: 6.8,
      unit: "sec",
      recordedDate: "2026-02-15",
      verified: false,
      notes: nil
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertNotNil(json?["metric_type"])
    XCTAssertNotNil(json?["recorded_date"])
    XCTAssertNil(json?["metricType"])
    XCTAssertNil(json?["recordedDate"])
  }

  func testCreateRequest_DecodesFromSnakeCaseJSON() throws {
    let json = """
    {
      "metric_type": "pop_time",
      "value": 1.95,
      "unit": "sec",
      "recorded_date": "2026-02-15",
      "verified": true,
      "notes": "Behind the plate drill"
    }
    """.data(using: .utf8)!

    let request = try JSONDecoder().decode(MetricCreateRequest.self, from: json)

    XCTAssertEqual(request.metricType, "pop_time")
    XCTAssertEqual(request.value, 1.95)
    XCTAssertEqual(request.unit, "sec")
    XCTAssertTrue(request.verified)
    XCTAssertEqual(request.notes, "Behind the plate drill")
  }

  // MARK: - MetricUpdateRequest Tests

  func testUpdateRequest_AllFieldsSet() {
    let request = MetricUpdateRequest(
      metricType: "velocity",
      value: 95.0,
      unit: "mph",
      recordedDate: "2026-02-16",
      verified: true,
      notes: "Updated notes"
    )

    XCTAssertEqual(request.metricType, "velocity")
    XCTAssertEqual(request.value, 95.0)
    XCTAssertEqual(request.unit, "mph")
    XCTAssertEqual(request.recordedDate, "2026-02-16")
    XCTAssertTrue(request.verified!)
    XCTAssertEqual(request.notes, "Updated notes")
  }

  func testUpdateRequest_AllFieldsNil() {
    let request = MetricUpdateRequest(
      metricType: nil,
      value: nil,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: nil
    )

    XCTAssertNil(request.metricType)
    XCTAssertNil(request.value)
    XCTAssertNil(request.unit)
    XCTAssertNil(request.recordedDate)
    XCTAssertNil(request.verified)
    XCTAssertNil(request.notes)
  }

  func testUpdateRequest_PartialUpdate() {
    let request = MetricUpdateRequest(
      metricType: nil,
      value: 93.0,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: "Just updating value"
    )

    XCTAssertNil(request.metricType)
    XCTAssertEqual(request.value, 93.0)
    XCTAssertEqual(request.notes, "Just updating value")
  }

  func testUpdateRequest_EncodesWithSnakeCaseKeys() throws {
    let request = MetricUpdateRequest(
      metricType: "velocity",
      value: 95.0,
      unit: nil,
      recordedDate: "2026-02-16",
      verified: nil,
      notes: nil
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertNotNil(json?["metric_type"])
    XCTAssertNotNil(json?["recorded_date"])
    XCTAssertNil(json?["metricType"])
    XCTAssertNil(json?["recordedDate"])
  }

  // MARK: - Sendable Tests

  func testCreateRequest_IsSendable() async {
    let request = MetricCreateRequest(
      metricType: "velocity",
      value: 90.0,
      unit: "mph",
      recordedDate: "2026-02-15",
      verified: false,
      notes: nil
    )

    let result = await Task.detached {
      return request.metricType
    }.value

    XCTAssertEqual(result, "velocity")
  }

  func testUpdateRequest_IsSendable() async {
    let request = MetricUpdateRequest(
      metricType: "era",
      value: 2.50,
      unit: nil,
      recordedDate: nil,
      verified: nil,
      notes: nil
    )

    let result = await Task.detached {
      return request.value
    }.value

    XCTAssertEqual(result, 2.50)
  }
}
