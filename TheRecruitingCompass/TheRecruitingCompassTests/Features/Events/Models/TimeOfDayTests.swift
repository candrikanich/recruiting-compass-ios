import XCTest
@testable import TheRecruitingCompass

final class TimeOfDayTests: XCTestCase {
  nonisolated deinit {}

  func testDisplay_justAfterMidnight_is12AM() {
    XCTAssertEqual(TimeOfDay.display("00:05"), "12:05 AM")
  }

  func testDisplay_noon_is12PM() {
    XCTAssertEqual(TimeOfDay.display("12:00"), "12:00 PM")
  }

  func testDisplay_valueWithSeconds_dropsSeconds() {
    XCTAssertEqual(TimeOfDay.display("14:30:00"), "2:30 PM")
  }

  func testDisplay_morning_hasNoLeadingZero() {
    XCTAssertEqual(TimeOfDay.display("09:05"), "9:05 AM")
  }

  func testDisplay_nilOrEmpty_isNil() {
    XCTAssertNil(TimeOfDay.display(nil))
    XCTAssertNil(TimeOfDay.display(""))
  }

  func testDisplay_garbage_passesThroughUnchanged() {
    XCTAssertEqual(TimeOfDay.display("around noon"), "around noon")
    XCTAssertEqual(TimeOfDay.display("25:99"), "25:99")
  }

  func testNormalized_secondsValue_becomes24HourHHmm() {
    XCTAssertEqual(TimeOfDay.normalized("14:30:00"), "14:30")
    XCTAssertEqual(TimeOfDay.normalized("07:05"), "07:05")
  }

  func testNormalized_garbage_isUnchanged() {
    XCTAssertEqual(TimeOfDay.normalized("soon"), "soon")
  }

  func testPickerRoundTrip_preservesHourAndMinute() throws {
    for raw in ["00:05", "12:00", "14:30", "23:59"] {
      let date = try XCTUnwrap(TimeOfDay.pickerDate(from: raw))
      XCTAssertEqual(TimeOfDay.string(from: date), raw)
    }
  }

  func testPickerDate_fromSecondsValue_roundTripsToHHmm() throws {
    let date = try XCTUnwrap(TimeOfDay.pickerDate(from: "14:30:00"))
    XCTAssertEqual(TimeOfDay.string(from: date), "14:30")
  }

  func testPickerDate_garbage_isNil() {
    XCTAssertNil(TimeOfDay.pickerDate(from: "soon"))
  }
}
