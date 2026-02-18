import Foundation

struct CreateMetricRequest: Encodable, Sendable {
  let userId: String
  let metricType: String
  let value: Double
  let unit: String
  let recordedDate: String
  let eventId: String?
  let verified: Bool
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case value, unit, verified, notes
    case userId = "user_id"
    case metricType = "metric_type"
    case recordedDate = "recorded_date"
    case eventId = "event_id"
  }
}
