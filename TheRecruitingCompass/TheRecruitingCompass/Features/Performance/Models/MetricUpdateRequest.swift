import Foundation

struct MetricUpdateRequest: Codable, Sendable {
  let metricType: String?
  let value: Double?
  let unit: String?
  let recordedDate: String?
  let verified: Bool?
  let notes: String?
  let isPrimary: Bool?

  init(
    metricType: String? = nil,
    value: Double? = nil,
    unit: String? = nil,
    recordedDate: String? = nil,
    verified: Bool? = nil,
    notes: String? = nil,
    isPrimary: Bool? = nil
  ) {
    self.metricType = metricType
    self.value = value
    self.unit = unit
    self.recordedDate = recordedDate
    self.verified = verified
    self.notes = notes
    self.isPrimary = isPrimary
  }

  enum CodingKeys: String, CodingKey {
    case metricType = "metric_type"
    case value
    case unit
    case recordedDate = "recorded_date"
    case verified
    case notes
    case isPrimary = "is_primary"
  }
}
