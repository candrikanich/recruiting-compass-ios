import Foundation

struct PerformanceMetric: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let userId: String
  let metricType: MetricType
  let value: Double
  let unit: String
  let recordedDate: Date
  let eventId: String?
  let verified: Bool
  let notes: String?
  let createdAt: Date
  let updatedAt: Date

  var displayName: String {
    metricType.displayName
  }

  var formattedValue: String {
    if unit.isEmpty {
      return String(format: "%.2f", value)
    }
    return "\(String(format: "%.2f", value)) \(unit)"
  }

  var formattedDate: String {
    recordedDate.formatted(date: .abbreviated, time: .omitted)
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case metricType = "metric_type"
    case value
    case unit
    case recordedDate = "recorded_date"
    case eventId = "event_id"
    case verified
    case notes
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
