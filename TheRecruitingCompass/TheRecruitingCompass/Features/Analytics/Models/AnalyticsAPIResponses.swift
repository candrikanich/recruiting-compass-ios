import Foundation

struct AnalyticsSummaryResponse: Codable, Sendable {
  let success: Bool
  let data: AnalyticsSummary
}

struct InteractionAnalyticsResponse: Codable, Sendable {
  let success: Bool
  let data: InteractionAnalyticsData

  struct InteractionAnalyticsData: Codable, Sendable {
    let byType: [ChartDataItem]
    let bySentiment: [ChartDataItem]

    enum CodingKeys: String, CodingKey {
      case byType = "by_type"
      case bySentiment = "by_sentiment"
    }
  }
}

struct PipelineResponse: Codable, Sendable {
  let success: Bool
  let data: PipelineData

  struct PipelineData: Codable, Sendable {
    let stages: [ChartDataItem]
  }
}

struct SchoolAnalyticsResponse: Codable, Sendable {
  let success: Bool
  let data: SchoolAnalyticsData

  struct SchoolAnalyticsData: Codable, Sendable {
    let byStatus: [ChartDataItem]

    enum CodingKeys: String, CodingKey {
      case byStatus = "by_status"
    }
  }
}

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

struct ChartDataItem: Codable, Equatable, Sendable {
  let label: String
  let value: Int
}
