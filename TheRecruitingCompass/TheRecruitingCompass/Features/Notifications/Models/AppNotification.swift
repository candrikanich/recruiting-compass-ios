import Foundation

struct AppNotification: Codable, Identifiable, Sendable {
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
