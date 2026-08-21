import Foundation

/// Canonical metric-type registry. Swift mirror of web `metricDefs` /
/// `sportMetrics`. Keys are stored verbatim in `performance_metrics.metric_type`.
/// Phase 1 seeds only the 8 legacy baseball/softball keys; later phases add the
/// remaining sports (byte-identical with web).
enum MetricRegistry {
  static let otherKey = "other"

  static let defs: [String: MetricDef] = Dictionary(
    uniqueKeysWithValues: allDefs.map { ($0.key, $0) }
  )

  /// Ordered per-sport keys (NOT including `other`, which `types(forSport:)`
  /// appends). Keys match the sport strings used across onboarding/preferences
  /// and `CanonicalPositions.bySport`.
  static let sportMetrics: [String: [String]] = [
    "Baseball": baseball,
    "Softball": baseball
  ]

  /// Fallback order for nil/unknown sports: all legacy baseball keys.
  private static let defaultOrder = baseball

  static func knownDef(for key: String) -> MetricDef? { defs[key] }

  static func def(for key: String) -> MetricDef {
    if let d = defs[key] { return d }
    let label = key.replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: .whitespaces)
    return MetricDef(key, label, "", .decimal(digits: 2, dropLeadingZero: false))
  }

  static func types(forSport sport: String?) -> [String] {
    let base = lookup(sport) ?? defaultOrder
    return base + [otherKey]
  }

  private static func lookup(_ sport: String?) -> [String]? {
    guard let sport else { return nil }
    return sportMetrics.first { $0.key.caseInsensitiveCompare(sport) == .orderedSame }?.value
  }

  // MARK: - Definitions

  private static let baseball = [
    "velocity", "exit_velo", "sixty_time", "pop_time", "batting_avg", "era", "strikeouts"
  ]

  private static let allDefs: [MetricDef] = [
    MetricDef("velocity", String(localized: "Fastball Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef("exit_velo", String(localized: "Exit Velocity"), "mph", .decimal(digits: 1, dropLeadingZero: false)),
    MetricDef(
      "sixty_time", String(localized: "60-Yard Dash"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef(
      "pop_time", String(localized: "Pop Time"), "sec",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("batting_avg", String(localized: "Batting Average"), "", .decimal(digits: 3, dropLeadingZero: true)),
    MetricDef(
      "era", String(localized: "ERA"), "",
      .decimal(digits: 2, dropLeadingZero: false), lowerIsBetter: true
    ),
    MetricDef("strikeouts", String(localized: "Strikeouts"), "count", .integer),
    MetricDef("other", String(localized: "Other Metric"), "", .decimal(digits: 2, dropLeadingZero: false))
  ]
}
