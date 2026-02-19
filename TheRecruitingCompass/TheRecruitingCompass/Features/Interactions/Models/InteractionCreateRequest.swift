import Foundation

/// Request model for creating a new interaction
struct InteractionCreateRequest: Codable, Sendable {
  let schoolId: String?
  let coachId: String?
  let eventId: String?
  let type: String
  let direction: String
  let occurredAt: String
  let subject: String?
  let content: String?
  let sentiment: String?
  let loggedBy: String
  let familyUnitId: String

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case coachId = "coach_id"
    case eventId = "event_id"
    case type
    case direction
    case occurredAt = "occurred_at"
    case subject
    case content
    case sentiment
    case loggedBy = "logged_by"
    case familyUnitId = "family_unit_id"
  }

  /// Create a request from form state
  init(
    schoolId: String?,
    coachId: String?,
    eventId: String? = nil,
    type: InteractionType,
    direction: Direction,
    occurredAt: Date,
    subject: String?,
    content: String?,
    sentiment: Sentiment?,
    loggedBy: String,
    familyUnitId: String
  ) {
    self.schoolId = schoolId
    self.coachId = coachId
    self.eventId = eventId
    self.type = type.rawValue
    self.direction = direction.rawValue
    self.sentiment = sentiment?.rawValue

    // Convert date to UTC ISO8601 string
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    self.occurredAt = formatter.string(from: occurredAt)

    // Sanitize text fields (HTML/XSS prevention): trim, strip HTML, then nil if empty
    let trimmedSubject = subject?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.subject = trimmedSubject.flatMap { DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags($0)) }
    let trimmedContent = content?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.content = trimmedContent.flatMap { DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags($0)) }

    self.loggedBy = loggedBy
    self.familyUnitId = familyUnitId
  }
}
