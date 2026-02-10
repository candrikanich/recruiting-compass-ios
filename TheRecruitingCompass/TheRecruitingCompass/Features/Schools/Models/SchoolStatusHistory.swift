import Foundation

struct SchoolStatusHistory: Identifiable, Codable, Sendable {
  let id: String
  let schoolId: String
  let previousStatus: String?
  let newStatus: String
  let changedBy: String
  let changedAt: Date
  let notes: String?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case schoolId = "school_id"
    case previousStatus = "previous_status"
    case newStatus = "new_status"
    case changedBy = "changed_by"
    case changedAt = "changed_at"
    case notes
    case createdAt = "created_at"
  }

  // Helper for date parsing from ISO8601 strings
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    schoolId = try container.decode(String.self, forKey: .schoolId)
    previousStatus = try container.decodeIfPresent(String.self, forKey: .previousStatus)
    newStatus = try container.decode(String.self, forKey: .newStatus)
    changedBy = try container.decode(String.self, forKey: .changedBy)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)

    let iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let changedAtString = try? container.decode(String.self, forKey: .changedAt),
       let date = iso8601Formatter.date(from: changedAtString) {
      changedAt = date
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .changedAt,
        in: container,
        debugDescription: "Date string does not match expected format"
      )
    }

    if let createdAtString = try? container.decode(String.self, forKey: .createdAt),
       let date = iso8601Formatter.date(from: createdAtString) {
      createdAt = date
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .createdAt,
        in: container,
        debugDescription: "Date string does not match expected format"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(schoolId, forKey: .schoolId)
    try container.encodeIfPresent(previousStatus, forKey: .previousStatus)
    try container.encode(newStatus, forKey: .newStatus)
    try container.encode(changedBy, forKey: .changedBy)
    try container.encodeIfPresent(notes, forKey: .notes)

    let iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    try container.encode(iso8601Formatter.string(from: changedAt), forKey: .changedAt)
    try container.encode(iso8601Formatter.string(from: createdAt), forKey: .createdAt)
  }

  // Manual initializer for testing
  init(
    id: String,
    schoolId: String,
    previousStatus: String?,
    newStatus: String,
    changedBy: String,
    changedAt: Date,
    notes: String? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.schoolId = schoolId
    self.previousStatus = previousStatus
    self.newStatus = newStatus
    self.changedBy = changedBy
    self.changedAt = changedAt
    self.notes = notes
    self.createdAt = createdAt
  }
}
