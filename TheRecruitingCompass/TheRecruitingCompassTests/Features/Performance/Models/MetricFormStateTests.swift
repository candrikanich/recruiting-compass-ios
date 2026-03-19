import XCTest
@testable import TheRecruitingCompass

@MainActor
final class MetricFormStateTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Default Initialization Tests

  func testInit_DefaultValues() {
    let form = MetricFormState()

    XCTAssertNil(form.metricType)
    XCTAssertEqual(form.value, "")
    XCTAssertEqual(form.unit, "")
    XCTAssertEqual(form.notes, "")
    XCTAssertFalse(form.verified)
  }

  // MARK: - isValid Tests

  func testIsValid_TrueWhenTypeAndValidValue() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "90.0"

    XCTAssertTrue(form.isValid)
  }

  func testIsValid_FalseWhenNoType() {
    var form = MetricFormState()
    form.metricType = nil
    form.value = "90.0"

    XCTAssertFalse(form.isValid)
  }

  func testIsValid_FalseWhenEmptyValue() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = ""

    XCTAssertFalse(form.isValid)
  }

  func testIsValid_FalseWhenNonNumericValue() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "abc"

    XCTAssertFalse(form.isValid)
  }

  func testIsValid_FalseWhenValueIsWhitespace() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "   "

    XCTAssertFalse(form.isValid)
  }

  func testIsValid_TrueWithNegativeNumber() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "-5.0"

    XCTAssertTrue(form.isValid)
  }

  func testIsValid_TrueWithZero() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "0"

    XCTAssertTrue(form.isValid)
  }

  func testIsValid_TrueWithDecimalValue() {
    var form = MetricFormState()
    form.metricType = .battingAvg
    form.value = "0.325"

    XCTAssertTrue(form.isValid)
  }

  // MARK: - parsedValue Tests

  func testParsedValue_ValidDouble() {
    var form = MetricFormState()
    form.value = "92.5"

    XCTAssertEqual(form.parsedValue, 92.5)
  }

  func testParsedValue_Integer() {
    var form = MetricFormState()
    form.value = "100"

    XCTAssertEqual(form.parsedValue, 100.0)
  }

  func testParsedValue_NilForInvalidString() {
    var form = MetricFormState()
    form.value = "not-a-number"

    XCTAssertNil(form.parsedValue)
  }

  func testParsedValue_NilForEmptyString() {
    var form = MetricFormState()
    form.value = ""

    XCTAssertNil(form.parsedValue)
  }

  func testParsedValue_NegativeNumber() {
    var form = MetricFormState()
    form.value = "-3.14"

    XCTAssertEqual(form.parsedValue, -3.14)
  }

  func testParsedValue_VeryLargeNumber() {
    var form = MetricFormState()
    form.value = "99999.99"

    XCTAssertEqual(form.parsedValue, 99999.99)
  }

  // MARK: - reset Tests

  func testReset_ClearsAllFields() {
    var form = MetricFormState()
    form.metricType = .velocity
    form.value = "90.0"
    form.unit = "mph"
    form.notes = "Great session"
    form.verified = true

    form.reset()

    XCTAssertNil(form.metricType)
    XCTAssertEqual(form.value, "")
    XCTAssertEqual(form.unit, "")
    XCTAssertEqual(form.notes, "")
    XCTAssertFalse(form.verified)
  }

  func testReset_ResetsDate() {
    var form = MetricFormState()
    let oldDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    form.recordedDate = oldDate

    form.reset()

    let now = Date()
    XCTAssertTrue(abs(form.recordedDate.timeIntervalSince(now)) < 1.0)
  }

  // MARK: - populate Tests

  func testPopulate_SetsAllFieldsFromMetric() {
    var form = MetricFormState()
    let date = Date()
    let metric = PerformanceMetric(
      id: "metric-1",
      userId: "user-1",
      metricType: .exitVelo,
      value: 105.3,
      unit: "mph",
      recordedDate: date,
      eventId: nil,
      verified: true,
      notes: "Batting practice",
      createdAt: date,
      updatedAt: date
    )

    form.populate(from: metric)

    XCTAssertEqual(form.metricType, .exitVelo)
    XCTAssertEqual(form.value, "105.30")
    XCTAssertEqual(form.unit, "mph")
    XCTAssertEqual(form.recordedDate, date)
    XCTAssertEqual(form.notes, "Batting practice")
    XCTAssertTrue(form.verified)
  }

  func testPopulate_HandlesNilNotes() {
    var form = MetricFormState()
    form.notes = "existing notes"

    let metric = PerformanceMetric(
      id: "metric-1",
      userId: "user-1",
      metricType: .velocity,
      value: 90.0,
      unit: "mph",
      recordedDate: Date(),
      eventId: nil,
      verified: false,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    form.populate(from: metric)

    XCTAssertEqual(form.notes, "")
  }

  func testPopulate_FormatsValueToTwoDecimals() {
    var form = MetricFormState()
    let metric = PerformanceMetric(
      id: "metric-1",
      userId: "user-1",
      metricType: .battingAvg,
      value: 0.3,
      unit: "avg",
      recordedDate: Date(),
      eventId: nil,
      verified: false,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )

    form.populate(from: metric)

    XCTAssertEqual(form.value, "0.30")
  }

  // MARK: - Equatable Tests

  func testEquatable_SameState_AreEqual() {
    var form1 = MetricFormState()
    form1.metricType = .velocity
    form1.value = "90.0"
    form1.unit = "mph"

    var form2 = MetricFormState()
    form2.metricType = .velocity
    form2.value = "90.0"
    form2.unit = "mph"

    // Note: recordedDate defaults may differ slightly
    form2.recordedDate = form1.recordedDate

    XCTAssertEqual(form1, form2)
  }

  func testEquatable_DifferentValues_AreNotEqual() {
    var form1 = MetricFormState()
    form1.metricType = .velocity
    form1.value = "90.0"

    var form2 = MetricFormState()
    form2.metricType = .velocity
    form2.value = "95.0"

    form2.recordedDate = form1.recordedDate

    XCTAssertNotEqual(form1, form2)
  }
}
