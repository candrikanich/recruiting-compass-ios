import XCTest
@testable import TheRecruitingCompass

final class MetricModelTests: XCTestCase {

  // MARK: - MetricType displayName

  func testDisplayName_velocity() {
    XCTAssertEqual(MetricType.velocity.displayName, "Fastball Velocity")
  }

  func testDisplayName_exitVelo() {
    XCTAssertEqual(MetricType.exitVelo.displayName, "Exit Velocity")
  }

  func testDisplayName_sixtyTime() {
    XCTAssertEqual(MetricType.sixtyTime.displayName, "60-Yard Dash")
  }

  func testDisplayName_popTime() {
    XCTAssertEqual(MetricType.popTime.displayName, "Pop Time")
  }

  func testDisplayName_battingAvg() {
    XCTAssertEqual(MetricType.battingAvg.displayName, "Batting Average")
  }

  func testDisplayName_era() {
    XCTAssertEqual(MetricType.era.displayName, "ERA")
  }

  func testDisplayName_strikeouts() {
    XCTAssertEqual(MetricType.strikeouts.displayName, "Strikeouts")
  }

  func testDisplayName_other() {
    XCTAssertEqual(MetricType.other.displayName, "Other Metric")
  }

  // MARK: - MetricType defaultUnit

  func testDefaultUnit_velocity() {
    XCTAssertEqual(MetricType.velocity.defaultUnit, "mph")
  }

  func testDefaultUnit_exitVelo() {
    XCTAssertEqual(MetricType.exitVelo.defaultUnit, "mph")
  }

  func testDefaultUnit_sixtyTime() {
    XCTAssertEqual(MetricType.sixtyTime.defaultUnit, "sec")
  }

  func testDefaultUnit_popTime() {
    XCTAssertEqual(MetricType.popTime.defaultUnit, "sec")
  }

  func testDefaultUnit_battingAvg() {
    XCTAssertEqual(MetricType.battingAvg.defaultUnit, "")
  }

  func testDefaultUnit_era() {
    XCTAssertEqual(MetricType.era.defaultUnit, "")
  }

  func testDefaultUnit_strikeouts() {
    XCTAssertEqual(MetricType.strikeouts.defaultUnit, "count")
  }

  func testDefaultUnit_other() {
    XCTAssertEqual(MetricType.other.defaultUnit, "")
  }

  // MARK: - MetricType isLowerBetter

  func testIsLowerBetter_sixtyTime() {
    XCTAssertTrue(MetricType.sixtyTime.isLowerBetter)
  }

  func testIsLowerBetter_popTime() {
    XCTAssertTrue(MetricType.popTime.isLowerBetter)
  }

  func testIsLowerBetter_era() {
    XCTAssertTrue(MetricType.era.isLowerBetter)
  }

  func testIsLowerBetter_velocity_isFalse() {
    XCTAssertFalse(MetricType.velocity.isLowerBetter)
  }

  func testIsLowerBetter_exitVelo_isFalse() {
    XCTAssertFalse(MetricType.exitVelo.isLowerBetter)
  }

  func testIsLowerBetter_strikeouts_isFalse() {
    XCTAssertFalse(MetricType.strikeouts.isLowerBetter)
  }

  // MARK: - MetricType registry-backed "all cases" (CaseIterable removed)

  func testRegistryTypes_hasExpectedCount() {
    XCTAssertEqual(MetricRegistry.types(forSport: nil).count, 8)
  }

  // MARK: - MetricType rawValue (Codable)

  func testRawValue_velocity() {
    XCTAssertEqual(MetricType.velocity.rawValue, "velocity")
  }

  func testRawValue_exitVelo() {
    XCTAssertEqual(MetricType.exitVelo.rawValue, "exit_velo")
  }

  func testRawValue_fromString_valid() {
    XCTAssertEqual(MetricType(rawValue: "sixty_time"), .sixtyTime)
  }

  // Struct wrapper: init is non-failable — an unknown key produces a MetricType
  // with that raw string rather than nil (unlike the old closed enum).
  func testRawValue_fromString_unknown_producesInstance() {
    XCTAssertEqual(MetricType(rawValue: "unknown_metric").rawValue, "unknown_metric")
  }

  // MARK: - PerformanceMetric formattedValue

  func testFormattedValue_withUnit() {
    let metric = makeMetric(value: 92.5, unit: "mph")
    XCTAssertEqual(metric.formattedValue, "92.5 mph")
  }

  func testFormattedValue_withEmptyUnit() {
    let metric = makeMetric(value: 92.5, unit: "")
    XCTAssertEqual(metric.formattedValue, "92.5")
  }

  func testFormattedValue_wholeNumber() {
    let metric = makeMetric(value: 10.0, unit: "K")
    XCTAssertEqual(metric.formattedValue, "10.0 K")
  }

  // MARK: - PerformanceMetric displayName

  func testPerformanceMetric_displayName_usesMetricType() {
    let metric = makeMetric(metricType: .velocity)
    XCTAssertEqual(metric.displayName, "Fastball Velocity")
  }

  func testPerformanceMetric_displayName_era() {
    let metric = makeMetric(metricType: .era)
    XCTAssertEqual(metric.displayName, "ERA")
  }

  // MARK: - NewMetricData validation

  func testNewMetricData_isValid_withValidNumber() {
    var data = NewMetricData()
    data.valueText = "92.5"
    XCTAssertTrue(data.isValid)
    XCTAssertEqual(data.parsedValue, 92.5)
  }

  func testNewMetricData_isValid_withInvalidNumber() {
    var data = NewMetricData()
    data.valueText = "abc"
    XCTAssertFalse(data.isValid)
    XCTAssertNil(data.parsedValue)
  }

  func testNewMetricData_isValid_withEmptyString() {
    var data = NewMetricData()
    data.valueText = ""
    XCTAssertFalse(data.isValid)
    XCTAssertNil(data.parsedValue)
  }

  func testNewMetricData_isValid_withZero() {
    var data = NewMetricData()
    data.valueText = "0"
    XCTAssertTrue(data.isValid)
    XCTAssertEqual(data.parsedValue, 0.0)
  }

  func testNewMetricData_isValid_withNegativeNumber() {
    var data = NewMetricData()
    data.valueText = "-5.0"
    XCTAssertTrue(data.isValid)
    XCTAssertEqual(data.parsedValue, -5.0)
  }

  // MARK: - Helpers

  private func makeMetric(
    metricType: MetricType = .velocity,
    value: Double = 92.5,
    unit: String = "mph"
  ) -> PerformanceMetric {
    PerformanceMetric(
      id: "m-1",
      userId: "u-1",
      metricType: metricType,
      value: value,
      unit: unit,
      recordedDate: Date(),
      eventId: "e-1",
      verified: false,
      notes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
