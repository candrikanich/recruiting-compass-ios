import Foundation

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
