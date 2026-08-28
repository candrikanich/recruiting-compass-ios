import Foundation

struct Interaction: Identifiable, Codable, Equatable, Sendable {
  let id: String
  let type: InteractionType
  let direction: Direction
  let schoolId: String?
  let coachId: String?
  let subject: String?
  let content: String?
  let sentiment: Sentiment?
  let occurredAt: String?
  let loggedBy: String?
  let attachments: [String]?
  let familyUnitId: String
  let createdAt: String
  let updatedAt: String?

  var displayDate: Date {
    if let occurredAt {
      if let date = Self.iso8601Formatter.date(from: occurredAt) { return date }
      if let date = Self.iso8601FallbackFormatter.date(from: occurredAt) { return date }
    }
    if let date = Self.iso8601Formatter.date(from: createdAt) { return date }
    if let date = Self.iso8601FallbackFormatter.date(from: createdAt) { return date }
    return .now
  }

  var hasAttachments: Bool {
    !(attachments ?? []).isEmpty
  }

  var attachmentCount: Int {
    (attachments ?? []).count
  }

  var displaySubject: String {
    subject ?? type.displayName
  }

  static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let iso8601FallbackFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case direction
    case schoolId = "school_id"
    case coachId = "coach_id"
    case subject
    case content
    case sentiment
    case occurredAt = "occurred_at"
    case loggedBy = "logged_by"
    case attachments
    case familyUnitId = "family_unit_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
