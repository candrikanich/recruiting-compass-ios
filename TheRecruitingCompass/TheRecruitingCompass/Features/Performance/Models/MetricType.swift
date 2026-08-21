import Foundation

/// A metric type identified by its registry key (stored verbatim in
/// `performance_metrics.metric_type`). Was a closed enum; now an open struct so
/// non-baseball sports get their own keys. Display logic delegates to
/// `MetricRegistry`. The 8 legacy keys remain as static constants for existing
/// `== .velocity` / `[MetricType: …]` call sites.
struct MetricType: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
  let rawValue: String
  init(rawValue: String) { self.rawValue = rawValue }

  var id: String { rawValue }
  private var def: MetricDef { MetricRegistry.def(for: rawValue) }

  var displayName: String { def.label }
  var defaultUnit: String { def.unit }
  var isLowerBetter: Bool { def.lowerIsBetter }

  /// The unit is fixed for every type except `.other`, which lets the athlete
  /// pick from the shared vocabulary. Mirrors the web log-metric modal.
  var unitIsFixed: Bool { self != .other }

  /// Format a raw value to its display string (number only — callers append the
  /// unit). Parity with web `formatMetricValue`.
  func format(_ value: Double) -> String { def.format.apply(value) }

  static let velocity = MetricType(rawValue: "velocity")
  static let exitVelo = MetricType(rawValue: "exit_velo")
  static let sixtyTime = MetricType(rawValue: "sixty_time")
  static let popTime = MetricType(rawValue: "pop_time")
  static let battingAvg = MetricType(rawValue: "batting_avg")
  static let era = MetricType(rawValue: "era")
  static let strikeouts = MetricType(rawValue: "strikeouts")
  static let other = MetricType(rawValue: "other")

  /// Fixed unit vocabulary offered for `.other`. Mirrors the web modal dropdown.
  static let unitVocabulary: [String] = ["", "mph", "sec", "in", "ft", "lbs", "count", "%"]
}
