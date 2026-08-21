import XCTest
@testable import TheRecruitingCompass

final class MetricFormatTests: XCTestCase {
  func test_decimal_dropsLeadingZero() {
    XCTAssertEqual(Format.decimal(digits: 3, dropLeadingZero: true).apply(0.410), ".410")
    XCTAssertEqual(Format.decimal(digits: 3, dropLeadingZero: true).apply(1.000), "1.000")
  }
  func test_decimal_keepsLeadingZero() {
    XCTAssertEqual(Format.decimal(digits: 2, dropLeadingZero: false).apply(3.45), "3.45")
    XCTAssertEqual(Format.decimal(digits: 1, dropLeadingZero: false).apply(82.3), "82.3")
  }
  func test_integer() {
    XCTAssertEqual(Format.integer.apply(12.0), "12")
    XCTAssertEqual(Format.integer.apply(12.7), "13") // rounds
  }
  func test_percent() {
    XCTAssertEqual(Format.percent(digits: 1).apply(45.0), "45.0")
    XCTAssertEqual(Format.percent(digits: 1).apply(82.34), "82.3")
  }
  func test_duration_minutesSeconds() {
    XCTAssertEqual(Format.duration.apply(112.34), "1:52.34")   // 1:52.34
    XCTAssertEqual(Format.duration.apply(9.41), "0:09.41")
    XCTAssertEqual(Format.duration.apply(581.0), "9:41.00")
  }
}
