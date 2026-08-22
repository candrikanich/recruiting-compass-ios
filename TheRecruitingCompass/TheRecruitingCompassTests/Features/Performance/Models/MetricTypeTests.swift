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

  // Struct wrapper: init is non-failable — any string produces a valid instance
  // (unknown keys fall back to `MetricRegistry.def(for:)`'s synthesized default).
  func testInit_FromUnknownRawValue_ProducesInstance() {
    XCTAssertEqual(MetricType(rawValue: "invalid").rawValue, "invalid")
    XCTAssertEqual(MetricType(rawValue: "").rawValue, "")
    XCTAssertEqual(MetricType(rawValue: "VELOCITY").rawValue, "VELOCITY")
  }

  // MARK: - Registry-backed "all cases" (allCases removed with CaseIterable)

  // nil/unknown sport now yields no vocabulary (no baseball fallback), so the
  // legacy baseball cases are sourced from the real "Baseball" sport.
  private var allLegacyTypes: [MetricType] {
    MetricRegistry.types(forSport: "Baseball").map(MetricType.init(rawValue:))
  }

  func testRegistryTypes_ContainsAllLegacyCases() {
    XCTAssertEqual(allLegacyTypes.count, 12) // 11 baseball keys + "other"
    XCTAssertTrue(allLegacyTypes.contains(.velocity))
    XCTAssertTrue(allLegacyTypes.contains(.exitVelo))
    XCTAssertTrue(allLegacyTypes.contains(.sixtyTime))
    XCTAssertTrue(allLegacyTypes.contains(.popTime))
    XCTAssertTrue(allLegacyTypes.contains(.battingAvg))
    XCTAssertTrue(allLegacyTypes.contains(.era))
    XCTAssertTrue(allLegacyTypes.contains(.strikeouts))
    XCTAssertTrue(allLegacyTypes.contains(.other))
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_IdEqualsRawValue() {
    for type in allLegacyTypes {
      XCTAssertEqual(type.id, type.rawValue, "id should equal rawValue for \(type)")
    }
  }

  // MARK: - displayName Tests

  func testDisplayName_AllCasesHaveNonEmptyName() {
    for type in allLegacyTypes {
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
    for type in allLegacyTypes {
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

  // Struct wrapper: init is non-failable, so an unknown key decodes successfully
  // as a MetricType with that raw string (unlike the old closed enum, which
  // threw). Unknown keys still format sensibly via `MetricRegistry.def(for:)`.
  func testCodable_DecodesUnknownValueVerbatim() throws {
    let json = "\"invalid_type\"".data(using: .utf8)!
    let decoder = JSONDecoder()
    let type = try decoder.decode(MetricType.self, from: json)

    XCTAssertEqual(type.rawValue, "invalid_type")
  }
}
