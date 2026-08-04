import Foundation

enum NotificationType: String, Codable, CaseIterable, Sendable {
  case followUpReminder = "follow_up_reminder"
  case deadlineAlert = "deadline_alert"
  case weeklyDigest = "weekly_digest"
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
    case .weeklyDigest: return "Digest"
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
    case .weeklyDigest: return "\u{1F4CA}"
    case .inboundInteraction: return "\u{1F4E7}"
    case .offer: return "\u{1F389}"
    case .event: return "\u{1F4C5}"
    case .unknown: return "\u{2139}\u{FE0F}"
    }
  }
}
