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
    value = metric.value.formatted(.number.precision(.fractionLength(2)))
    recordedDate = metric.recordedDate
    unit = metric.unit
    notes = metric.notes ?? ""
    verified = metric.verified
  }
}
