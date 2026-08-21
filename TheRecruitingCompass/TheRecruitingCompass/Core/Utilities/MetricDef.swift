import Foundation

/// One metric type's definition. `key` is stored verbatim in
/// `performance_metrics.metric_type`. Byte-identical with web `MetricDef`.
struct MetricDef: Equatable, Sendable {
  let key: String
  let label: String
  let unit: String
  let format: Format
  let lowerIsBetter: Bool

  init(_ key: String, _ label: String, _ unit: String,
       _ format: Format, lowerIsBetter: Bool = false) {
    self.key = key
    self.label = label
    self.unit = unit
    self.format = format
    self.lowerIsBetter = lowerIsBetter
  }
}
