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
  let isPrimary: Bool
  let createdAt: Date
  let updatedAt: Date

  init(
    id: String,
    userId: String,
    metricType: MetricType,
    value: Double,
    unit: String,
    recordedDate: Date,
    eventId: String?,
    verified: Bool,
    notes: String?,
    isPrimary: Bool = false,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.metricType = metricType
    self.value = value
    self.unit = unit
    self.recordedDate = recordedDate
    self.eventId = eventId
    self.verified = verified
    self.notes = notes
    self.isPrimary = isPrimary
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    metricType = try container.decode(MetricType.self, forKey: .metricType)
    value = try container.decode(Double.self, forKey: .value)
    unit = try container.decode(String.self, forKey: .unit)
    recordedDate = try Self.decodeFlexibleDate(container, key: .recordedDate)
    eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
    verified = try container.decode(Bool.self, forKey: .verified)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    isPrimary = try container.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    createdAt = try Self.decodeFlexibleDate(container, key: .createdAt)
    // updated_at may be absent in some DB rows; fall back to createdAt
    updatedAt = Self.decodeOptionalDate(container, key: .updatedAt) ?? createdAt
  }

  private static func decodeOptionalDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
    guard let string = try? container.decode(String.self, forKey: key) else { return nil }
    return decodeDate(from: string)
  }

  private static func decodeFlexibleDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Date {
    let string = try container.decode(String.self, forKey: key)
    guard let date = decodeDate(from: string) else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: container,
        debugDescription: "Invalid date format: \(string)"
      )
    }
    return date
  }

  private static func decodeDate(from string: String) -> Date? {
    let iso8601 = ISO8601DateFormatter()
    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso8601.date(from: string) {
      return date
    }
    iso8601.formatOptions = [.withInternetDateTime]
    if let date = iso8601.date(from: string) {
      return date
    }
    let dateOnly = DateFormatter()
    dateOnly.dateFormat = "yyyy-MM-dd"
    dateOnly.locale = Locale(identifier: "en_US_POSIX")
    dateOnly.timeZone = TimeZone(identifier: "UTC")
    return dateOnly.date(from: string)
  }

  /// Returns a copy with `isPrimary` toggled — used for optimistic local updates
  /// after the `set_primary_metric` RPC, which also clears the prior primary row.
  func withIsPrimary(_ value: Bool) -> PerformanceMetric {
    PerformanceMetric(
      id: id,
      userId: userId,
      metricType: metricType,
      value: self.value,
      unit: unit,
      recordedDate: recordedDate,
      eventId: eventId,
      verified: verified,
      notes: notes,
      isPrimary: value,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  var displayName: String {
    metricType.displayName
  }

  var formattedValue: String {
    let formatted = value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    if unit.isEmpty {
      return formatted
    }
    return "\(formatted) \(unit)"
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
    case isPrimary = "is_primary"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
