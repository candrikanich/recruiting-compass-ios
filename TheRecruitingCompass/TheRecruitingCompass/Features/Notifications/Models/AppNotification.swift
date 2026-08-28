import Foundation

struct AppNotification: Codable, Identifiable, Equatable, Sendable {
  private static let isoFormatter = ISO8601DateFormatter()
  let id: String
  let userId: String?
  let type: NotificationType
  let title: String
  let message: String
  let priority: NotificationPriority
  let readAt: String?
  let scheduledFor: String
  let sentAt: String?
  let emailSent: Bool?
  let emailSentAt: String?
  let actionUrl: String?
  let relatedEntityType: String?
  let relatedEntityId: String?
  let relatedSchoolId: String?
  let relatedCoachId: String?
  let relatedOfferId: String?
  let relatedEventId: String?
  let createdAt: String?
  let updatedAt: String?

  var isRead: Bool {
    readAt != nil
  }

  func markingAsRead(at timestamp: String = Self.isoFormatter.string(from: Date.now)) -> AppNotification {
    AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      priority: priority,
      readAt: timestamp,
      scheduledFor: scheduledFor,
      sentAt: sentAt,
      emailSent: emailSent,
      emailSentAt: emailSentAt,
      actionUrl: actionUrl,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      relatedSchoolId: relatedSchoolId,
      relatedCoachId: relatedCoachId,
      relatedOfferId: relatedOfferId,
      relatedEventId: relatedEventId,
      createdAt: createdAt,
      updatedAt: timestamp
    )
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case type
    case title
    case message
    case priority
    case readAt = "read_at"
    case scheduledFor = "scheduled_for"
    case sentAt = "sent_at"
    case emailSent = "email_sent"
    case emailSentAt = "email_sent_at"
    case actionUrl = "action_url"
    case relatedEntityType = "related_entity_type"
    case relatedEntityId = "related_entity_id"
    case relatedSchoolId = "related_school_id"
    case relatedCoachId = "related_coach_id"
    case relatedOfferId = "related_offer_id"
    case relatedEventId = "related_event_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

extension AppNotification {
  /// Production `notifications` rows omit columns the iOS model historically
  /// treated as required. `updated_at` is not a table column at all; offer /
  /// inbound / event DB triggers insert without `scheduled_for`; `message` is
  /// nullable. A single null required field used to fail the entire inbox
  /// decode, so the list never loaded.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decodeIfPresent(String.self, forKey: .userId)
    type = try container.decode(NotificationType.self, forKey: .type)
    title = try container.decode(String.self, forKey: .title)
    message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    priority = try container.decodeIfPresent(NotificationPriority.self, forKey: .priority) ?? .normal
    readAt = try container.decodeIfPresent(String.self, forKey: .readAt)
    createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    scheduledFor = try container.decodeIfPresent(String.self, forKey: .scheduledFor)
      ?? createdAt
      ?? ""
    sentAt = try container.decodeIfPresent(String.self, forKey: .sentAt)
    emailSent = try container.decodeIfPresent(Bool.self, forKey: .emailSent)
    emailSentAt = try container.decodeIfPresent(String.self, forKey: .emailSentAt)
    actionUrl = try container.decodeIfPresent(String.self, forKey: .actionUrl)
    relatedEntityType = try container.decodeIfPresent(String.self, forKey: .relatedEntityType)
    relatedEntityId = try container.decodeIfPresent(String.self, forKey: .relatedEntityId)
    relatedSchoolId = try container.decodeIfPresent(String.self, forKey: .relatedSchoolId)
    relatedCoachId = try container.decodeIfPresent(String.self, forKey: .relatedCoachId)
    relatedOfferId = try container.decodeIfPresent(String.self, forKey: .relatedOfferId)
    relatedEventId = try container.decodeIfPresent(String.self, forKey: .relatedEventId)
    updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
  }
}
