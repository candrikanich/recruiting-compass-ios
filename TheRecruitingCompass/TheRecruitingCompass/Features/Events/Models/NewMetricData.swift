import Foundation

struct NewMetricData {
  var metricType: MetricType = .velocity
  var valueText: String = ""
  var unit: String = ""
  var notes: String = ""

  var parsedValue: Double? {
    Double(valueText)
  }

  var isValid: Bool {
    parsedValue != nil
  }
}
