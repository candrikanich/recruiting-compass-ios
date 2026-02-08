import Foundation

struct PerformanceMetric: Codable, Identifiable, Sendable {
  let id: String
  let metricType: String
  let value: Double
  let unit: String?
  let recordedDate: String
  let userId: String
  let createdAt: String

  var displayName: String {
    metricType.replacingOccurrences(of: "_", with: " ").capitalized
  }

  enum CodingKeys: String, CodingKey {
    case id
    case metricType = "metric_type"
    case value
    case unit
    case recordedDate = "recorded_date"
    case userId = "user_id"
    case createdAt = "created_at"
  }
}
