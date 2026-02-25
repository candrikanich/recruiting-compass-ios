import Foundation

struct AppNotification: Codable, Identifiable, Sendable {
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

  func markingAsRead(at timestamp: String = ISO8601DateFormatter().string(from: Date())) -> AppNotification {
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

enum NotificationType: String, Codable, CaseIterable, Sendable {
  case followUpReminder = "follow_up_reminder"
  case deadlineAlert = "deadline_alert"
  case dailyDigest = "daily_digest"
  case inboundInteraction = "inbound_interaction"
  case offer
  case event
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = NotificationType(rawValue: rawValue) ?? .unknown
  }

  var label: String {
    switch self {
    case .followUpReminder: return "Follow-ups"
    case .deadlineAlert: return "Deadlines"
    case .dailyDigest: return "Digest"
    case .inboundInteraction: return "Inbound"
    case .offer: return "Offers"
    case .event: return "Events"
    case .unknown: return "Other"
    }
  }

  var emoji: String {
    switch self {
    case .followUpReminder: return "\u{1F514}"
    case .deadlineAlert: return "\u{23F0}"
    case .dailyDigest: return "\u{1F4CA}"
    case .inboundInteraction: return "\u{1F4E7}"
    case .offer: return "\u{1F389}"
    case .event: return "\u{1F4C5}"
    case .unknown: return "\u{2139}\u{FE0F}"
    }
  }
}

enum NotificationPriority: String, Codable, Sendable {
  case low
  case normal
  case high
}
