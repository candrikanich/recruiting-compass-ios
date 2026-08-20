import Foundation

struct MetricFormState: Equatable {
  var metricType: MetricType?
  var value: String = ""
  var recordedDate: Date = Date.now
  var unit: String = ""
  var notes: String = ""
  var verified: Bool = false

  var isValid: Bool {
    metricType != nil && !value.isEmpty && Double(value) != nil
  }

  var parsedValue: Double? {
    Double(value)
  }

  mutating func reset() {
    metricType = nil
    value = ""
    recordedDate = Date.now
    unit = ""
    notes = ""
    verified = false
  }

  mutating func populate(from metric: PerformanceMetric) {
    metricType = metric.metricType
    // Batting average and ERA carry 3 decimals (e.g. 0.000, 3.250); 2 otherwise.
    let fractionLength = (metric.metricType == .battingAvg || metric.metricType == .era) ? 3 : 2
    value = metric.value.formatted(.number.precision(.fractionLength(fractionLength)))
    recordedDate = metric.recordedDate
    unit = metric.unit
    notes = metric.notes ?? ""
    verified = metric.verified
  }
}
