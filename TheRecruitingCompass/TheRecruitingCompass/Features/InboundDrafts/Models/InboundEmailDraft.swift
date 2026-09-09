import Foundation

/// Maps to an `inbound_email_drafts` row. Field names are the exact JSON keys
/// returned by `GET /api/inbound-drafts` — snake_case straight off the Supabase
/// table (Nitro returns raw rows, no camelCase mapping), matching the same
/// `CodingKeys` pattern used by `Interaction`/`Coach`.
struct InboundEmailDraft: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let familyUnitId: String
  let rawEmailId: String?
  let matchedCoachId: String?
  let matchedSchoolId: String?
  let senderName: String?
  let senderEmail: String?
  let subject: String?
  let bodyText: String?
  let occurredAt: String
  /// Plain Postgres `text` with a CHECK constraint (`pending`/`confirmed`/`discarded`),
  /// not a Postgres enum — kept as `String` so an unrecognized future value decodes
  /// gracefully instead of failing the whole list.
  let status: String
  let confirmedInteractionId: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case familyUnitId = "family_unit_id"
    case rawEmailId = "raw_email_id"
    case matchedCoachId = "matched_coach_id"
    case matchedSchoolId = "matched_school_id"
    case senderName = "sender_name"
    case senderEmail = "sender_email"
    case subject
    case bodyText = "body_text"
    case occurredAt = "occurred_at"
    case status
    case confirmedInteractionId = "confirmed_interaction_id"
    case createdAt = "created_at"
  }

  var displaySenderName: String {
    senderName ?? String(localized: "Unknown sender")
  }

  /// Parses `occurredAt`, tolerating both fractional- and whole-second ISO8601
  /// (the raw email's `Date` header vs. a re-saved row), falling back to now.
  var occurredAtDate: Date {
    if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: occurredAt) { return date }
    if let date = ISO8601DateFormatter().date(from: occurredAt) { return date }
    return .now
  }
}

private extension ISO8601DateFormatter {
  static let withFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}

struct InboundDraftsListResponse: Codable, Sendable {
  let drafts: [InboundEmailDraft]
}

/// Overrides for confirming a draft (#113 parity w/ web #678) — the reviewer
/// edits the parsed fields in the Log Interaction form before saving, so every
/// field here is always sent (never omitted) to reflect the form's current
/// state; `coachId`/`subject`/`content` must encode explicit `null` rather than
/// being dropped, or the server would fall back to the original parsed value
/// instead of honoring a cleared field. Mirrors `confirmBodySchema` in
/// `confirm.post.ts`.
struct InboundDraftConfirmRequest: Encodable, Sendable {
  let schoolId: String?
  let coachId: String?
  let type: String
  let direction: String
  let occurredAt: String
  let subject: String?
  let content: String?

  enum CodingKeys: String, CodingKey {
    case schoolId, coachId, type, direction, occurredAt, subject, content
  }

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  init(
    schoolId: String?,
    coachId: String?,
    type: InteractionType,
    direction: Direction,
    occurredAt: Date,
    subject: String?,
    content: String?
  ) {
    self.schoolId = schoolId
    self.coachId = coachId
    self.type = type.rawValue
    self.direction = direction.rawValue
    self.occurredAt = Self.isoFormatter.string(from: occurredAt)

    let trimmedSubject = subject?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.subject = trimmedSubject.flatMap { DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags($0)) }
    let trimmedContent = content?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.content = trimmedContent.flatMap { DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags($0)) }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(schoolId, forKey: .schoolId)
    // `encode(_:forKey:)` (not `encodeIfPresent`) so a nil writes `null`
    // instead of omitting the key — Optional's own Encodable conformance
    // handles the `null` case.
    try container.encode(coachId, forKey: .coachId)
    try container.encode(type, forKey: .type)
    try container.encode(direction, forKey: .direction)
    try container.encode(occurredAt, forKey: .occurredAt)
    try container.encode(subject, forKey: .subject)
    try container.encode(content, forKey: .content)
  }
}

struct InboundDraftConfirmResponse: Codable, Sendable {
  let ok: Bool
  let interactionId: String?
}

struct InboundDraftDiscardResponse: Codable, Sendable {
  let ok: Bool
}

struct InboundAddressResponse: Codable, Sendable {
  let address: String
}
