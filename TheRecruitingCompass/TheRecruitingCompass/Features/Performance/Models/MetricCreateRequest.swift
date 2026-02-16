import Foundation

struct MetricCreateRequest: Codable, Sendable {
  let metricType: String
  let value: Double
  let unit: String
  let recordedDate: String
  let verified: Bool
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case metricType = "metric_type"
    case value
    case unit
    case recordedDate = "recorded_date"
    case verified
    case notes
  }
}

struct MetricUpdateRequest: Codable, Sendable {
  let metricType: String?
  let value: Double?
  let unit: String?
  let recordedDate: String?
  let verified: Bool?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case metricType = "metric_type"
    case value
    case unit
    case recordedDate = "recorded_date"
    case verified
    case notes
  }
}
