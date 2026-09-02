import Foundation

/// A named section of metric keys within a sport, used to group the log-metric
/// picker into headed sections (e.g. Baseball → Hitting/Pitching/Fielding/Speed).
/// Parallel to `SPORT_METRICS` ordering — kept out of `MetricDef` because shared
/// keys carry different categories across sports.
struct MetricGroup: Sendable {
  let category: String
  let keys: [String]
}

/// Canonical metric-type registry. Swift mirror of web `metricDefs` /
/// `sportMetrics`. Keys are stored verbatim in `performance_metrics.metric_type`.
/// Populated for all 17 sports (byte-identical with web).
enum MetricRegistry {
  static let otherKey = "other"

  static let defs: [String: MetricDef] = Dictionary(
    uniqueKeysWithValues: allDefs.map { ($0.key, $0.withIcon(iconByKey[$0.key] ?? $0.icon)) }
  )

  /// Central SF Symbol per metric key across all 17 sports. Keeps `MetricRow`
  /// (and any future icon surface) sport-aware without a baseball-only switch.
  /// Unlisted keys fall back to the def's generic default ("chart.bar").
  private static let iconByKey: [String: String] = [
    // Baseball / Softball
    "velocity": "flame", "exit_velo": "flame", "batting_avg": "baseball",
    "sixty_time": "timer", "pop_time": "stopwatch", "era": "chart.bar",
    "on_base_pct": "percent", "slugging_pct": "percent", "whip": "chart.bar",
    "strikeouts": "figure.strengthtraining.traditional", "fielding_pct": "percent",
    // Basketball
    "points_per_game": "basketball", "rebounds_per_game": "arrow.up.and.down",
    "assists_per_game": "hand.thumbsup", "field_goal_pct": "percent",
    "three_point_pct": "percent", "free_throw_pct": "percent",
    "steals_per_game": "hand.raised", "blocks_per_game": "hand.raised.fill",
    "vertical_jump": "arrow.up",
    // Football
    "forty_time": "timer", "bench_press": "figure.strengthtraining.traditional",
    "broad_jump": "arrow.left.and.right", "shuttle": "timer", "three_cone": "timer",
    "squat": "figure.strengthtraining.traditional", "passing_yards": "football",
    "rushing_yards": "figure.run", "receiving_yards": "football",
    "tackles": "figure.american.football",
    // Soccer / Lacrosse / Hockey / Water Polo (shared + specific)
    "goals": "soccerball", "assists": "hand.thumbsup", "saves": "hand.raised.fill",
    "clean_sheets": "checkmark.shield", "minutes_played": "clock",
    "ground_balls": "circle.grid.cross", "points": "star.circle",
    "save_pct": "percent", "goals_against_avg": "chart.bar", "steals": "hand.raised",
    // Volleyball
    "kills": "bolt", "blocks": "hand.raised.fill", "digs": "hand.raised",
    "aces": "bolt.fill", "hitting_pct": "percent",
    // Track & Field
    "sprint_time": "figure.run", "distance_time": "figure.run", "relay_split": "timer",
    "long_jump": "arrow.left.and.right", "high_jump": "arrow.up",
    "shot_put": "circle.fill", "discus": "circle",
    // Cross Country
    "race_time": "figure.run", "pace_per_mile": "speedometer",
    // Swimming
    "event_time": "timer", "free_50": "figure.pool.swim", "free_100": "figure.pool.swim",
    // Golf
    "scoring_average": "figure.golf", "handicap": "flag",
    // Tennis
    "utr_rating": "star", "ranking": "number",
    // Wrestling
    "pins": "figure.wrestling", "takedowns": "figure.wrestling", "weight_class": "scalemass",
    // Rowing
    "erg_2k": "figure.rower", "erg_split": "timer",
    // Gymnastics (judged scores — one consistent symbol across all nine)
    "aa_score": "figure.gymnastics", "vault_score": "figure.gymnastics",
    "floor_score": "figure.gymnastics", "bars_score": "figure.gymnastics",
    "beam_score": "figure.gymnastics", "pommel_score": "figure.gymnastics",
    "rings_score": "figure.gymnastics", "pbars_score": "figure.gymnastics",
    "high_bar_score": "figure.gymnastics",
    // Fallback bucket
    "other": "chart.bar"
  ]

  /// Ordered per-sport keys (NOT including `other`, which `types(forSport:)`
  /// appends). Keys match the sport strings used across onboarding/preferences
  /// and `CanonicalPositions.bySport`.
  static let sportMetrics: [String: [String]] = [
    // Baseball/Softball intentionally share one ordering array (deferred-minor
    // from earlier review — the two sports use identical metric vocabularies).
    "Baseball": baseball,
    "Softball": baseball,
    "Basketball": basketball,
    "Football": football,
    "Soccer": soccer,
    "Volleyball": volleyball,
    "Track & Field": trackAndField,
    "Cross Country": crossCountry,
    "Swimming": swimming,
    "Golf": golf,
    "Tennis": tennis,
    "Wrestling": wrestling,
    "Lacrosse": lacrosse,
    "Ice Hockey": iceHockey,
    "Field Hockey": fieldHockey,
    "Rowing": rowing,
    "Water Polo": waterPolo,
    "Gymnastics": gymnastics,
    // Beach Volleyball reuses the indoor Volleyball metric keys — NO new defs.
    "Beach Volleyball": ["kills", "aces", "digs", "blocks", "hitting_pct"]
  ]

  static func knownDef(for key: String) -> MetricDef? { defs[key] }

  static func def(for key: String) -> MetricDef {
    if let existing = defs[key] { return existing }
    let label = key.replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: .whitespaces)
    return MetricDef(key, label, "", .decimal(digits: 2, dropLeadingZero: false))
  }

  /// Ordered metric keys for a sport (with `other` appended). Empty when the
  /// sport is nil/unknown — mirrors `CanonicalPositions.positions(for:)`. There
  /// is no baseball fallback: `primary_sport` is required going forward, so an
  /// absent sport yields no metric vocabulary rather than silently defaulting.
  static func types(forSport sport: String?) -> [String] {
    guard let base = lookup(sport) else { return [] }
    return base + [otherKey]
  }

  private static func lookup(_ sport: String?) -> [String]? {
    guard let sport else { return nil }
    return sportMetrics.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value
  }

  // MARK: - Metric groups (log-picker section headers)

  /// Per-sport ordered metric groups for the log-metric picker. Only the 6
  /// dense sports get an entry; every other sport renders flat (no entry →
  /// `groups(forSport:)` returns []). Section order = array order; keys within
  /// a group are in display order. Every key here is a subset of that sport's
  /// `sportMetrics` ordering (verified by test).
  static let sportMetricGroups: [String: [MetricGroup]] = [
    "Baseball": baseballGroups,
    "Softball": baseballGroups,
    "Basketball": basketballGroups,
    "Football": footballGroups,
    "Track & Field": trackAndFieldGroups,
    "Volleyball": volleyballGroups
  ]

  /// Ordered metric groups for a sport, or [] when the sport has no grouping
  /// (nil/unknown, or one of the 11 flat sports). Mirrors the case-insensitive
  /// lookup used by `types(forSport:)`.
  static func groups(forSport sport: String?) -> [MetricGroup] {
    guard let sport else { return [] }
    return sportMetricGroups.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value ?? []
  }

  private static let baseballGroups: [MetricGroup] = [
    MetricGroup(category: String(localized: "Hitting"),
                keys: ["exit_velo", "batting_avg", "on_base_pct", "slugging_pct"]),
    MetricGroup(category: String(localized: "Pitching"),
                keys: ["velocity", "era", "whip", "strikeouts"]),
    MetricGroup(category: String(localized: "Fielding"), keys: ["pop_time", "fielding_pct"]),
    MetricGroup(category: String(localized: "Speed"), keys: ["sixty_time"])
  ]

  private static let basketballGroups: [MetricGroup] = [
    MetricGroup(category: String(localized: "Scoring"),
                keys: ["points_per_game", "field_goal_pct", "three_point_pct", "free_throw_pct"]),
    MetricGroup(category: String(localized: "Playmaking"), keys: ["assists_per_game"]),
    MetricGroup(category: String(localized: "Defense"),
                keys: ["rebounds_per_game", "steals_per_game", "blocks_per_game"]),
    MetricGroup(category: String(localized: "Athleticism"), keys: ["vertical_jump"])
  ]

  private static let footballGroups: [MetricGroup] = [
    MetricGroup(category: String(localized: "Combine"),
                keys: ["forty_time", "vertical_jump", "broad_jump", "shuttle", "three_cone"]),
    MetricGroup(category: String(localized: "Strength"), keys: ["bench_press", "squat"]),
    MetricGroup(category: String(localized: "Offense"),
                keys: ["passing_yards", "rushing_yards", "receiving_yards"]),
    MetricGroup(category: String(localized: "Defense"), keys: ["tackles"])
  ]

  private static let trackAndFieldGroups: [MetricGroup] = [
    MetricGroup(category: String(localized: "Running"), keys: ["sprint_time", "distance_time", "relay_split"]),
    MetricGroup(category: String(localized: "Jumps"), keys: ["long_jump", "high_jump"]),
    MetricGroup(category: String(localized: "Throws"), keys: ["shot_put", "discus"])
  ]

  private static let volleyballGroups: [MetricGroup] = [
    MetricGroup(category: String(localized: "Attacking"), keys: ["kills", "hitting_pct", "aces"]),
    MetricGroup(category: String(localized: "Setting"), keys: ["assists"]),
    MetricGroup(category: String(localized: "Defense"), keys: ["blocks", "digs"])
  ]

  // MARK: - Sport orderings

  private static let baseball = [
    "velocity", "exit_velo", "batting_avg", "sixty_time", "pop_time", "era",
    "on_base_pct", "slugging_pct", "whip", "strikeouts", "fielding_pct"
  ]

  private static let basketball = [
    "points_per_game", "rebounds_per_game", "assists_per_game", "field_goal_pct",
    "three_point_pct", "free_throw_pct", "steals_per_game", "blocks_per_game", "vertical_jump"
  ]

  private static let football = [
    "forty_time", "vertical_jump", "bench_press", "broad_jump", "shuttle", "three_cone",
    "squat", "passing_yards", "rushing_yards", "receiving_yards", "tackles"
  ]

  private static let soccer = ["goals", "assists", "saves", "clean_sheets", "minutes_played"]

  private static let volleyball = ["kills", "assists", "blocks", "digs", "aces", "hitting_pct"]

  private static let trackAndField = [
    "sprint_time", "distance_time", "relay_split", "long_jump", "high_jump", "shot_put", "discus"
  ]

  private static let crossCountry = ["race_time", "pace_per_mile"]

  private static let swimming = ["event_time", "free_50", "free_100"]

  private static let golf = ["scoring_average", "handicap"]

  // "singles_record" excluded — text field, not a numeric metric.
  private static let tennis = ["utr_rating", "ranking"]

  // "record" excluded — text field, not a numeric metric.
  private static let wrestling = ["pins", "takedowns", "weight_class"]

  private static let lacrosse = ["goals", "assists", "ground_balls", "saves"]

  private static let iceHockey = ["points", "goals", "assists", "save_pct", "goals_against_avg"]

  private static let fieldHockey = ["goals", "assists", "saves"]

  private static let rowing = ["erg_2k", "erg_split"]

  private static let waterPolo = ["goals", "assists", "saves", "steals"]

  private static let gymnastics = [
    "aa_score", "vault_score", "floor_score", "bars_score", "beam_score",
    "pommel_score", "rings_score", "pbars_score", "high_bar_score"
  ]

  // MARK: - Definitions

  private static let allDefs: [MetricDef] = baseballDefs + basketballDefs + footballDefs
    + soccerLacrosseHockeyDefs + volleyballDefs + trackAndFieldDefs + crossCountryDefs
    + swimmingDefs + golfDefs + tennisDefs + wrestlingDefs + rowingDefs + gymnasticsDefs + sharedDefs
    + [MetricDef(otherKey, String(localized: "Other Metric"), "", .decimal(digits: 2, dropLeadingZero: false))]

  // MARK: Baseball / Softball

  private static let baseballDefs: [MetricDef] = [
    MetricDef("velocity", String(localized: "Fastball Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("exit_velo", String(localized: "Exit Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("batting_avg", String(localized: "Batting Average"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef(
      "sixty_time", String(localized: "60-Yard Dash"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef(
      "pop_time", String(localized: "Pop Time"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef(
      "era", String(localized: "ERA"), "",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("on_base_pct", String(localized: "On-Base Percentage"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef("slugging_pct", String(localized: "Slugging Percentage"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef(
      "whip", String(localized: "WHIP"), "",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("strikeouts", String(localized: "Strikeouts"), "count", .integer),
    MetricDef("fielding_pct", String(localized: "Fielding Percentage"), "", .decimal(digits: 3, dropLeadingZero: true))
  ]

  // MARK: Basketball

  private static let basketballDefs: [MetricDef] = [
    MetricDef("points_per_game", String(localized: "Points Per Game"), "", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef(
      "rebounds_per_game", String(localized: "Rebounds Per Game"), "",
      .decimal(digits: 1, dropLeadingZero: false)
    ),
    MetricDef(
      "assists_per_game", String(localized: "Assists Per Game"), "",
      .decimal(digits: 1, dropLeadingZero: false)
    ),
    MetricDef("field_goal_pct", String(localized: "Field Goal %"), "%", .percent(digits: 1)),
    MetricDef("three_point_pct", String(localized: "3-Point %"), "%", .percent(digits: 1)),
    MetricDef("free_throw_pct", String(localized: "Free Throw %"), "%", .percent(digits: 1)),
    MetricDef("steals_per_game", String(localized: "Steals Per Game"), "", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("blocks_per_game", String(localized: "Blocks Per Game"), "", .decimal(digits: 1, dropLeadingZero: false))
  ]

  // MARK: Football

  private static let footballDefs: [MetricDef] = [
    MetricDef(
      "forty_time", String(localized: "40-Yard Dash"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("bench_press", String(localized: "Bench Press"), "reps", .integer),
    MetricDef("broad_jump", String(localized: "Broad Jump"), "in", .integer),
    MetricDef(
      "shuttle", String(localized: "Shuttle Run"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef(
      "three_cone", String(localized: "3-Cone Drill"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("squat", String(localized: "Squat"), "lbs", .integer),
    MetricDef("passing_yards", String(localized: "Passing Yards"), "yds", .integer),
    MetricDef("rushing_yards", String(localized: "Rushing Yards"), "yds", .integer),
    MetricDef("receiving_yards", String(localized: "Receiving Yards"), "yds", .integer),
    MetricDef("tackles", String(localized: "Tackles"), "count", .integer)
  ]

  // MARK: Soccer / Lacrosse / Ice Hockey / Field Hockey / Water Polo (non-shared keys)

  private static let soccerLacrosseHockeyDefs: [MetricDef] = [
    MetricDef("clean_sheets", String(localized: "Clean Sheets"), "count", .integer),
    MetricDef("minutes_played", String(localized: "Minutes Played"), "count", .integer),
    MetricDef("ground_balls", String(localized: "Ground Balls"), "count", .integer),
    MetricDef("points", String(localized: "Points"), "count", .integer),
    MetricDef("save_pct", String(localized: "Save %"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef(
      "goals_against_avg", String(localized: "Goals Against Avg"), "",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("steals", String(localized: "Steals"), "count", .integer)
  ]

  // MARK: Volleyball

  private static let volleyballDefs: [MetricDef] = [
    MetricDef("kills", String(localized: "Kills"), "count", .integer),
    MetricDef("blocks", String(localized: "Blocks"), "count", .integer),
    MetricDef("digs", String(localized: "Digs"), "count", .integer),
    MetricDef("aces", String(localized: "Aces"), "count", .integer),
    MetricDef("hitting_pct", String(localized: "Hitting Percentage"), "", .decimal(digits: 3, dropLeadingZero: true))
  ]

  // MARK: Track & Field

  private static let trackAndFieldDefs: [MetricDef] = [
    MetricDef(
      "sprint_time", String(localized: "Sprint Time"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("distance_time", String(localized: "Distance Time"), "", .duration, lowerIsBetter: true),
    MetricDef(
      "relay_split", String(localized: "Relay Split"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("long_jump", String(localized: "Long Jump"), "m", .decimal(digits: 2, dropLeadingZero: false)),
    MetricDef("high_jump", String(localized: "High Jump"), "m", .decimal(digits: 2, dropLeadingZero: false)),
    MetricDef("shot_put", String(localized: "Shot Put"), "m", .decimal(digits: 2, dropLeadingZero: false)),
    MetricDef("discus", String(localized: "Discus"), "m", .decimal(digits: 2, dropLeadingZero: false))
  ]

  // MARK: Cross Country

  private static let crossCountryDefs: [MetricDef] = [
    MetricDef("race_time", String(localized: "Race Time"), "", .duration, lowerIsBetter: true),
    MetricDef("pace_per_mile", String(localized: "Pace Per Mile"), "", .duration, lowerIsBetter: true)
  ]

  // MARK: Swimming

  private static let swimmingDefs: [MetricDef] = [
    MetricDef("event_time", String(localized: "Event Time"), "", .duration, lowerIsBetter: true),
    MetricDef(
      "free_50", String(localized: "50 Free"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("free_100", String(localized: "100 Free"), "", .duration, lowerIsBetter: true)
  ]

  // MARK: Golf

  private static let golfDefs: [MetricDef] = [
    MetricDef(
      "scoring_average", String(localized: "Scoring Average"), "strokes",
      .decimal(digits: 1, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef(
      "handicap", String(localized: "Handicap"), "",
      .decimal(digits: 1, dropLeadingZero: false), lowerIsBetter: true
    )
  ]

  // MARK: Tennis

  private static let tennisDefs: [MetricDef] = [
    MetricDef("utr_rating", String(localized: "UTR Rating"), "", .decimal(digits: 2, dropLeadingZero: false)),
    MetricDef("ranking", String(localized: "Ranking"), "", .integer, lowerIsBetter: true)
  ]

  // MARK: Wrestling

  private static let wrestlingDefs: [MetricDef] = [
    MetricDef("pins", String(localized: "Pins"), "count", .integer),
    MetricDef("takedowns", String(localized: "Takedowns"), "count", .integer),
    MetricDef("weight_class", String(localized: "Weight Class"), "lbs", .integer)
  ]

  // MARK: Rowing

  private static let rowingDefs: [MetricDef] = [
    MetricDef("erg_2k", String(localized: "2K Erg"), "", .duration, lowerIsBetter: true),
    MetricDef("erg_split", String(localized: "Erg Split"), "", .duration, lowerIsBetter: true)
  ]

  // MARK: Gymnastics (judged scores — all higher-is-better, 3-decimal)

  private static let gymnasticsDefs: [MetricDef] = [
    MetricDef("aa_score", String(localized: "All-Around Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("vault_score", String(localized: "Vault Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("floor_score", String(localized: "Floor Exercise Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("bars_score", String(localized: "Uneven Bars Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("beam_score", String(localized: "Balance Beam Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("pommel_score", String(localized: "Pommel Horse Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("rings_score", String(localized: "Still Rings Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("pbars_score", String(localized: "Parallel Bars Score"), "", .decimal(digits: 3, dropLeadingZero: false)),
    MetricDef("high_bar_score", String(localized: "High Bar Score"), "", .decimal(digits: 3, dropLeadingZero: false))
  ]

  // MARK: Shared across sports (goals/assists/saves/vertical_jump — one def each)

  private static let sharedDefs: [MetricDef] = [
    MetricDef("goals", String(localized: "Goals"), "count", .integer),
    MetricDef("assists", String(localized: "Assists"), "count", .integer),
    MetricDef("saves", String(localized: "Saves"), "count", .integer),
    MetricDef("vertical_jump", String(localized: "Vertical Jump"), "in", .decimal(digits: 1, dropLeadingZero: false))
  ]
}
