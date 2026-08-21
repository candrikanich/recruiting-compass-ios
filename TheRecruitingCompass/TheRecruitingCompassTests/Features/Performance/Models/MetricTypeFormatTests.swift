import XCTest
@testable import TheRecruitingCompass

/// Baseball-convention display formatting per metric type (parity with web `formatMetricValue`).
/// Number only — callers append the unit. Batting average drops the leading zero (`.410`);
/// ERA keeps it (`3.45`); velocities are 1-decimal; times 2-decimal; strikeouts integer.
final class MetricTypeFormatTests: XCTestCase {

  func test_battingAvg_threeDecimals_dropsLeadingZero() {
    XCTAssertEqual(MetricType.battingAvg.format(0.41), ".410")
    XCTAssertEqual(MetricType.battingAvg.format(0.4), ".400")
    XCTAssertEqual(MetricType.battingAvg.format(0), ".000")
  }

  func test_battingAvg_atOrAboveOne_keepsLeadingDigit() {
    XCTAssertEqual(MetricType.battingAvg.format(1.0), "1.000")
    XCTAssertEqual(MetricType.battingAvg.format(1.5), "1.500")
  }

  func test_era_twoDecimals_keepsLeadingDigit() {
    XCTAssertEqual(MetricType.era.format(3.45), "3.45")
    XCTAssertEqual(MetricType.era.format(0.0), "0.00")
    XCTAssertEqual(MetricType.era.format(12.0), "12.00")
  }

  func test_velocity_oneDecimal() {
    XCTAssertEqual(MetricType.velocity.format(82.3), "82.3")
    XCTAssertEqual(MetricType.velocity.format(82.30), "82.3")
    XCTAssertEqual(MetricType.exitVelo.format(92.1), "92.1")
  }

  func test_times_twoDecimals() {
    XCTAssertEqual(MetricType.sixtyTime.format(7.23), "7.23")
    XCTAssertEqual(MetricType.popTime.format(1.95), "1.95")
  }

  func test_strikeouts_integer() {
    XCTAssertEqual(MetricType.strikeouts.format(12), "12")
    XCTAssertEqual(MetricType.strikeouts.format(12.0), "12")
  }

  func test_other_twoDecimals_keepsLeadingZero() {
    XCTAssertEqual(MetricType.other.format(4.5), "4.50")
    XCTAssertEqual(MetricType.other.format(0.5), "0.50")
  }
}
