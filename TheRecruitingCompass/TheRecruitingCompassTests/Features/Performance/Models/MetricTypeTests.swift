import XCTest
@testable import TheRecruitingCompass

final class MetricTypeTests: XCTestCase {

  // MARK: - Raw Value Tests

  func testRawValues_MatchExpectedStrings() {
    XCTAssertEqual(MetricType.velocity.rawValue, "velocity")
    XCTAssertEqual(MetricType.exitVelo.rawValue, "exit_velo")
    XCTAssertEqual(MetricType.sixtyTime.rawValue, "sixty_time")
    XCTAssertEqual(MetricType.popTime.rawValue, "pop_time")
    XCTAssertEqual(MetricType.battingAvg.rawValue, "batting_avg")
    XCTAssertEqual(MetricType.era.rawValue, "era")
    XCTAssertEqual(MetricType.strikeouts.rawValue, "strikeouts")
    XCTAssertEqual(MetricType.other.rawValue, "other")
  }

  func testInit_FromValidRawValue() {
    XCTAssertEqual(MetricType(rawValue: "velocity"), .velocity)
    XCTAssertEqual(MetricType(rawValue: "exit_velo"), .exitVelo)
    XCTAssertEqual(MetricType(rawValue: "sixty_time"), .sixtyTime)
    XCTAssertEqual(MetricType(rawValue: "pop_time"), .popTime)
    XCTAssertEqual(MetricType(rawValue: "batting_avg"), .battingAvg)
    XCTAssertEqual(MetricType(rawValue: "era"), .era)
    XCTAssertEqual(MetricType(rawValue: "strikeouts"), .strikeouts)
    XCTAssertEqual(MetricType(rawValue: "other"), .other)
  }

  func testInit_FromInvalidRawValue_ReturnsNil() {
    XCTAssertNil(MetricType(rawValue: "invalid"))
    XCTAssertNil(MetricType(rawValue: ""))
    XCTAssertNil(MetricType(rawValue: "VELOCITY"))
  }

  // MARK: - CaseIterable Tests

  func testCaseIterable_ContainsAllCases() {
    XCTAssertEqual(MetricType.allCases.count, 8)
    XCTAssertTrue(MetricType.allCases.contains(.velocity))
    XCTAssertTrue(MetricType.allCases.contains(.exitVelo))
    XCTAssertTrue(MetricType.allCases.contains(.sixtyTime))
    XCTAssertTrue(MetricType.allCases.contains(.popTime))
    XCTAssertTrue(MetricType.allCases.contains(.battingAvg))
    XCTAssertTrue(MetricType.allCases.contains(.era))
    XCTAssertTrue(MetricType.allCases.contains(.strikeouts))
    XCTAssertTrue(MetricType.allCases.contains(.other))
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_IdEqualsRawValue() {
    for type in MetricType.allCases {
      XCTAssertEqual(type.id, type.rawValue, "id should equal rawValue for \(type)")
    }
  }

  // MARK: - displayName Tests

  func testDisplayName_AllCasesHaveNonEmptyName() {
    for type in MetricType.allCases {
      XCTAssertFalse(type.displayName.isEmpty, "displayName should not be empty for \(type)")
    }
  }

  func testDisplayName_SpecificValues() {
    XCTAssertEqual(MetricType.velocity.displayName, "Fastball Velocity")
    XCTAssertEqual(MetricType.exitVelo.displayName, "Exit Velocity")
    XCTAssertEqual(MetricType.sixtyTime.displayName, "60-Yard Dash")
    XCTAssertEqual(MetricType.popTime.displayName, "Pop Time")
    XCTAssertEqual(MetricType.battingAvg.displayName, "Batting Average")
    XCTAssertEqual(MetricType.era.displayName, "ERA")
    XCTAssertEqual(MetricType.strikeouts.displayName, "Strikeouts")
    XCTAssertEqual(MetricType.other.displayName, "Other Metric")
  }

  // MARK: - defaultUnit Tests

  func testDefaultUnit_VelocityTypes() {
    XCTAssertEqual(MetricType.velocity.defaultUnit, "mph")
    XCTAssertEqual(MetricType.exitVelo.defaultUnit, "mph")
  }

  func testDefaultUnit_TimeTypes() {
    XCTAssertEqual(MetricType.sixtyTime.defaultUnit, "sec")
    XCTAssertEqual(MetricType.popTime.defaultUnit, "sec")
  }

  // Web-parity: `unitByMetricType` (LogMetricModal.vue) stores None for batting_avg/era
  // and "count" for strikeouts. iOS must write the same units for the same metric types.
  func testDefaultUnit_StatTypes() {
    XCTAssertEqual(MetricType.battingAvg.defaultUnit, "")
    XCTAssertEqual(MetricType.era.defaultUnit, "")
    XCTAssertEqual(MetricType.strikeouts.defaultUnit, "count")
  }

  func testDefaultUnit_OtherIsEmpty() {
    XCTAssertEqual(MetricType.other.defaultUnit, "")
  }

  // Every locked unit must be a member of the shared vocabulary, or iOS would store a
  // unit the web modal can't produce — the exact cross-platform drift this guards against.
  func testDefaultUnit_AllMembersOfVocabulary() {
    for type in MetricType.allCases {
      XCTAssertTrue(MetricType.unitVocabulary.contains(type.defaultUnit),
                    "\(type).defaultUnit '\(type.defaultUnit)' not in unitVocabulary")
    }
  }

  // MARK: - isLowerBetter Tests

  func testIsLowerBetter_TrueForTimeAndERA() {
    XCTAssertTrue(MetricType.sixtyTime.isLowerBetter)
    XCTAssertTrue(MetricType.popTime.isLowerBetter)
    XCTAssertTrue(MetricType.era.isLowerBetter)
  }

  func testIsLowerBetter_FalseForOtherTypes() {
    XCTAssertFalse(MetricType.velocity.isLowerBetter)
    XCTAssertFalse(MetricType.exitVelo.isLowerBetter)
    XCTAssertFalse(MetricType.battingAvg.isLowerBetter)
    XCTAssertFalse(MetricType.strikeouts.isLowerBetter)
    XCTAssertFalse(MetricType.other.isLowerBetter)
  }

  // MARK: - Codable Tests

  func testCodable_EncodesAsRawValue() throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(MetricType.exitVelo)
    let string = String(data: data, encoding: .utf8)

    XCTAssertEqual(string, "\"exit_velo\"")
  }

  func testCodable_DecodesFromRawValue() throws {
    let json = "\"sixty_time\"".data(using: .utf8)!
    let decoder = JSONDecoder()
    let type = try decoder.decode(MetricType.self, from: json)

    XCTAssertEqual(type, .sixtyTime)
  }

  func testCodable_ThrowsForInvalidValue() {
    let json = "\"invalid_type\"".data(using: .utf8)!
    let decoder = JSONDecoder()

    XCTAssertThrowsError(try decoder.decode(MetricType.self, from: json))
  }
}
