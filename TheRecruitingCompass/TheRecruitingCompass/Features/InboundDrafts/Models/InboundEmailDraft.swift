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
}

struct InboundDraftsListResponse: Codable, Sendable {
  let drafts: [InboundEmailDraft]
}

/// `coachId` uses `AnyEncodable??`-style tri-state via the custom `encode` below:
/// omitted entirely (server falls back to the parsed draft's match) vs explicit
/// `null` (server clears the match) vs a UUID string.
struct InboundDraftConfirmRequest: Encodable, Sendable {
  let schoolId: String?
  let coachId: String??
  let type: String?
  let direction: String?
  let occurredAt: String?
  let subject: String?
  let content: String?

  init(
    schoolId: String? = nil,
    coachId: String?? = nil,
    type: String? = nil,
    direction: String? = nil,
    occurredAt: String? = nil,
    subject: String? = nil,
    content: String? = nil
  ) {
    self.schoolId = schoolId
    self.coachId = coachId
    self.type = type
    self.direction = direction
    self.occurredAt = occurredAt
    self.subject = subject
    self.content = content
  }

  enum CodingKeys: String, CodingKey {
    case schoolId, coachId, type, direction, occurredAt, subject, content
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(schoolId, forKey: .schoolId)
    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(direction, forKey: .direction)
    try container.encodeIfPresent(occurredAt, forKey: .occurredAt)
    try container.encodeIfPresent(subject, forKey: .subject)
    try container.encodeIfPresent(content, forKey: .content)
    // Outer nil = key omitted entirely; outer .some(inner) = key present, inner may be null.
    if let coachId {
      try container.encode(coachId, forKey: .coachId)
    }
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
