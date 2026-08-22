import Foundation

struct PerformanceCorrelationResponse: Codable, Sendable {
  let success: Bool
  let data: PerformanceCorrelationData

  struct PerformanceCorrelationData: Codable, Sendable {
    let datasets: [CorrelationDataSet]
  }

  struct CorrelationDataSet: Codable, Sendable {
    let label: String
    let points: [CorrelationPoint]
    /// Axis titles derived from the registry for the two correlated metrics.
    /// Optional so any legacy decode path stays valid; the service always sets
    /// them so labels are never baseball-specific for a non-baseball sport.
    let xAxisLabel: String?
    let yAxisLabel: String?

    init(label: String, points: [CorrelationPoint],
         xAxisLabel: String? = nil, yAxisLabel: String? = nil) {
      self.label = label
      self.points = points
      self.xAxisLabel = xAxisLabel
      self.yAxisLabel = yAxisLabel
    }
  }

  struct CorrelationPoint: Codable, Sendable {
    let x: Double
    let y: Double
    let label: String
  }
}
