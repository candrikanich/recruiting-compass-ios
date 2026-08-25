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
  func test_types_forNilOrUnknownSport_returnsEmpty() {
    // No baseball fallback — mirrors CanonicalPositions.positions(for:).
    XCTAssertTrue(MetricRegistry.types(forSport: nil).isEmpty)
    XCTAssertTrue(MetricRegistry.types(forSport: "Quidditch").isEmpty)
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

  // MARK: - Metric grouping (log-picker sections)

  func test_metricGroups_coverExactlyTheSixDenseSports() {
    XCTAssertEqual(
      Set(MetricRegistry.sportMetricGroups.keys),
      ["Baseball", "Softball", "Basketball", "Football", "Track & Field", "Volleyball"]
    )
  }

  func test_metricGroups_everyKeyExistsInThatSportsMetricSet() {
    for (sport, groups) in MetricRegistry.sportMetricGroups {
      let sportKeys = Set(MetricRegistry.types(forSport: sport))
      for group in groups {
        for key in group.keys {
          XCTAssertTrue(
            sportKeys.contains(key),
            "orphan grouped key \(key) not in \(sport)'s metric set"
          )
        }
      }
    }
  }

  func test_softballGroups_mirrorBaseball() {
    let baseball = MetricRegistry.groups(forSport: "Baseball")
    let softball = MetricRegistry.groups(forSport: "Softball")
    XCTAssertEqual(baseball.map(\.category), softball.map(\.category))
    XCTAssertEqual(baseball.map(\.keys), softball.map(\.keys))
  }

  func test_groups_forUngroupedSport_returnsEmpty() {
    XCTAssertTrue(MetricRegistry.groups(forSport: "Soccer").isEmpty)
  }

  func test_groups_forNilOrUnknownSport_returnsEmpty() {
    XCTAssertTrue(MetricRegistry.groups(forSport: nil).isEmpty)
    XCTAssertTrue(MetricRegistry.groups(forSport: "Quidditch").isEmpty)
  }

  func test_groups_caseInsensitiveLookup() {
    XCTAssertFalse(MetricRegistry.groups(forSport: "baseball").isEmpty)
  }

  func test_allNineteenSports_present() {
    let sports = [
      "Baseball", "Softball", "Basketball", "Football", "Soccer", "Volleyball",
      "Track & Field", "Cross Country", "Swimming", "Golf", "Tennis", "Wrestling",
      "Lacrosse", "Ice Hockey", "Field Hockey", "Rowing", "Water Polo",
      "Gymnastics", "Beach Volleyball"
    ]
    for sport in sports {
      XCTAssertNotNil(MetricRegistry.sportMetrics[sport], "missing sport \(sport)")
    }
  }

  // MARK: - Gymnastics + Beach Volleyball parity

  func test_gymnastics_orderAndJudgedScores() {
    let order = MetricRegistry.sportMetrics["Gymnastics"]
    XCTAssertEqual(order?.first, "aa_score")
    XCTAssertEqual(order?.count, 9)
    XCTAssertEqual(order, [
      "aa_score", "vault_score", "floor_score", "bars_score", "beam_score",
      "pommel_score", "rings_score", "pbars_score", "high_bar_score"
    ])
    // All nine are judged scores: higher-is-better, 3-decimal, no unit.
    for key in order ?? [] {
      let def = MetricRegistry.def(for: key)
      XCTAssertFalse(def.lowerIsBetter, "\(key) should be higher-is-better")
      XCTAssertEqual(def.unit, "", "\(key) should have no unit")
      XCTAssertEqual(def.format.apply(9.85), "9.850", "\(key) should format to 3 decimals")
    }
  }

  func test_gymnastics_rendersFlat_noGroups() {
    XCTAssertTrue(MetricRegistry.groups(forSport: "Gymnastics").isEmpty)
  }

  func test_beachVolleyball_reusesIndoorVolleyballDefs_noNewDefs() {
    // Beach Volleyball must reuse the exact five indoor Volleyball keys.
    XCTAssertEqual(
      MetricRegistry.sportMetrics["Beach Volleyball"],
      ["kills", "aces", "digs", "blocks", "hitting_pct"]
    )
    // Same def objects as indoor Volleyball — proves no duplicate defs were introduced.
    for key in ["kills", "aces", "digs", "blocks", "hitting_pct"] {
      XCTAssertNotNil(MetricRegistry.knownDef(for: key), "missing shared def \(key)")
    }
    XCTAssertEqual(MetricRegistry.def(for: "kills").label, "Kills")
    XCTAssertEqual(MetricRegistry.def(for: "hitting_pct").format.apply(0.412), ".412")
  }

  // Registry invariant: Beach Volleyball's keys are a subset of indoor
  // Volleyball's, so no new defs were introduced for it.
  func test_beachVolleyball_keysAreSubsetOfVolleyball() {
    let volleyball = Set(MetricRegistry.sportMetrics["Volleyball"] ?? [])
    let beach = Set(MetricRegistry.sportMetrics["Beach Volleyball"] ?? [])
    XCTAssertFalse(beach.isEmpty)
    XCTAssertTrue(beach.isSubset(of: volleyball),
                  "Beach Volleyball must reuse indoor Volleyball keys, not add new defs")
  }
}
