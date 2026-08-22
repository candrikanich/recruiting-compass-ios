import Foundation

struct NewMetricData {
  /// Neutral default = the first metric of the registry's default order. The
  /// sport-aware default is applied by `EventMetricForm` once the athlete's
  /// sport is known (this model is constructed before sport is available).
  static let defaultMetricType = MetricType(
    rawValue: MetricRegistry.types(forSport: nil).first ?? MetricType.velocity.rawValue
  )

  var metricType: MetricType = NewMetricData.defaultMetricType
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
