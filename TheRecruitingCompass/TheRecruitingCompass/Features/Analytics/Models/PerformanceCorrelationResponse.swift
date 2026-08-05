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
  }

  struct CorrelationPoint: Codable, Sendable {
    let x: Double
    let y: Double
    let label: String
  }
}
