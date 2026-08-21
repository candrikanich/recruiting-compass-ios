import Foundation

struct MetricFormState: Equatable {
  var metricType: MetricType?
  var value: String = ""
  var recordedDate: Date = Date.now
  var unit: String = ""
  var notes: String = ""
  var verified: Bool = false
  /// Custom label when `metricType == .other` — stored as the row's metric_type
  /// so it stops rendering as literally "other".
  var otherName: String = ""

  var isValid: Bool {
    guard let metricType, !value.isEmpty, Double(value) != nil else { return false }
    if metricType == .other { return !otherName.trimmingCharacters(in: .whitespaces).isEmpty }
    return true
  }

  var parsedValue: Double? {
    Double(value)
  }

  /// The metric_type key to persist: the custom `otherName` (snake_cased) when
  /// `other`, else the type's rawValue.
  var resolvedMetricKey: String? {
    guard let metricType else { return nil }
    if metricType == .other {
      let trimmed = otherName.trimmingCharacters(in: .whitespaces)
      // Collapse any run of whitespace to a single underscore so the persisted
      // key matches web byte-for-byte ("Bat  Speed" -> "bat_speed", not "bat__speed").
      return trimmed.isEmpty ? nil
        : trimmed.lowercased()
          .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
    }
    return metricType.rawValue
  }

  mutating func reset() {
    metricType = nil
    value = ""
    recordedDate = Date.now
    unit = ""
    notes = ""
    verified = false
    otherName = ""
  }

  mutating func populate(from metric: PerformanceMetric) {
    metricType = metric.metricType
    let digits = (metric.metricType == .battingAvg || metric.metricType == .era) ? 3 : 2
    value = metric.value.formatted(.number.precision(.fractionLength(digits)))
    recordedDate = metric.recordedDate
    unit = metric.unit
    notes = metric.notes ?? ""
    verified = metric.verified
    otherName = ""
  }
}
