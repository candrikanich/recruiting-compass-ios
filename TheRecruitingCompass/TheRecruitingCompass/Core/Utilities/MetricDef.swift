import Foundation

/// One metric type's definition. `key` is stored verbatim in
/// `performance_metrics.metric_type`. The data fields (`key`, `label`, `unit`,
/// `format`, `lowerIsBetter`) are byte-identical with web `MetricDef`; `icon` is
/// platform-presentational (SF Symbol here, emoji on web) and intentionally NOT
/// shared — the two rendering systems have no common icon vocabulary.
struct MetricDef: Equatable, Sendable {
  let key: String
  let label: String
  let unit: String
  let format: Format
  let lowerIsBetter: Bool
  /// SF Symbol name used wherever this metric is shown with an icon (e.g.
  /// `MetricRow`). Generic default keeps non-baseball metrics from falling back
  /// to a baseball-only symbol switch.
  let icon: String

  init(_ key: String, _ label: String, _ unit: String,
       _ format: Format, lowerIsBetter: Bool = false, icon: String = "chart.bar") {
    self.key = key
    self.label = label
    self.unit = unit
    self.format = format
    self.lowerIsBetter = lowerIsBetter
    self.icon = icon
  }

  /// Returns a copy with a different SF Symbol. Lets `MetricRegistry` assign
  /// icons from a central key→symbol map without rewriting every def literal.
  func withIcon(_ icon: String) -> MetricDef {
    MetricDef(key, label, unit, format, lowerIsBetter: lowerIsBetter, icon: icon)
  }
}
