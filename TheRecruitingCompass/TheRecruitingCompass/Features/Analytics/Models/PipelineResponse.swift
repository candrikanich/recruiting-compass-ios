import Foundation

struct PipelineResponse: Codable, Sendable {
  let success: Bool
  let data: PipelineData

  struct PipelineData: Codable, Sendable {
    let stages: [ChartDataItem]
  }
}
