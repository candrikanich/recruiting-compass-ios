import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PerformanceMetricTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInit_SetsAllProperties() {
    let date = Date()
    let metric = createMetric(
      id: "metric-1",
      userId: "user-1",
      metricType: .velocity,
      value: 92.5,
      unit: "mph",
      recordedDate: date,
      eventId: "event-1",
      verified: true,
      notes: "Great session",
      createdAt: date,
      updatedAt: date
    )

    XCTAssertEqual(metric.id, "metric-1")
    XCTAssertEqual(metric.userId, "user-1")
    XCTAssertEqual(metric.metricType, .velocity)
    XCTAssertEqual(metric.value, 92.5)
    XCTAssertEqual(metric.unit, "mph")
    XCTAssertEqual(metric.recordedDate, date)
    XCTAssertEqual(metric.eventId, "event-1")
    XCTAssertTrue(metric.verified)
    XCTAssertEqual(metric.notes, "Great session")
  }

  func testInit_OptionalFieldsCanBeNil() {
    let metric = createMetric(eventId: nil, notes: nil)

    XCTAssertNil(metric.eventId)
    XCTAssertNil(metric.notes)
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_UsesIdProperty() {
    let metric = createMetric(id: "unique-id")
    XCTAssertEqual(metric.id, "unique-id")
  }

  // MARK: - Equatable Tests

  func testEquatable_SameMetricsAreEqual() {
    let date = Date()
    let metric1 = createMetric(id: "1", recordedDate: date, createdAt: date, updatedAt: date)
    let metric2 = createMetric(id: "1", recordedDate: date, createdAt: date, updatedAt: date)

    XCTAssertEqual(metric1, metric2)
  }

  func testEquatable_DifferentIdsAreNotEqual() {
    let date = Date()
    let metric1 = createMetric(id: "1", recordedDate: date, createdAt: date, updatedAt: date)
    let metric2 = createMetric(id: "2", recordedDate: date, createdAt: date, updatedAt: date)

    XCTAssertNotEqual(metric1, metric2)
  }

  func testEquatable_DifferentValuesAreNotEqual() {
    let date = Date()
    let metric1 = createMetric(id: "1", value: 90.0, recordedDate: date, createdAt: date, updatedAt: date)
    let metric2 = createMetric(id: "1", value: 95.0, recordedDate: date, createdAt: date, updatedAt: date)

    XCTAssertNotEqual(metric1, metric2)
  }

  // MARK: - displayName Tests

  func testDisplayName_DelegatesToMetricType() {
    let metric = createMetric(metricType: .velocity)
    XCTAssertEqual(metric.displayName, "Fastball Velocity")
  }

  func testDisplayName_AllTypes() {
    let types: [(MetricType, String)] = [
      (.velocity, "Fastball Velocity"),
      (.exitVelo, "Exit Velocity"),
      (.sixtyTime, "60-Yard Dash"),
      (.popTime, "Pop Time"),
      (.battingAvg, "Batting Average"),
      (.era, "ERA"),
      (.strikeouts, "Strikeouts"),
      (.other, "Other Metric")
    ]

    for (type, expected) in types {
      let metric = createMetric(metricType: type)
      XCTAssertEqual(metric.displayName, expected, "Display name mismatch for \(type)")
    }
  }

  // MARK: - formattedValue Tests

  func testFormattedValue_WithUnit() {
    let metric = createMetric(value: 92.50, unit: "mph")
    XCTAssertEqual(metric.formattedValue, "92.50 mph")
  }

  func testFormattedValue_WithEmptyUnit() {
    let metric = createMetric(value: 3.80, unit: "")
    XCTAssertEqual(metric.formattedValue, "3.80")
  }

  func testFormattedValue_WholeNumber() {
    let metric = createMetric(value: 100.0, unit: "K")
    XCTAssertEqual(metric.formattedValue, "100.00 K")
  }

  func testFormattedValue_VerySmallValue() {
    let metric = createMetric(value: 0.001, unit: "sec")
    XCTAssertEqual(metric.formattedValue, "0.00 sec")
  }

  func testFormattedValue_VeryLargeValue() {
    let metric = createMetric(value: 99999.99, unit: "mph")
    XCTAssertEqual(metric.formattedValue, "99999.99 mph")
  }

  func testFormattedValue_NegativeValue() {
    let metric = createMetric(value: -1.5, unit: "mph")
    XCTAssertEqual(metric.formattedValue, "-1.50 mph")
  }

  // MARK: - formattedDate Tests

  func testFormattedDate_ReturnsAbbreviatedDate() {
    let date = Date()
    let metric = createMetric(recordedDate: date)
    let expected = date.formatted(date: .abbreviated, time: .omitted)
    XCTAssertEqual(metric.formattedDate, expected)
  }

  // MARK: - Codable Tests

  func testCodable_EncodesAndDecodes() throws {
    let date = Date()
    let metric = createMetric(
      id: "codec-test",
      metricType: .exitVelo,
      value: 105.3,
      unit: "mph",
      recordedDate: date,
      verified: true,
      notes: "Line drive"
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(metric)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(PerformanceMetric.self, from: data)

    XCTAssertEqual(decoded.id, metric.id)
    XCTAssertEqual(decoded.metricType, metric.metricType)
    XCTAssertEqual(decoded.value, metric.value)
    XCTAssertEqual(decoded.unit, metric.unit)
    XCTAssertEqual(decoded.verified, metric.verified)
    XCTAssertEqual(decoded.notes, metric.notes)
  }

  func testCodable_UsesSnakeCaseCodingKeys() throws {
    let date = Date()
    let metric = createMetric(
      id: "key-test",
      userId: "user-123",
      metricType: .velocity,
      recordedDate: date,
      eventId: "event-456",
      createdAt: date,
      updatedAt: date
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(metric)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertNotNil(json?["user_id"])
    XCTAssertNotNil(json?["metric_type"])
    XCTAssertNotNil(json?["recorded_date"])
    XCTAssertNotNil(json?["event_id"])
    XCTAssertNotNil(json?["created_at"])
    XCTAssertNotNil(json?["updated_at"])
  }

  func testCodable_DecodesFromSnakeCaseJSON() throws {
    let json = """
    {
      "id": "json-test",
      "user_id": "user-1",
      "metric_type": "velocity",
      "value": 95.0,
      "unit": "mph",
      "recorded_date": "2026-02-15T10:00:00Z",
      "event_id": null,
      "verified": false,
      "notes": null,
      "created_at": "2026-02-15T10:00:00Z",
      "updated_at": "2026-02-15T10:00:00Z"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let metric = try decoder.decode(PerformanceMetric.self, from: json)

    XCTAssertEqual(metric.id, "json-test")
    XCTAssertEqual(metric.userId, "user-1")
    XCTAssertEqual(metric.metricType, .velocity)
    XCTAssertEqual(metric.value, 95.0)
    XCTAssertEqual(metric.unit, "mph")
    XCTAssertFalse(metric.verified)
    XCTAssertNil(metric.eventId)
    XCTAssertNil(metric.notes)
  }

  // MARK: - Sendable Tests

  func testSendable_CanBePassedAcrossConcurrencyBoundary() async {
    let metric = createMetric(id: "sendable-test")

    let result = await Task.detached {
      return metric.id
    }.value

    XCTAssertEqual(result, "sendable-test")
  }

  // MARK: - Helper Methods

  private func createMetric(
    id: String = "test-id",
    userId: String = "user-1",
    metricType: MetricType = .velocity,
    value: Double = 90.0,
    unit: String = "mph",
    recordedDate: Date = Date(),
    eventId: String? = nil,
    verified: Bool = false,
    notes: String? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PerformanceMetric {
    PerformanceMetric(
      id: id,
      userId: userId,
      metricType: metricType,
      value: value,
      unit: unit,
      recordedDate: recordedDate,
      eventId: eventId,
      verified: verified,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
