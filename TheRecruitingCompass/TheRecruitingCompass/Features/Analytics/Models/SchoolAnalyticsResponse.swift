import Foundation

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
