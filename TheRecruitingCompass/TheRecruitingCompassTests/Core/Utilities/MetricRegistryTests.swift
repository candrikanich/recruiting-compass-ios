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

  // MARK: - Task 9: all-sport content

  func test_baseball_order_grownTo11() {
    let order = MetricRegistry.sportMetrics["Baseball"]
    XCTAssertEqual(order?.first, "velocity")
    XCTAssertEqual(order?.last, "fielding_pct")
    XCTAssertEqual(order?.count, 11)
    for key in ["on_base_pct", "slugging_pct", "whip", "fielding_pct"] {
      XCTAssertTrue(order?.contains(key) ?? false, "missing \(key)")
    }
  }

  func test_basketball_order_and_percent() {
    XCTAssertEqual(MetricRegistry.sportMetrics["Basketball"]?.first, "points_per_game")
    XCTAssertEqual(MetricRegistry.def(for: "field_goal_pct").format.apply(45.0), "45.0")
    XCTAssertEqual(MetricRegistry.def(for: "field_goal_pct").unit, "%")
  }

  func test_hockey_savePct_isBaseballStyle() {
    XCTAssertEqual(MetricRegistry.def(for: "save_pct").format.apply(0.915), ".915")
  }

  func test_duration_sports() {
    XCTAssertEqual(MetricRegistry.def(for: "race_time").format.apply(581.0), "9:41.00")
    XCTAssertTrue(MetricRegistry.def(for: "erg_2k").lowerIsBetter)
  }

  func test_everySportHasDefs_andOtherAppended() {
    for sport in MetricRegistry.sportMetrics.keys {
      let types = MetricRegistry.types(forSport: sport)
      XCTAssertEqual(types.last, "other", "sport \(sport) missing trailing other")
      for key in types where key != "other" {
        XCTAssertNotNil(MetricRegistry.knownDef(for: key), "missing def for \(key) in \(sport)")
      }
    }
  }

  func test_sharedKeys_singleDef() {
    XCTAssertEqual(MetricRegistry.def(for: "goals").label, "Goals")
    XCTAssertEqual(MetricRegistry.def(for: "assists").label, "Assists")
    XCTAssertEqual(MetricRegistry.def(for: "saves").label, "Saves")
    XCTAssertEqual(MetricRegistry.def(for: "vertical_jump").label, "Vertical Jump")
    XCTAssertEqual(MetricRegistry.def(for: "vertical_jump").unit, "in")
  }

  func test_allSeventeenSports_present() {
    let sports = [
      "Baseball", "Softball", "Basketball", "Football", "Soccer", "Volleyball",
      "Track & Field", "Cross Country", "Swimming", "Golf", "Tennis", "Wrestling",
      "Lacrosse", "Ice Hockey", "Field Hockey", "Rowing", "Water Polo"
    ]
    for sport in sports {
      XCTAssertNotNil(MetricRegistry.sportMetrics[sport], "missing sport \(sport)")
    }
  }
}
