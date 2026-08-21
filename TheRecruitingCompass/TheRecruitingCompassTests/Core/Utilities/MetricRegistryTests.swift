import XCTest
@testable import TheRecruitingCompass

final class MetricRegistryTests: XCTestCase {
  func test_legacyKeys_matchOldFormatting() {
    XCTAssertEqual(MetricRegistry.def(for: "batting_avg").format.apply(0.410), ".410")
    XCTAssertEqual(MetricRegistry.def(for: "era").format.apply(3.45), "3.45")
    XCTAssertEqual(MetricRegistry.def(for: "velocity").format.apply(82.3), "82.3")
    XCTAssertEqual(MetricRegistry.def(for: "sixty_time").format.apply(6.85), "6.85")
    XCTAssertEqual(MetricRegistry.def(for: "strikeouts").format.apply(12.0), "12")
  }
  func test_legacyLabelsAndLowerBetter() {
    XCTAssertEqual(MetricRegistry.def(for: "velocity").label, "Fastball Velocity")
    XCTAssertTrue(MetricRegistry.def(for: "era").lowerIsBetter)
    XCTAssertFalse(MetricRegistry.def(for: "velocity").lowerIsBetter)
  }
  func test_unknownKey_fallback() {
    let d = MetricRegistry.def(for: "wingspan_reach")
    XCTAssertEqual(d.label, "wingspan reach")
    XCTAssertEqual(d.format.apply(12.5), "12.50")
    XCTAssertNil(MetricRegistry.knownDef(for: "wingspan_reach"))
  }
  func test_types_forBaseball_endsWithOther() {
    let t = MetricRegistry.types(forSport: "Baseball")
    XCTAssertEqual(t.last, "other")
    XCTAssertTrue(t.contains("batting_avg"))
  }
  func test_types_forNilSport_returnsDefaultPlusOther() {
    XCTAssertEqual(MetricRegistry.types(forSport: nil).last, "other")
  }
}
